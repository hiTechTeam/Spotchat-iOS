import Foundation

/// A durable marker keeps a failed/interrupted deletion from reopening radios
/// or silently creating replacement keys on the next launch.
@MainActor
final class SpotchatDeletionService {
    private let marker: URL
    private let directories: [URL]
    private let deleteKeys: () -> Bool
    private let clearPreferences: () -> Void
    init(marker: URL, directories: [URL], deleteKeys: @escaping () -> Bool, clearPreferences: @escaping () -> Void) {
        self.marker = marker; self.directories = directories
        self.deleteKeys = deleteKeys; self.clearPreferences = clearPreferences
    }
    var hasDeletion: Bool { FileManager.default.fileExists(atPath: marker.path) }
    var completed: Bool { (try? String(contentsOf: marker, encoding: .utf8)) == "deleted" }
    func begin() throws { try writeMarker("pending") }
    func finish() throws {
        guard hasDeletion else { throw SpotchatFailure.storage }
        // Remove files before committing success. A partial failure leaves the
        // marker and the app closed; Retry is safe even after key deletion.
        for directory in directories where FileManager.default.fileExists(atPath: directory.path) {
            for entry in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                if entry.standardizedFileURL == marker.deletingLastPathComponent().standardizedFileURL { continue }
                try FileManager.default.removeItem(at: entry)
            }
        }
        guard deleteKeys() else { throw SpotchatFailure.unavailableIdentity }
        clearPreferences()
        try writeMarker("deleted")
    }
    func allowNewProfile() throws {
        guard completed else { throw SpotchatFailure.storage }
        try FileManager.default.removeItem(at: marker)
    }
    private func writeMarker(_ value: String) throws {
        try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(value.utf8).write(to: marker, options: .atomic)
        var folder = marker.deletingLastPathComponent()
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
    }
    static func live() -> SpotchatDeletionService {
        let files = FileManager.default
        let support = files.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return SpotchatDeletionService(marker: support.appendingPathComponent("SpotchatPrivacy/deletion.state"),
            directories: [support, files.urls(for: .cachesDirectory, in: .userDomainMask)[0], files.urls(for: .documentDirectory, in: .userDomainMask)[0], files.temporaryDirectory],
            deleteKeys: { KeychainManager.makeDefault().deleteAllKeychainData() },
            clearPreferences: { if let bundle = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: bundle) } })
    }
}

#if os(iOS)
import SwiftUI

enum SpotchatSupport {
    static let email = "admin@tgtelescan.ru"
    static let privacyURL = URL(string: "https://github.com/hiTechTeam/Spotchat-info/blob/main/PRIVACY_POLICY.ru.md")!
    static let mailURL = URL(string: "mailto:admin@tgtelescan.ru?subject=Spotchat")!
}

@MainActor
final class SpotchatSessionController: ObservableObject {
    @Published private(set) var runtime: SpotchatRuntime?
    @Published private(set) var deletionComplete = false
    @Published var deletionError: String?
    private let deletion: SpotchatDeletionService
    private let runtimeFactory: () -> SpotchatRuntime
    init(deletion: SpotchatDeletionService, runtimeFactory: @escaping () -> SpotchatRuntime) {
        self.deletion = deletion; self.runtimeFactory = runtimeFactory
        if deletion.hasDeletion {
            if deletion.completed { deletionComplete = true }
            else { finishDeletion() }
        } else { makeRuntime() }
    }
    static func live() -> SpotchatSessionController {
        #if DEBUG
        if TestEnvironment.isRunningTests {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let isolated = SpotchatDeletionService(marker: folder.appendingPathComponent("marker/state"), directories: [folder], deleteKeys: { true }, clearPreferences: {})
            return SpotchatSessionController(deletion: isolated, runtimeFactory: { SpotchatRuntime.live() })
        }
        #endif
        return SpotchatSessionController(deletion: .live(), runtimeFactory: { SpotchatRuntime.live() })
    }
    private func makeRuntime() {
        let model = runtimeFactory()
        model.deleteProfileHandler = { [weak self] in self?.deleteProfile() }
        runtime = model
    }
    func deleteProfile() {
        do { try deletion.begin() }
        catch { runtime?.error = "Не удалось начать удаление. Проверьте свободное место."; return }
        runtime?.retireForDeletion()
        runtime = nil
        finishDeletion()
    }
    func finishDeletion() {
        do { try deletion.finish(); deletionComplete = true; deletionError = nil }
        catch { deletionError = "Удаление не завершено. Разблокируйте iPhone и повторите. Обмен сообщениями остановлен." }
    }
    func createProfile() {
        do { try deletion.allowNewProfile(); deletionComplete = false; makeRuntime() }
        catch { deletionError = "Не удалось создать новый профиль. Повторите попытку." }
    }
}

