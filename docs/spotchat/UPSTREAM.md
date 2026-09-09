# Происхождение исходников

- Repository: https://github.com/permissionlesstech/bitchat
- Baseline: `9b84b361225facd8e623f25d76f889d3dc54a879`
- Imported: 2026-09-10
- License: Unlicense, исходный текст сохранён в корневом `LICENSE`.
- История Git сохранена. Spotchat — самостоятельный приватный репозиторий,
  созданный из исходников, а не GitHub fork.

Изначальная инструкция Bitchat сохранена в `BITCHAT-README.md` рядом с этим
файлом. Её относительные ссылки рассчитаны на исходное расположение в корне;
для запуска Spotchat используйте корневой README.

Зависимости сохраняют собственные лицензии; корневой Unlicense не заменяет
лицензии сторонних пакетов. В частности, проверять `localPackages/Arti`,
`docs/ARTI-BINARY-PROVENANCE.md` и лицензию Swift-пакета swift-secp256k1.

Upstream GitHub Actions сохранены в `upstream-workflows/*.yml.disabled` как
справочный материал. Они не запускаются в новом репозитории: среди них есть
периодическое обновление Nostr-relays, публикация upstream-манифестов и аудит
бинарных зависимостей, которые пока не относятся к этапу 1 Spotchat.

На этом этапе файлы из Telescan-iOS и Telegram-iOS не копировались.
