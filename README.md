# Spotchat iOS

Локальный чат с людьми рядом без интернета. Этап 1: техническая основа на
исходниках Bitchat, отдельный репозиторий и проверка сборки.

**Текущая сборка сохраняет интерфейс и функции Bitchat.** Минимальный UI
Spotchat, отключение интернет-транспортов и тест переписки на двух iPhone —
следующие этапы. Новое имя приложения само по себе не меняет его поведение.

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

Baseline включает share extension и App Groups. Для установки потребуются
соответствующие provisioning profiles; Personal Team может не поддерживать
эти возможности. Если тестируем через Personal Team, на этапе 2 нужно убрать
share extension/App Groups из минимальной тестовой сборки, а не выбирать чужую
команду. Установка и Bluetooth-обмен на двух iPhone на этапе 1 не проверялись.

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
