# Spotchat iOS

Локальный чат с людьми рядом без интернета. Этап 3: список людей рядом и
экран переписки в стиле Telegram с Bluetooth-транспортом Bitchat.

В iOS уже работают локальное имя, список подключённых людей, личный текстовый
чат, подтверждения доставки/прочтения, повтор отправки и защита от дублей.
`AppRuntime`, Nostr, геоканалы и Tor в iOS-запуске не создаются. Их исходники
и зависимости пока сохранены для постепенного отделения от upstream.
macOS-схема остаётся исходным Bitchat и не является целью текущего этапа.

Пузыри по размеру текста, новое поле ввода и счётчики непрочитанных реализованы
в [этапе 3](docs/spotchat/STAGE3.md). Фото, описание и карточки профилей — этап 4. Сейчас профиль редактирует только имя, история переписки хранится
в памяти процесса. Исчезновение из списка не удаляет сообщения до перезапуска.

## Открыть и собрать

Требуется Xcode. Проект использует iOS 16.0 как минимальную версию.
Первое разрешение Swift-пакетов требует интернета; это требование сборки,
а не будущего Bluetooth-чата.

```sh
open bitchat.xcodeproj
```

Выбрать схему **Spotchat** и iOS Simulator. Внутренние имена проекта, модулей
и файлов `bitchat` сохранены для удобного сравнения с upstream.

Сборка из терминала без подписи:

```sh
xcodebuild -project bitchat.xcodeproj \
  -scheme Spotchat -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

## Подготовка подписи для физических устройств

```sh
cp Configs/Local.xcconfig.example Configs/Local.xcconfig
```

Указать свой `DEVELOPMENT_TEAM` в локальном файле. Debug его автоматически
подключает; файл исключён из Git. Release намеренно не использует локальные
Debug-настройки. Команда исходного автора Bitchat удалена из общей конфигурации.

Схема **Spotchat** не собирает и не встраивает share extension и не запрашивает
App Groups, поэтому подходит для Personal Team. Сами upstream-targets сохранены.
Для каждого нового тестового телефона Xcode должен обновить provisioning profile.
Пример сборки с регистрацией подключённого устройства:

```sh
xcodebuild -project bitchat.xcodeproj -scheme Spotchat \
  -configuration Debug -destination 'platform=iOS,id=YOUR_DEVICE_UDID' \
  -derivedDataPath .DerivedData \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

На устройстве необходимы Developer Mode, доверие компьютеру и профилю
разработчика, а при первом запуске — разрешение Bluetooth.

## Проверить чат на двух iPhone

1. Установить **Spotchat** на оба iPhone и открыть приложения рядом друг с другом.
2. Ввести разные имена через кнопку профиля справа сверху.
3. Открыть появившегося человека и отправить короткий текст в обе стороны.
4. Убедиться, что «Отправляется…» сменилось на «Доставлено» или «Прочитано».
5. Выключить Wi-Fi и мобильные данные, оставив Bluetooth включённым, и повторить.

Первый тест проводится при открытых приложениях. Фоновую доставку iOS нельзя
считать гарантированной. В этой версии один текст ограничен **255 UTF-8 байт**
форматом private-message TLV Bitchat (примерно 127 кириллических букв без пробелов).
Превышение показывается как ошибка, текст не обрезается молча.

Подробности автоматизированной проверки: [этап 2](docs/spotchat/STAGE2.md).

## Структура и следующие этапы

- [Карта модулей и план подключения BLE](docs/spotchat/ARCHITECTURE.md)
- [Происхождение кода и зависимости](docs/spotchat/UPSTREAM.md)
- [Результаты проверки сборки](docs/spotchat/VALIDATION.md)
- [Исходный README Bitchat](docs/spotchat/BITCHAT-README.md)

1. Основа проекта и сборка исходной версии.
2. Текстовый обмен на двух физических iPhone без интернета.
3. Список людей рядом и экран чата по согласованным макетам.
4. Свой профиль, карточка собеседника и передача аватарок.
5. Проверка переподключений, фоновых сценариев и статусов доставки.

## Upstream

- `origin`: https://github.com/hiTechTeam/Spotchat-iOS
- `upstream`: https://github.com/permissionlesstech/bitchat
- Baseline: `9b84b361225facd8e623f25d76f889d3dc54a879`

Код Bitchat сохранён с историей и исходной [лицензией Unlicense](LICENSE).
Лицензии сторонних зависимостей действуют отдельно. Код Telescan и Telegram
на этапе 1 не переносился. GitHub Actions исходного проекта сохранены как
неактивные справочные файлы в `docs/spotchat/upstream-workflows`.
