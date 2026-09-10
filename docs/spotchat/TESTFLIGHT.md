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

The binary includes end-to-end encryption beyond system TLS. Do not declare
that it contains no encryption merely to bypass the export-compliance form.
Uploading a build does not itself approve external beta testing or an App Store
release; verify the processing/compliance state in Connect.
