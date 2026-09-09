# Проверка этапа 1

Дата: 2026-09-10. Xcode 26.3 (`17C529`), iOS Simulator SDK 26.2.

## Результаты

- Схема `bitchat (iOS)`, Debug, generic iOS Simulator, без подписи:
  **BUILD SUCCEEDED**.
- Схема `Spotchat`, Debug, generic iOS Simulator, без подписи:
  **BUILD SUCCEEDED** после смены идентификаторов и имени приложения.
- `plutil -lint` для Info.plist и project.pbxproj: OK.
- XML схемы Spotchat успешно разобран.
- Проверен собранный Info.plist:
  - `CFBundleDisplayName`: `Spotchat`;
  - `CFBundleIdentifier`: `com.hitechteam.spotchat`;
  - `CFBundleShortVersionString`: `0.1.0`;
  - `AppGroupID`: `group.com.hitechteam.spotchat`.

Команда финальной сборки:

```sh
xcodebuild -project bitchat.xcodeproj -scheme Spotchat \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build
```

Полные локальные логи находятся в
`.DerivedData/SpotchatValidation/baseline-build.log` и
`.DerivedData/SpotchatValidation/spotchat-build.log` (не публикуются в Git).

## Границы проверки

Это проверка компиляции и идентичности приложения. Unit-тесты upstream,
запуск UI, подпись, установка и Bluetooth-обмен между физическими iPhone
на этапе 1 не проверялись. Исходные интернет-функции и UI ещё присутствуют.
