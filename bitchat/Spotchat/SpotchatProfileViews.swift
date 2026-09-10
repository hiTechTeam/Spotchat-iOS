#if os(iOS)
import PhotosUI
import SwiftUI

struct SpotchatOwnProfileSheet: View {
    @ObservedObject var runtime: SpotchatRuntime
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var bio: String
    @State private var avatar: Data?
    @State private var selection: PhotosPickerItem?
    @State private var processing = false
    @State private var photoError: String?
    @State private var showPhoto = false
    @State private var showQR = false

    init(runtime: SpotchatRuntime) {
        self.runtime = runtime
        _name = State(initialValue: runtime.nickname)
        _bio = State(initialValue: runtime.profiles.own.bio)
        _avatar = State(initialValue: runtime.profiles.own.avatar)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Button { showPhoto = avatar != nil } label: {
                        SpotchatAvatar(name: name, size: 88, imageData: avatar)
                            .overlay { if processing { ProgressView().padding(12).background(.regularMaterial, in: Circle()) } }
                    }.buttonStyle(.plain).accessibilityLabel("Посмотреть своё фото")
                    PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                        Text(avatar == nil ? "Добавить фото" : "Сменить фото").font(.system(size: 16, weight: .medium))
                    }.disabled(processing)
                    VStack(spacing: 0) {
                        TextField("Ваше имя", text: $name).textInputAutocapitalization(.words)
                            .padding(14).accessibilityLabel("Имя")
                        Divider().padding(.leading, 14)
                        TextField("Немного о себе", text: $bio, axis: .vertical)
                            .lineLimit(2...3).padding(14).accessibilityLabel("Описание профиля")
                            .onChange(of: bio) { value in if value.count > SpotchatProfile.maxBioCharacters { bio = String(value.prefix(SpotchatProfile.maxBioCharacters)) } }
                    }.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    HStack {
                        Text("Ваш профиль виден людям рядом.")
                        Spacer(minLength: 8)
                        Text("\(bio.count)/\(SpotchatProfile.maxBioCharacters)").monospacedDigit()
                    }.font(.caption).foregroundStyle(.secondary)
                    if runtime.permanent != nil {
                        Button { showQR = true } label: { Label("Мой QR-код", systemImage: "qrcode") }
                    }
                    NavigationLink { SpotchatPrivacySettings(runtime: runtime) } label: {
                        Label("Настройки и поддержка", systemImage: "gearshape")
                    }
                    if avatar != nil {
                        Button("Удалить фото", role: .destructive) { avatar = nil; selection = nil }
                            .font(.footnote).disabled(processing)
                    }
                }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Мой профиль").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Закрыть")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        if runtime.saveProfile(name: name, bio: bio, avatar: avatar) { dismiss() }
                        else { photoError = runtime.error; runtime.error = nil }
                    }.fontWeight(.semibold).disabled(processing)
                }
            }
            .task(id: selection) {
                guard let item = selection else { return }
                processing = true
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                    try Task.checkCancellation()
                    let prepared = try SpotchatAvatarCodec.prepare(data)
                    try Task.checkCancellation()
                    avatar = prepared
                } catch is CancellationError { return }
                catch { photoError = "Не получилось открыть фото. Выберите другое изображение." }
                processing = false
            }
            .alert("Профиль", isPresented: Binding(get: { photoError != nil }, set: { if !$0 { photoError = nil } })) {
                Button("Понятно") { photoError = nil }
            } message: { Text(photoError ?? "") }
            .sheet(isPresented: $showQR) { if let card = runtime.permanent?.ownCard { SpotchatQRView(card: card) } }
            .fullScreenCover(isPresented: $showPhoto) {
                if let avatar { SpotchatPhotoViewer(data: avatar) }
            }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}

struct SpotchatPeerProfileSheet: View {
    @ObservedObject var runtime: SpotchatRuntime
    let peer: SpotchatPeer
    @Environment(\.dismiss) private var dismiss
    @State private var showPhoto = false
    private var profile: SpotchatProfile? { runtime.profile(for: peer.id) }
    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            GeometryReader { geometry in
                // Same available-space calculation as Telescan's ProfileSheetView.
                let availableSize = max(0, min(geometry.size.width, geometry.size.height) - 24)
                let avatarSize = availableSize * 0.9 * 1.04
                Button { showPhoto = profile?.avatar != nil } label: {
                    SpotchatAvatar(name: runtime.displayName(peer), size: avatarSize, imageData: profile?.avatar)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .offset(y: -10)
                .accessibilityLabel("Посмотреть фото собеседника")
            }
            VStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text(runtime.displayName(peer)).font(.title.bold()).multilineTextAlignment(.center)
                    HStack(spacing: 5) {
                        Circle().fill(runtime.isNearby(peer.id) ? Color.green : Color.secondary).frame(width: 6, height: 6)
                        Text(runtime.isBlocked(peer.id) ? "Заблокирован" : (runtime.isNearby(peer.id) ? "Рядом" : "Сейчас не рядом"))
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    }
                }
                .offset(y: -10)
                if let bio = profile?.bio, !bio.isEmpty {
                    Text(String(bio.prefix(SpotchatProfile.maxBioCharacters)))
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 48)
                } else {
                    Color.clear.frame(height: 48).accessibilityHidden(true)
                }
                if runtime.profiles.loading.contains(peer.id) {
                    HStack(spacing: 6) { ProgressView(); Text("Загружаем фото…").font(.caption).foregroundStyle(.secondary) }
                } else if runtime.profiles.failed.contains(peer.id), runtime.isNearby(peer.id) {
                    Button("Обновить профиль") { runtime.profiles.refresh(peer.id) }.font(.caption)
                }
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 20)
            // Preserve Telescan's 50 pt footer space without its message button.
            .padding(.bottom, 50)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
        }
        .padding(.top, 60)
        .offset(y: -10)
        .background(Color(.systemBackground))
        .overlay(alignment: .topTrailing) {
            if let card = runtime.permanent?.card(for: peer.id) {
                SpotchatContactActionsMenu(runtime: runtime, card: card, onDelete: { dismiss() })
                    .padding(.trailing, 16).padding(.top, 12)
            }
        }
        .presentationDetents([.medium]).presentationDragIndicator(.visible)
        .onAppear { if profile == nil || runtime.profiles.failed.contains(peer.id) { runtime.profiles.refresh(peer.id) } }
        .fullScreenCover(isPresented: $showPhoto) {
            if let data = profile?.avatar { SpotchatPhotoViewer(data: data) }
        }
    }
}

struct SpotchatPhotoViewer: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
                    .scaleEffect(zoom)
                    .gesture(MagnificationGesture().onChanged { zoom = min(3, max(1, $0)) }.onEnded { _ in withAnimation { zoom = 1 } })
                    .onTapGesture(count: 2) { withAnimation { zoom = zoom > 1 ? 1 : 2 } }
                    .accessibilityLabel("Фото профиля")
            }
        }.overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(.ultraThinMaterial, in: Circle())
            }.padding().accessibilityLabel("Закрыть фото")
        }
    }
}
#endif
