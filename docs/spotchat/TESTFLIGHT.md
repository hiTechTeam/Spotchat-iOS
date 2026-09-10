# TestFlight

Release signing uses FrameLabs LLC (`SDL7K9875S`) and bundle ID
`hiTeam.Spotchat`. The earlier `com.hitechteam.spotchat` identifier belongs to
the Personal Team and cannot be registered to the distribution team.
The ignored `Configs/Local.xcconfig` keeps cable Debug builds on that earlier
identifier. These installations have separate containers and Keychain access;
the TestFlight installation does not inherit the earlier test profile/history.

The Connect listing uses **Spotchat — Offline Chat** because **Spotchat** alone
was unavailable. The Home Screen display name remains **Spotchat**.
Primary listing language: Russian. SKU: `Spotchat-iOS`.

## First upload — 2026-09-10

- App Store Connect app ID: `6810787268`.
- Version/build: **0.1.0 (1)**.
- Release archive and App Store distribution export succeeded.
- Apple confirmed **Upload succeeded** at 22:02 Moscow time and reported that
  the uploaded package was processing.
- Local archive: `.DerivedData/Archives/Spotchat-0.1.0-1.xcarchive`.
- Exported IPA: `.DerivedData/Distribution/Spotchat-0.1.0-1/bitchat.ipa`.
- The user verified the privacy/support update on their iPhone before upload.

Connect: https://appstoreconnect.apple.com/apps/6810787268/distribution

## Build and upload

Run from the repository root using the signed-in Xcode account:

```sh
xcodebuild -project bitchat.xcodeproj -scheme Spotchat \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath .DerivedData \
  -archivePath .DerivedData/Archives/Spotchat.xcarchive \
  -allowProvisioningUpdates archive

xcodebuild -exportArchive \
  -archivePath .DerivedData/Archives/Spotchat.xcarchive \
  -exportOptionsPlist Configs/TestFlightExport.plist \
  -exportPath .DerivedData/Distribution/Spotchat \
  -allowProvisioningUpdates
```

`TestFlightExport.plist` **uploads** to App Store Connect. Increment
`CURRENT_PROJECT_VERSION` in `Configs/Release.xcconfig` for a new build.
Export does not automatically increment it. Do not repeat an upload after an
uncertain response before checking Connect for the existing version/build.

Public privacy policy: https://github.com/hiTechTeam/Spotchat-info/blob/main/PRIVACY_POLICY.ru.md

Support: admin@tgtelescan.ru

## External beta — 2026-09-10

- Internal group: **Spotchat Internal**. Build **0.1.0 (1)** is available to
  the App Store Connect user `r66cha@gmail.com`.
- External group: **Spotchat Beta**.
- Build **0.1.0 (1)** was submitted to Beta App Review and its current status
  is **Waiting for Review**.
- Public invitation: https://testflight.apple.com/join/C6hdFUgr
- Public-link limit: **100 testers**. Testers cannot join until Apple approves
  a build in the external group.
- Export compliance declares standard encryption implemented by the app in
  addition to Apple's operating-system encryption. Distribution in France is
  disabled for this declaration; enabling it requires the applicable French
  encryption documentation.

External group: https://appstoreconnect.apple.com/teams/29d8cd9c-3fd3-4ff3-bb0e-d7d37c876985/apps/6810787268/testflight/groups/40ee36aa-23ba-4be8-abc1-b70bd6263528

The binary includes end-to-end encryption beyond system TLS. Do not declare
that it contains no encryption merely to bypass the export-compliance form.
Uploading a build does not itself approve external beta testing or an App Store
release; verify the processing/compliance state in Connect.
