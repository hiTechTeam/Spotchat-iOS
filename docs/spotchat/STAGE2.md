# Этап 2: Bluetooth-переписка

## Реализация

- `bitchat/Spotchat/SpotchatRuntime.swift`: минимальная композиция напрямую
  с `BLEService` через `Transport` и типизированные события.
- `bitchat/Spotchat/SpotchatRootView.swift`: список людей, имя и личный чат.
- iOS-ветка `BitchatApp`: создаёт только SpotchatRuntime. Upstream AppRuntime,
  ChatViewModel, NostrTransport, геосервисы и Tor не запускаются.
- Service UUID `14D26780-9D8B-4C16-8D42-A4F5B127C902` и characteristic UUID
  `AF27DC35-9357-4D33-9273-18C1277C743B` принадлежат тестовой сети Spotchat;
  одинаковы в Debug/Release, отличаются от Bitchat.
- Существующие Noise-сессии, подписанные объявления, фрагментация и BLE-очереди
  сохранены. Самодельного шифрования нет.
- В списке только `isConnected` участники; после потери связи даётся 6 секунд
  на короткий обрыв. Это индикатор соединения, не доказательство расстояния.
- Отправка идёт напрямую в `sendPrivateMessage`. До 3 попыток с одним message ID,
  интервал 10 секунд, далее видимая ошибка и ручной повтор. Получатель подавляет
  дубли, но повторно подтверждает приём. Входящие подтверждения проверяются
  по ID сообщения **и** ожидаемому отправителю.
- Прочтение подтверждается только при открытой переписке и активном приложении.
  Локальное событие `.sent` не выдаётся за подтверждённую доставку.
- Убраны зависимость iOS-target от share extension, его встраивание в app и
  iOS App Group entitlements. Локальная подпись не хранится в Git.

## Целевые тесты

`bitchatTests/SpotchatRuntimeTests.swift` проверяет два логических конца
переписки, дубли, поддельное/позднее подтверждение, видимость для read receipts,
повторы/таймаут, исчезновение людей и UTF-8-ограничение пакета.

```sh
xcodebuild -project bitchat.xcodeproj -scheme Spotchat \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .DerivedDataSimulator CODE_SIGNING_ALLOWED=NO \
  -only-testing:bitchatTests_iOS/SpotchatRuntimeTests test
```

## Диагностика на физических телефонах (только Debug)

Для воспроизводимой проверки разработчик может запустить оба собственных
телефона с одинаковым случайным ID теста и разными именами:

```sh
xcrun devicectl device process launch --device DEVICE_ID \
  --terminate-existing com.hitechteam.spotchat -- \
  -SpotchatSelfTestRun RANDOM_RUN_ID -SpotchatSelfTestName iPhoneA
```

Имя временно получает префикс `SC-RANDOM_RUN_ID`. Отправляется одно синтетическое
сообщение только другому подключённому участнику с тем же тестовым префиксом.
При ожидании теста не меняйте имена в UI. Тест не включён при обычном запуске;
он не читает пользовательские сообщения и не использует сетевой API.

`Documents/spotchat-test-result.json` содержит ID прогона, состояние Bluetooth,
число соседей и счётчики отправленных, полученных, подтверждённых синтетических
сообщений. Успех двустороннего теста: `receivedCount >= 1` и `confirmedCount >= 1`
на **обоих** телефонах с одним run ID.

```sh
xcrun devicectl device copy from --device DEVICE_ID \
  --domain-type appDataContainer --domain-identifier com.hitechteam.spotchat \
  --source Documents/spotchat-test-result.json --destination result.json
```

После теста запустить приложение заново без этих аргументов — вернётся сохранённое
обычное имя. В режиме теста не сохраняются временные имена в профиль.

## Ограничения этой итерации

- Только короткий текст (до 255 UTF-8 байт), аватарки и описание ещё не передаются.
- Переписка в памяти, без восстановления после завершения процесса.
- За один снимок обновляются до 100 соседей; это не обещание вместимости
  Bluetooth. Сообщения ограничены 1000, кеш дедупликации — 4000 ID.
- macOS, Android, фоновые сценарии и нагрузка множества участников не проверяются
  этим этапом.

## Результаты, 2026-09-10

- Сборка Debug для iPhone: **BUILD SUCCEEDED**, подписана Personal Team.
- Установка и запуск на **iPhone 11** и **iPhone 14 Pro** выполнены успешно.
- Прогон `S2C0910`: на каждом устройстве `bluetoothPoweredOn = true`,
  `sentCount = 1`, `receivedCount = 1`, `confirmedCount = 1`.
  Это реальный обмен через BLEService и зашифрованные Noise payloads, не mock.
- Диагностические результаты: [iPhone 11](evidence/stage2-iphone11.json),
  [iPhone 14 Pro](evidence/stage2-iphone14pro.json).
- **6 целевых тестов SpotchatRuntimeTests прошли**, `TEST SUCCEEDED`.
- После проверки оба приложения перезапущены без тестовых аргументов.
- Wi-Fi и мобильные данные на телефонах программно не выключались. В iOS-графе
  Spotchat интернет-транспорт отсутствует; отдельная пользовательская проверка
  с выключенными Wi-Fi/мобильными данными остаётся полезной проверкой условий.
- Полные локальные логи сохранены в `.DerivedData/SpotchatValidation/`:
  `stage2-tests.log`, `stage2-device-build.log`.