struct SpotchatSessionView: View {
    @StateObject private var session = SpotchatSessionController.live()
    @Environment(\.scenePhase) private var phase
    var body: some View {
        Group {
            if let runtime = session.runtime {
                SpotchatRootView(runtime: runtime)
                    .task { runtime.setAppActive(phase == .active); runtime.start() }
                    .onChange(of: phase) { runtime.setAppActive($0 == .active) }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: session.deletionComplete ? "checkmark.circle" : "lock.shield")
                        .font(.system(size: 48)).foregroundStyle(.blue)
                    Text(session.deletionComplete ? "Профиль удалён" : "Завершение удаления").font(.title2.bold())
                    Text(session.deletionComplete ? "Данные и ключи удалены с этого iPhone. Копии сообщений у собеседников могут сохраниться." : (session.deletionError ?? "Обмен сообщениями остановлен."))
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if session.deletionComplete {
                        Button("Создать новый профиль") { session.createProfile() }.buttonStyle(.borderedProminent)
                    } else {
                        Button("Повторить удаление") { session.finishDeletion() }.buttonStyle(.borderedProminent)
                    }
                    Link("Поддержка", destination: SpotchatSupport.mailURL)
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(.systemBackground))
            }
        }
    }
}

struct SpotchatPrivacySettings: View {
    @ObservedObject var runtime: SpotchatRuntime
    @Environment(\.openURL) private var openURL
    @State private var confirmDelete = false
    @State private var error: String?
    var body: some View {
        List {
            Section("Информация") {
                Button { openURL(SpotchatSupport.mailURL) { accepted in
                    if !accepted { error = "Напишите нам: \(SpotchatSupport.email). На этом iPhone не настроена почта." }
                } } label: { Label("Связаться с поддержкой", systemImage: "envelope") }
                Text(SpotchatSupport.email).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
                Link(destination: SpotchatSupport.privacyURL) { Label("Политика конфиденциальности", systemImage: "hand.raised") }
            }
            Section("Заблокированные") {
                let cards = (runtime.permanent?.state.blocked?.values.map { $0 } ?? []).sorted { $0.name < $1.name }
                if cards.isEmpty { Text("Нет заблокированных контактов").foregroundStyle(.secondary) }
                ForEach(cards) { card in
                    HStack {
                        Text(card.name); Spacer()
                        Button("Разблокировать") {
                            do { try runtime.permanent?.setBlocked(card, blocked: false) }
                            catch { self.error = error.localizedDescription }
                        }.font(.subheadline)
                    }
                }
            }
            Section {
                Button("Удалить профиль и данные", role: .destructive) { confirmDelete = true }
                    .accessibilityIdentifier("spotchat.deleteProfile")
            } footer: {
                Text("Удаляет профиль, ключи, контакты, историю и очередь на этом iPhone. Восстановить прежний профиль будет нельзя. Копии у других людей не удаляются.")
            }
        }
        .navigationTitle("Настройки").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Удалить профиль навсегда?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить профиль и данные", role: .destructive) { runtime.deleteProfileHandler?() }
            Button("Отмена", role: .cancel) {}
        } message: { Text("Все данные и ключи на этом iPhone будут удалены. Отправленные сообщения могут остаться у собеседников и на устройствах-посредниках.") }
        .alert("Spotchat", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Понятно") {} } message: { Text(error ?? "") }
    }
}

struct SpotchatContactActionsMenu: View {
    @ObservedObject var runtime: SpotchatRuntime
    let card: SpotchatContactCard
    var onDelete: () -> Void = {}
    @State private var action: String?
    @State private var error: String?
    private var blocked: Bool { runtime.permanent?.isBlocked(card) == true }
    var body: some View {
        Menu {
            Button { action = "block" } label: { Label(blocked ? "Разблокировать" : "Заблокировать", systemImage: "hand.raised") }
            Button(role: .destructive) { action = "chat" } label: { Label("Удалить чат", systemImage: "trash") }
            Button(role: .destructive) { action = "contact" } label: { Label("Удалить контакт", systemImage: "person.crop.circle.badge.minus") }
        } label: { Image(systemName: "ellipsis.circle").font(.title3).frame(width: 44, height: 44).contentShape(Circle()) }
        .accessibilityLabel("Действия с контактом")
        .confirmationDialog(title, isPresented: Binding(get: { action != nil }, set: { if !$0 { action = nil } }), titleVisibility: .visible) {
            if let action {
                Button(title, role: blocked && action == "block" ? nil : .destructive) {
                    do {
                        if action == "block" { try runtime.permanent?.setBlocked(card, blocked: !blocked) }
                        else { try runtime.permanent?.deleteConversation(with: card, removeContact: action == "contact"); onDelete() }
                    } catch { self.error = error.localizedDescription }
                    self.action = nil
                }
            }
            Button("Отмена", role: .cancel) { action = nil }
        } message: {
            Text(action == "block" ? (blocked ? "Вы снова сможете обмениваться сообщениями." : "Сообщения и приглашения этого пользователя будут отклоняться на вашем iPhone. Неотправленные сообщения будут отменены.") : (action == "contact" ? "Контакт, история и очередь будут удалены на этом iPhone. Копии у собеседника и существующая блокировка сохранятся." : "История и очередь будут удалены на этом iPhone. Контакт сохранится, и вы сможете начать новый разговор."))
        }
        .alert("Spotchat", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("Понятно") {} } message: { Text(error ?? "") }
    }
    private var title: String {
        switch action { case "block": return blocked ? "Разблокировать контакт" : "Заблокировать контакт"
        case "contact": return "Удалить контакт"; default: return "Удалить чат" }
    }
}
#endif
