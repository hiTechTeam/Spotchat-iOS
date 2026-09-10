import Foundation
import Testing
@testable import bitchat

@Suite("Spotchat profile deletion", .serialized)
@MainActor
struct SpotchatDeletionTests {
    @Test func deletionIsRetryableAndKeepsIdentityClosedUntilExplicitNewProfile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let marker = root.appendingPathComponent("privacy/deletion.state")
        let profile = root.appendingPathComponent("profile.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("private profile".utf8).write(to: profile)
        let keychain = MockKeychain()
        _ = keychain.saveIdentityKey(Data([1,2,3]), forKey: "noiseStaticKey")
        var clearedPreferences = false
        let service = SpotchatDeletionService(marker: marker, directories: [root], deleteKeys: { keychain.deleteAllKeychainData() }, clearPreferences: { clearedPreferences = true })
        try service.begin()
        keychain.simulatedDeleteAllResult = false
        #expect(throws: (any Error).self) { try service.finish() }
        #expect(service.hasDeletion && !service.completed)
        #expect(!clearedPreferences)
        #expect(throws: (any Error).self) { try service.allowNewProfile() }
        keychain.simulatedDeleteAllResult = true
        let restarted = SpotchatDeletionService(marker: marker, directories: [root], deleteKeys: { keychain.deleteAllKeychainData() }, clearPreferences: { clearedPreferences = true })
        try restarted.finish()
        #expect(restarted.completed)
        #expect(!FileManager.default.fileExists(atPath: profile.path))
        #expect(keychain.getIdentityKey(forKey: "noiseStaticKey") == nil)
        #expect(clearedPreferences)
        try restarted.allowNewProfile()
        #expect(!restarted.hasDeletion)
    }
    #if os(iOS)
    @Test func sessionStaysDeletedAcrossRelaunchUntilUserCreatesFreshProfile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let deletion = SpotchatDeletionService(marker: root.appendingPathComponent("marker/state"), directories: [root], deleteKeys: { true }, clearPreferences: {})
        let suite = "SpotchatDeletionTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var creations = 0
        let factory = {
            creations += 1
            return SpotchatRuntime(transport: MockTransport(), defaults: defaults)
        }
        let session = SpotchatSessionController(deletion: deletion, runtimeFactory: factory)
        let oldRuntime = try #require(session.runtime)
        session.deleteProfile()
        #expect(session.runtime == nil && session.deletionComplete)
        #expect(creations == 1)
        let relaunched = SpotchatSessionController(deletion: deletion, runtimeFactory: factory)
        #expect(relaunched.runtime == nil && relaunched.deletionComplete)
        #expect(creations == 1)
        relaunched.createProfile()
        #expect(creations == 2)
        #expect(relaunched.runtime !== oldRuntime)
        #expect(!deletion.hasDeletion)
        #expect(!oldRuntime.saveProfile(name: "Old", bio: "", avatar: nil))
    }
    #endif

}
