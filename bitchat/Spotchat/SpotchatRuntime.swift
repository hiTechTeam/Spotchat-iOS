import BitFoundation
import Combine
import CoreBluetooth
import Foundation

struct SpotchatPeer: Identifiable, Hashable {
    let id: PeerID
    var name: String
    var lastConnected: Date
}

struct SpotchatMessage: Identifiable {
    let id: String
    let peerID: PeerID
    let text: String
    let date: Date
    let outgoing: Bool
    var status: DeliveryStatus
    var attempts: Int = 0
    var lastAttempt: Date = .distantPast
}

/// Minimal local-only composition. Never instantiates AppRuntime/ChatViewModel,
/// NostrTransport, MessageRouter, location services or Tor.
@MainActor
final class SpotchatRuntime: ObservableObject, TransportEventDelegate, TransportPeerEventsDelegate {
    @Published private(set) var peers: [SpotchatPeer] = []
    @Published private(set) var messages: [SpotchatMessage] = []
    @Published private var unreadMessageIDs: Set<String> = []
    @Published private(set) var nickname: String
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published var error: String?
    let profiles: SpotchatProfiles
    private var profileChanges: AnyCancellable?
    private(set) var activePeer: PeerID?
    private var appActive = true
    private let transport: Transport
    private let defaults: UserDefaults
    private let now: () -> Date
    private var timer: AnyCancellable?
    private var started = false
    private var knownPeers: [PeerID: SpotchatPeer] = [:]
    private var receivedIDs: Set<String> = []
    private var receivedOrder: [String] = []
    static let disappearanceDelay: TimeInterval = 6
    static let retryInterval: TimeInterval = 10
    static let maxAttempts = 3

    static func live() -> SpotchatRuntime {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-SpotchatPreview") { return preview() }
        #endif
        let keychain = KeychainManager.makeDefault()
        let ble = BLEService(keychain: keychain,
                             idBridge: NostrIdentityBridge(keychain: keychain),
                             identityManager: SecureIdentityStateManager(keychain))
        return SpotchatRuntime(transport: ble, profileStore: .live())
    }

    #if DEBUG && targetEnvironment(simulator)
    private static func preview() -> SpotchatRuntime {
        let wire = SpotchatPreviewTransport()
        let model = SpotchatRuntime(transport: wire, defaults: UserDefaults(suiteName: "Spotchat.UI.Preview")!)
        model.nickname = "Руслан"
        try? model.profiles.save(SpotchatProfile(name: "Руслан", bio: "Люблю знакомиться и создавать новое", avatar: SpotchatAvatarCodec.diagnosticPhoto(seed: 12)))
        model.profiles.seedPreview(SpotchatProfile(name: "Аня", bio: "Кофе, прогулки и хорошие разговоры", avatar: SpotchatAvatarCodec.diagnosticPhoto(seed: 64)), for: wire.samples[0].peerID)
        model.didReceiveTransportEvent(.bluetoothStateUpdated(.poweredOn))
        model.didUpdatePeerSnapshots(wire.samples)
        let peer = wire.samples[0].peerID
        let lines: [(String, Bool)] = [
            ("Привет! 👋", false), ("Привет", true),
            ("Ты тоже пробуешь Spotchat?", false),
            ("Да", true),
            ("Прикольно, что можно просто написать человеку рядом. Даже без интернета", true),
            ("Ага! Давай проверим 🙂", false),
            ("Раз, два…\nВсё долетело?", false),
            ("Всё работает ✨", true)
        ]
        model.messages = lines.enumerated().map { index, line in
            SpotchatMessage(id: "preview-\(index)", peerID: peer, text: line.0,
                date: Date().addingTimeInterval(Double(index - lines.count) * 30),
                outgoing: line.1, status: .read(by: "Аня", at: Date()))
        }
        for (index, text) in ["Увидимся!", "Привет, я тоже здесь", "Отличная идея 👍"].enumerated() {
            let sample = wire.samples[index + 1]
            let id = "preview-peer-\(index)"
            model.messages.append(SpotchatMessage(id: id, peerID: sample.peerID, text: text,
                date: Date().addingTimeInterval(-600), outgoing: false, status: .delivered(to: "Руслан", at: Date())))
            if index == 1 { model.unreadMessageIDs.insert("\(sample.peerID.id):\(id)") }
        }
        if ProcessInfo.processInfo.arguments.contains("-SpotchatPreviewEmptyChat") { model.messages = [] }
        if ProcessInfo.processInfo.arguments.contains("-SpotchatPreviewLongBio") {
            let bio = String(String(repeating: "Люблю прогулки, новые знакомства и разговоры о том, что вдохновляет. ", count: 3).prefix(SpotchatProfile.maxBioCharacters))
            model.profiles.seedPreview(SpotchatProfile(name: "Аня", bio: bio, avatar: SpotchatAvatarCodec.diagnosticPhoto(seed: 64)), for: peer)
        }
        return model
    }
    #endif

