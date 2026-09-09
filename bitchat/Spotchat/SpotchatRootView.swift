#if os(iOS)
import BitFoundation
import SwiftUI

struct SpotchatRootView: View {
    @ObservedObject var runtime: SpotchatRuntime
    @State private var showName = false
    @State private var name = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(runtime.peers) { peer in
                        NavigationLink(value: peer) {
                            HStack(spacing: 12) {
                                initials(peer.name)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(peer.name).font(.headline)
                                    Text(runtime.conversation(peer.id).last?.text ?? "Нажмите, чтобы написать")
                                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }.padding(.vertical, 6)
                        }
                    }
                } header: {
                    Text(statusText)
                }
                if runtime.peers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.wave.2").font(.largeTitle).foregroundStyle(.blue)
                        Text("Люди рядом").font(.headline)
                        Text("Откройте Spotchat на втором iPhone и включите Bluetooth на обоих устройствах.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 35).listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Spotchat")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { name = runtime.nickname; showName = true } label: {
                        Image(systemName: "person.crop.circle").font(.title2)
                    }.accessibilityLabel("Мой профиль")
                }
            }
            .navigationDestination(for: SpotchatPeer.self) { peer in
                SpotchatConversationView(runtime: runtime, peer: peer)
            }
            .sheet(isPresented: $showName) {
                NavigationStack {
                    Form {
                        Section("Ваше имя") {
                            TextField("Имя", text: $name).textInputAutocapitalization(.words)
                        }
                        Text("Имя видно людям рядом. Регистрация и интернет не нужны.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .navigationTitle("Мой профиль").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Готово") { if runtime.saveNickname(name) { showName = false } }
                        }
                        ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { showName = false } }
                    }
                }.presentationDetents([.medium])
            }
            .alert("Spotchat", isPresented: Binding(get: { runtime.error != nil }, set: { if !$0 { runtime.error = nil } })) {
                Button("Понятно") { runtime.error = nil }
            } message: { Text(runtime.error ?? "") }
        }.tint(.blue)
    }

    private var statusText: String {
        switch runtime.bluetoothState {
        case .poweredOn: return "Рядом: \(runtime.peers.count) · \(runtime.nickname)"
        case .poweredOff: return "Включите Bluetooth в настройках iPhone"
        case .unauthorized: return "Разрешите Bluetooth для Spotchat в настройках"
        case .unsupported: return "Bluetooth недоступен на этом устройстве"
        default: return "Запускаем Bluetooth…"
        }
    }

    private func initials(_ name: String) -> some View {
        Text(String(name.prefix(1)).uppercased()).font(.title2.weight(.medium))
            .frame(width: 52, height: 52).background(Color.blue.opacity(0.12), in: Circle())
            .foregroundStyle(.blue)
    }
}

private struct SpotchatConversationView: View {
    @ObservedObject var runtime: SpotchatRuntime
    let peer: SpotchatPeer
    @State private var draft = ""

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(runtime.conversation(peer.id)) { message in
                        HStack {
                            if message.outgoing { Spacer(minLength: 40) }
                            VStack(alignment: .trailing, spacing: 5) {
                                Text(message.text).frame(maxWidth: .infinity, alignment: .leading)
                                HStack(spacing: 5) {
                                    Text(message.date, style: .time)
                                    if message.outgoing { Text(status(message.status)) }
                                }.font(.caption2).foregroundStyle(.secondary)
                                if message.outgoing, case .failed = message.status {
                                    Button("Повторить") { runtime.retry(message) }.font(.caption)
                                }
                            }
                            .padding(12)
                            .background(message.outgoing ? Color.blue.opacity(0.13) : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 18))
                            if !message.outgoing { Spacer(minLength: 40) }
                        }.id(message.id)
                    }
                }.padding()
            }
            .onChange(of: runtime.conversation(peer.id).count) { _ in
                if let id = runtime.conversation(peer.id).last?.id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            .onAppear {
                runtime.openConversation(peer.id)
                if let id = runtime.conversation(peer.id).last?.id { proxy.scrollTo(id, anchor: .bottom) }
            }
            .onDisappear { runtime.openConversation(nil) }
        }
        .navigationTitle(runtime.peers.first(where: { $0.id == peer.id })?.name ?? peer.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if !runtime.isNearby(peer.id) {
                    Text("Собеседник недоступен").font(.caption).foregroundStyle(.secondary)
                }
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Сообщение", text: $draft, axis: .vertical)
                        .lineLimit(1...5).padding(11)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
                        .accessibilityIdentifier("spotchat.messageInput")
                    Button {
                        if runtime.send(draft, to: peer.id) { draft = "" }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 36))
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !runtime.isNearby(peer.id))
                    .accessibilityLabel("Отправить")
                }
            }.padding(.horizontal).padding(.vertical, 8).background(.regularMaterial)
        }
    }

    private func status(_ status: DeliveryStatus) -> String {
        switch status {
        case .delivered: return "Доставлено"
        case .read: return "Прочитано"
        case .failed: return "Не доставлено"
        default: return "Отправляется…"
        }
    }
}
#endif
