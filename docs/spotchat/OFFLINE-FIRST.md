# Permanent conversations implementation

Checkpoint: `3816201` (existing BLE app and icon explorations).

## Existing components retained

- `SpotchatRuntime`, `SpotchatRootView`, `SpotchatProfileViews`: current composition, message bubbles/composer, medium profile cards.
- `SpotchatProfiles`: bounded authenticated profile/avatar exchange and disk profile cache.
- `BLEService`, `Transport`: discovery, authenticated Noise sessions, packet fragmentation, CoreBluetooth restoration/background lifecycle.
- `NoiseEncryptionService`: persistent CryptoKit Curve25519/Ed25519 identity in Keychain, Noise XX sessions and authenticated one-way Noise X courier sealing.
- `NostrIdentityBridge`, `NostrTransport`, `NostrProtocol`, `NostrRelayManager`: persisted Nostr identity, private envelopes, signature validation, bounded relay subscriptions/reconnects.
- Upstream `CourierStore` / `MessageRouter` demonstrate bounded carry queues; their legacy private-message TLV and favorite/session-based routing do not represent Spotchat permanent message IDs, contact cards, signed receipts or conversation persistence. Spotchat adds a small application envelope/outbox coordinator over the existing BLE/Noise/Nostr primitives instead of changing radio discovery/routing.

## Implementation sequence

1. Stable identity and encrypted transactional local storage.
2. Contacts, QR exchange, nearby addition and system invitations.
3. Permanent conversations and unchanged chat UI components.
4. Durable offline outbox, common end-to-end addressing over BLE/Nostr.
5. Bounded store-and-forward, authenticated receipts, deduplication and expiry.
6. Targeted tests, build, visual verification and installation on the connected iPhone 11.

## Constraints

Nostr needs internet and independent relay servers; no Spotchat backend is required. Compatible Spotchat envelopes use existing bitchat private-envelope encryption and relay transport, but are not chat messages for arbitrary Nostr/bitchat clients.

CoreBluetooth background modes/restoration remain enabled. iOS may suspend or terminate the process; BLE discovery and relay WebSockets cannot be promised continuously in the background. Outbox resumes on foreground/available execution. Without internet, delivery requires reachable compatible devices or subsequent physical encounters, and can expire.

Static Noise X courier sealing reuses upstream crypto and authenticates the sender, but does not provide forward secrecy against later compromise of the recipient static key. No new custom cryptographic primitive is introduced. Local history is encrypted with a separate device-only Keychain storage key, using CryptoKit ChaChaPoly and iOS file protection. That key is for disk storage, not another messaging protocol.

## Implemented boundaries

- `SpotchatIdentityService`: reuses the existing Noise static/signing keys, checks durable Keychain copies before opening permanent history; signed versioned contact card pins Noise, signing and Nostr public keys. A locked/corrupt Keychain does not silently create a new permanent profile.
- `SpotchatContactsService` / `SpotchatContactsView`: QR and URL invitations, nearby authenticated Spotchat cards, saved contacts and explicit acceptance of incoming invitations. The iOS contact picker exposes only the selected person; sharing is completed by the user in the system sheet.
- `SpotchatConversationStore`: one transactional encrypted database for contacts, conversations, messages/outbox, opaque relay copies, signed receipts and replay tombstones. Disk save precedes visible acceptance/ACK. Corrupt files are not overwritten. Storage key is device-only; automatic backup is excluded.
- `SpotchatMessageStore`: permanent conversation IDs derived from the two full user IDs; UUID message IDs; sender/recipient identity, timestamp, ciphertext, delivery state, received hop count and transport metadata. UI never routes via BLE directly.
- `SpotchatCryptoService`: authenticated Noise X envelope, transported inside the existing Noise session for BLE. Relay devices only see encrypted content and signed public routing metadata. It is not metadata-anonymous: a carrier can observe public contact cards, timestamps, message IDs and routing addresses.
- `NostrTransport.sendSpotchat` uses existing `NostrProtocol` private envelopes and `NostrRelayManager`, including validated reception and relay OK handling. Relay OK means accepted by a relay, not delivered to the user. This composition uses direct TLS relay connections, not Tor. Both endpoints still need connectivity to compatible relays for internet delivery.
- Nearby profile/avatar exchange remains the existing BLE mechanism. Saved avatars persist; a QR invitation carries identity/name/bio, not a photo payload.

## Queue and relay limits

Text is limited to 4096 UTF-8 bytes. Pending personal outbox: 200 messages. An envelope expires after 24 hours, with a signed expiry and maximum four BLE hops. Expiry stops transport attempts and leaves the history row visible; retry creates a fresh message. At most four personal transmissions, eight relay handovers and eight receipt jobs are scheduled per foreground tick. Retries back off to 60 seconds.

A sender deposits with at most three distinct carriers. Each carrier fans out to at most two additional devices, remembers where it has forwarded, and carries at most 64 envelopes / eight per depositor. Persistent seen IDs prevent repeated deposits after eviction/delivery. Only authenticated compatible Spotchat neighbors accept deposits. Signatures bind immutable envelope metadata; honest clients enforce hop limits, while a malicious carrier can still drop mail or lie about its mutable hop count. Signed expiry, quotas and deduplication remain the resource bounds.

Recipient-signed receipts are carried along devices that held the original envelope. Their signature, recipient key, message ID and ciphertext digest must match before deleting a relay copy or marking a message delivered. Other disconnected copies disappear when they encounter that proof or expire; global instantaneous deletion is impossible. Read receipts require an active visible conversation. A current BLE receive callback can send a durable delivery receipt while backgrounded; no timer/WebSocket background guarantee is made.

## Test paths

`SpotchatPermanentTests` exercises real Noise sealing, stable identities, signed QR round-trips, encrypted disk restore and corrupt-file handling, session-ID changes, shared BLE/Nostr message dedup, forged ACK rejection, carrier confidentiality/delivery, invitations and expiry. Existing `SpotchatRuntimeTests` and `SpotchatProfileTests` cover preserved radio diagnostics and avatar behavior.

`SpotchatLiveRelayTests` is opt-in with `TEST_RUNNER_SPOTCHAT_LIVE_NOSTR=1`; only two fresh test-owned Nostr identities exchange synthetic packets across public relays. It is separate from deterministic tests because public relay reachability is environmental.

## Validation - 2026-09-10

- 25 deterministic tests passed on iOS 18.5, including cold key initialization,
  real encrypted disk relay restoration, BLE session changes, invalid hops,
  background delivery/read separation and disk-write failure without ACK.
- The opt-in live Nostr test passed in 12 seconds: relay publication ACK and
  authenticated decryption in both directions, with bounded retries while the
  independent relay connections become ready. Reachability is not guaranteed.
- Signed Debug builds succeeded for the iOS Simulator and physical iPhone.
  An unsigned simulator build can deny real Keychain access, even when mocked
  unit tests pass; use the normal Xcode signing configuration for UI checks.
- Contacts and own QR were inspected on iOS 18.5; permanent offline chats and
  the message composer were also inspected on iOS 26.3.
- Installed and launched on the user's iPhone 11 only. This update has not yet
  been exercised across two physical iPhones or a three-phone carrier route.