    init(transport: Transport, defaults: UserDefaults = .standard,
         profileStore: SpotchatProfileStore = SpotchatProfileStore(),
         now: @escaping () -> Date = Date.init) {
        self.transport = transport
        self.defaults = defaults
        self.now = now
        var initialName = defaults.string(forKey: "spotchat.nickname")
            .flatMap(InputValidator.validateNickname) ?? "Гость \(transport.myPeerID.id.prefix(4))"
        #if DEBUG
        if let testName = defaults.string(forKey: "SpotchatSelfTestName"),
           let run = defaults.string(forKey: "SpotchatSelfTestRun") {
            initialName = "SC-\(run) \(testName)"
        }
        #endif
        var activeStore = profileStore
        #if DEBUG
        if defaults.string(forKey: "SpotchatSelfTestRun") != nil { activeStore = SpotchatProfileStore() }
        #endif
        let profileModel = SpotchatProfiles(name: initialName, store: activeStore, now: now,
            connected: { transport.isPeerConnected($0) },
            send: { data, peer in (transport as? SpotchatProfileTransporting)?.sendSpotchatProfile(data, to: peer) })
        profiles = profileModel
        nickname = profileModel.own.name
        transport.eventDelegate = self
        transport.peerEventsDelegate = self
        transport.setNickname(nickname)
        profileChanges = profiles.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        #if DEBUG && os(iOS)
        if let run = defaults.string(forKey: "SpotchatSelfTestRun") {
            let seed = nickname.utf8.reduce(0) { ($0 + Int($1)) % 255 }
            try? profiles.save(SpotchatProfile(name: nickname, bio: "Проверка профиля \(run)", avatar: SpotchatAvatarCodec.diagnosticPhoto(seed: seed)))
        }
        #endif
    }

    func start(runTimer: Bool = true) {
        guard !started else { return }
        started = true
        transport.startServices()
        if runTimer {
            timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
                .sink { [weak self] _ in self?.tick() }
        }
        tick()
    }

    func setAppActive(_ active: Bool) {
        appActive = active
        if active {
            transport.startServices()
            tick()
            markVisibleRead()
        }
    }

    func saveNickname(_ name: String) -> Bool {
        guard let valid = InputValidator.validateNickname(name), valid.utf8.count <= 64 else {
            error = "Введите короткое имя без служебных символов."
            return false
        }
        return saveProfile(name: valid, bio: profiles.own.bio, avatar: profiles.own.avatar)
    }

    func saveProfile(name: String, bio: String, avatar: Data?) -> Bool {
        guard let valid = InputValidator.validateNickname(name), valid.utf8.count <= 64 else {
            error = "Введите короткое имя без служебных символов."; return false
        }
        let profile = SpotchatProfile(name: valid, bio: bio.trimmingCharacters(in: .whitespacesAndNewlines), avatar: avatar)
        guard profile.valid else { error = "Описание — до \(SpotchatProfile.maxBioCharacters) символов. Попробуйте выбрать фото ещё раз."; return false }
        do { try profiles.save(profile) }
        catch { self.error = "Не удалось сохранить профиль. Попробуйте ещё раз."; return false }
        nickname = valid
        defaults.set(valid, forKey: "spotchat.nickname")
        transport.setNickname(valid)
        return true
    }

    func displayName(_ peer: SpotchatPeer) -> String { profiles.remote[peer.id]?.name ?? peers.first(where: { $0.id == peer.id })?.name ?? peer.name }

    func openConversation(_ peer: PeerID?) {
        activePeer = peer
        if let peer, transport.isPeerConnected(peer) { transport.triggerHandshake(with: peer) }
        markVisibleRead()
    }

    func conversation(_ peer: PeerID) -> [SpotchatMessage] {
        messages.filter { $0.peerID == peer }
    }

    func unreadCount(for peer: PeerID) -> Int {
        conversation(peer).filter { !$0.outgoing && unreadMessageIDs.contains("\(peer.id):\($0.id)") }.count
    }

    func isNearby(_ peer: PeerID) -> Bool {
        bluetoothState == .poweredOn && transport.isPeerConnected(peer)
    }

    @discardableResult
    func send(_ text: String, to peer: PeerID) -> Bool {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return false }
        // Upstream private-message TLV has a one-byte length. Reject visibly
        // rather than silently dropping Cyrillic/emoji payloads above 255 bytes.
        guard content.utf8.count <= 255 else {
            error = "Для этой тестовой версии сократите сообщение или отправьте его частями."
            return false
        }
        guard isNearby(peer) else {
            error = "Собеседник сейчас недоступен. Подойдите ближе и попробуйте снова."
            return false
        }
        let message = SpotchatMessage(id: UUID().uuidString, peerID: peer,
                                      text: content, date: now(), outgoing: true, status: .sending)
        messages.append(message)
        trimMessages()
        transmit(id: message.id)
        return true
    }

    func retry(_ message: SpotchatMessage) {
        guard message.outgoing, isNearby(message.peerID),
              let index = messages.firstIndex(where: { $0.id == message.id && $0.outgoing }) else { return }
        guard case .failed = messages[index].status else { return }
        messages[index].attempts = 0
        messages[index].status = .sending
        transmit(id: message.id)
    }

    private func transmit(id: String) {
        guard let index = messages.firstIndex(where: { $0.id == id && $0.outgoing }) else { return }
        messages[index].attempts += 1
        messages[index].lastAttempt = now()
        let message = messages[index]
        transport.sendPrivateMessage(message.text, to: message.peerID,
                                     recipientNickname: knownPeers[message.peerID]?.name ?? "Гость",
                                     messageID: message.id)
    }

    func tick() {
        didUpdatePeerSnapshots(transport.currentPeerSnapshots())
        if transport is SpotchatProfileTransporting, bluetoothState == .poweredOn { profiles.tick() }
        // Each retry uses the same ID. Recipient deduplication makes a lost
        // acknowledgement safe; no receipt means no success indicator.
        let pending = messages.filter { message in
            guard message.outgoing else { return false }
            switch message.status {
            case .sending, .sent: return now().timeIntervalSince(message.lastAttempt) >= Self.retryInterval
            default: return false
            }
        }
        for message in pending {
            if message.attempts < Self.maxAttempts && isNearby(message.peerID) {
                transmit(id: message.id)
            } else if let index = messages.firstIndex(where: { $0.id == message.id && $0.outgoing }) {
                messages[index].status = .failed(reason: "Нет подтверждения")
            }
        }
        #if DEBUG
        runSelfTestIfRequested()
        #endif
    }

    func didUpdatePeerSnapshots(_ snapshots: [TransportPeerSnapshot]) {
        let current = now()
        let connected = snapshots.filter { $0.peerID != transport.myPeerID && $0.isConnected }
        let ids = Set(connected.map(\.peerID))
        profiles.updatePeers(ids)
        for peer in connected.prefix(100) {
            knownPeers[peer.peerID] = SpotchatPeer(id: peer.peerID, name: peer.nickname, lastConnected: current)
        }
        knownPeers = knownPeers.filter { ids.contains($0.key) || current.timeIntervalSince($0.value.lastConnected) < Self.disappearanceDelay }
        peers = knownPeers.values.sorted { $0.name == $1.name ? $0.id.id < $1.id.id : $0.name < $1.name }
    }

    func didReceiveTransportEvent(_ event: TransportEvent) {
        switch event {
        case .bluetoothStateUpdated(let state):
            bluetoothState = state
            if state != .poweredOn { knownPeers.removeAll(); peers = []; profiles.updatePeers([]) }
        case .peerSnapshotsUpdated(let snapshots): didUpdatePeerSnapshots(snapshots)
        case .peerConnected, .peerDisconnected, .peerListUpdated:
            didUpdatePeerSnapshots(transport.currentPeerSnapshots())
        case .noisePayloadReceived(let peer, let type, let data, let date):
            switch type {
            case .spotchatProfile:
                profiles.receive(data, from: peer)
            case .privateMessage:
                guard let packet = PrivateMessagePacket.decode(from: data),
                      !packet.messageID.isEmpty, packet.messageID.utf8.count <= 255,
                      !packet.content.isEmpty else { return }
                let dedupID = "\(peer.id):\(packet.messageID)"
                if receivedIDs.insert(dedupID).inserted {
                    if !appActive || activePeer != peer { unreadMessageIDs.insert(dedupID) }
                    receivedOrder.append(dedupID)
                    if receivedOrder.count > 4000 { receivedIDs.remove(receivedOrder.removeFirst()) }
                    messages.append(SpotchatMessage(id: packet.messageID, peerID: peer,
                                                   text: packet.content, date: date,
                                                   outgoing: false, status: .delivered(to: nickname, at: now())))
                    trimMessages()
                }
                transport.sendDeliveryAck(for: packet.messageID, to: peer)
                if appActive && activePeer == peer { sendRead(packet.messageID, to: peer) }
            case .delivered, .readReceipt:
                guard let id = String(data: data, encoding: .utf8),
                      let index = messages.firstIndex(where: { $0.id == id && $0.outgoing && $0.peerID == peer }) else { return }
                if case .read = messages[index].status { return }
                let name = knownPeers[peer]?.name ?? "Собеседник"
                messages[index].status = type == .readReceipt
                    ? .read(by: name, at: now()) : .delivered(to: name, at: now())
            default: break
            }
        case .messageDeliveryStatusUpdated(let id, let status):
            guard let index = messages.firstIndex(where: { $0.id == id && $0.outgoing }) else { return }
            // A local write or a late retry callback cannot override a receipt
            // or turn a timed-out message back into an endless spinner.
            switch messages[index].status {
            case .sending, .sent:
                switch status {
                case .sent: messages[index].status = .sent
                case .failed: messages[index].status = status
                default: break
                }
            default: break
            }
        default: break
        }
        #if DEBUG
        writeSelfTestResult()
        #endif
    }

    private func sendRead(_ id: String, to peer: PeerID) {
        transport.sendReadReceipt(ReadReceipt(originalMessageID: id,
            readerID: transport.myPeerID, readerNickname: nickname), to: peer)
    }

    private func markVisibleRead() {
        guard appActive, let peer = activePeer else { return }
        for message in conversation(peer) where !message.outgoing {
            unreadMessageIDs.remove("\(peer.id):\(message.id)")
            sendRead(message.id, to: peer)
        }
    }

    private func trimMessages() {
        if messages.count > 1000 {
            for message in messages.prefix(messages.count - 1000) {
                unreadMessageIDs.remove("\(message.peerID.id):\(message.id)")
            }
            messages.removeFirst(messages.count - 1000)
        }
    }

    #if DEBUG
    // Explicit opt-in only, for the two owner-controlled test phones. Synthetic
    // messages target only another device advertising the same random test run.
    private var testedPeers: Set<PeerID> = []
    private func runSelfTestIfRequested() {
        guard let run = defaults.string(forKey: "SpotchatSelfTestRun"), !run.isEmpty else { return }
        for peer in peers where peer.name.hasPrefix("SC-\(run) ") && !testedPeers.contains(peer.id) {
            if send("Spotchat BLE test \(run) от \(nickname)", to: peer.id) { testedPeers.insert(peer.id) }
        }
        writeSelfTestResult()
    }

    private func writeSelfTestResult() {
        guard let run = defaults.string(forKey: "SpotchatSelfTestRun"), !run.isEmpty else { return }
        let synthetic = messages.filter { $0.text.hasPrefix("Spotchat BLE test \(run) ") }
        let confirmed = synthetic.filter {
            guard $0.outgoing else { return false }
            switch $0.status { case .delivered, .read: return true; default: return false }
        }
        let receivedProfiles = profiles.remote.values.filter { $0.name.hasPrefix("SC-\(run) ") && $0.bio == "Проверка профиля \(run)" }
        let receivedPhotos = receivedProfiles.compactMap(\.avatar)
        let result: [String: Any] = [
            "run": run, "name": nickname, "transport": "BLEService",
            "bluetoothPoweredOn": bluetoothState == .poweredOn,
            "nearbyCount": peers.count,
            "profileReceivedCount": receivedProfiles.count,
            "avatarReceivedCount": receivedPhotos.count,
            "ownAvatarHash": profiles.own.avatar.map(SpotchatProfile.digest) ?? "",
            "receivedAvatarHashes": receivedPhotos.map(SpotchatProfile.digest),
            "receivedAvatarBytes": receivedPhotos.map(\.count),
            "sentCount": synthetic.filter(\.outgoing).count,
            "receivedCount": synthetic.filter { !$0.outgoing }.count,
            "confirmedCount": confirmed.count,
            "updatedAt": ISO8601DateFormatter().string(from: now())
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]),
              let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        try? data.write(to: directory.appendingPathComponent("spotchat-test-result.json"), options: .atomic)
    }
    #endif
}
