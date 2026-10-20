# Зависимости, native-компоненты и право распространения

База: `c366dd11871d75d5f511e843605b689731759622`. Ниже разделены подтверждённые факты, advisory matching и вопросы, которые ещё не разрешены.

## Лицензия: публикация сборок пока не разрешена доказательствами

В tracked tree нет общего `LICENSE`, `COPYING`, `NOTICE` или другого файла с явным разрешением на использование всего проекта; в корневом `package.json` нет `license`. README благодарит WeFlow и описывает историческое заимствование, но не содержит общей лицензии. 21.10.2026 GitHub API для `Wxw-Gu/TraceMemo` и `randomspb/TraceMemoENRU` вернул `license:null`; upstream `main` совпадал с проверенным SHA.

Отсутствие распознанной лицензии само по себе не доказывает запрет любой деятельности или нарушение кем-либо закона. Но публичная доступность и возможность fork в GitHub **не устанавливают** разрешение публиковать модифицированные бинарные сборки, переиспользовать торговые обозначения и распространять сторонние native файлы. Право International-публикации остаётся неустановленным. В этом PR не добавляется произвольно выбранная лицензия на весь upstream-код.

Перед распространением нужны:

1. Явная применимая лицензия/письменное разрешение правообладателей исходников и условия производных работ.
2. Provenance и разрешения каждого native helper, WCDB wrapper, WeChat hook, модели, иконки/шрифта/ресурса; исходники для выполнения обязательств там, где они требуются.
3. Реальный third-party notices/SBOM финального ASAR и installers, а не только списка npm-пакетов.
4. Проверка GPL/LGPL и иных условий поставляемого FFmpeg: source offer/соответствующие исходники, notices, параметры сборки и модель распространения. Готовое юридическое заключение о лицензии всего приложения из этого не следует.
5. Отдельные appId/бренд/подписи и разрешённое использование знаков TraceMemo/WeChat; условия Tencent API, модификации процесса и получения ключей также требуют проверки.

Проверенные declarations npm: `electron-updater` MIT, `koffi` MIT (поле внутри metadata), `@napi-rs/system-ocr` MIT, `sherpa-onnx-node` Apache-2.0, **`ffmpeg-static` GPL-3.0-or-later**. Лицензия wrapper не заменяет проверку лицензии конкретного binary/model. Лицензия SenseVoice artifact не проверена по карточке/условиям весов, её нельзя угадывать из лицензии recognizer library.

## Lockfile и advisories

`packageManager=pnpm@7.33.7`, CI Node 22; множество manifest ranges `^`, но [pnpm-lock.yaml](../../pnpm-lock.yaml) фиксирует установленные версии и integrity. Имеются platform packages macOS/Windows и optional runtimes. Lockfile не изменён.

Получен `pnpm audit --json` без install/fix: **129 advisory records: 1 critical, 79 high, 41 moderate, 8 low**, metadata totalDependencies=1022. Нулевые devDependencies в ответе registry — свойство отчёта, **не доказательство**, что все 1022 являются production dependencies. [Полный список с locked version и paths](evidence/dependency-advisories.csv) сохранён. Запрос передавал npm registry технический dependency graph, без WeChat данных или секретов. Snapshot сделан до уточнения static-only; повторная отправка на этапе подготовки документов не выполнялась.

| Пример | Установленная версия / сигнал registry | Контекст и необходимая проверка |
| --- | --- | --- |
| `tar` | `6.2.1`, critical `GHSA-23hp-3jrh-7fpw`, unlimited decompression/parse DoS | Цепочка electron-builder → app-builder-lib → @electron/rebuild → node-gyp → tar. Build-time поверхность, не доказанное удалённое исполнение в приложении |
| `electron` | `43.1.0`, high: `GHSA-j84w-jfhq-vhvj`, `GHSA-qmv3-fv6v-rmhq`, `GHSA-9qh4-3jw8-366w` | Electron находится в devDependencies, но его runtime поставляется пользователю. Условия protocol/preload/webview различаются; проверить достижимость и актуальную поддерживаемую исправленную ветку |
| `vite` | `7.2.7`, file-read/fs.deny/dev-server advisories | Dev/build поверхность. Не открывать dev server в Интернет; провести обновление с regression tests |
| `minimatch`, `brace-expansion`, `undici`, `sharp` и прочие | Разные версии/цепочки и условия, см. CSV | Нужна раздельная классификация runtime, tooling и optional platform; количество advisories не равно количеству доступных атак |

Указанные patched ranges сохранены как ответ registry, не как универсальная рекомендация версии: например, tar advisory предлагает `>=7.5.19`, но прямой override транзитивного major может сломать node-gyp. Не применять `audit fix --force` и не подменять checksum. Отдельным PR обновить минимально необходимые цепочки, проверить upstream advisories и итоговый binary SBOM; не обещать «исправлены все уязвимости» по одному успешному audit.

## Postinstall и загрузка исполняемого кода

Скрипты просмотрены как текст; после перехода в static-only они не выполнялись.

| Компонент | Фактические действия | Trust boundary / вывод |
| --- | --- | --- |
| Root `postinstall` | `electron-builder install-app-deps`, `prepare-electron-runtime.cjs`, `ensure-electron-binary.cjs` | Установка не является пассивным скачиванием JS. Могут выполняться native dependency lifecycle и внешние загрузчики |
| `prepare-electron-runtime.cjs` | Проверяет архитектуру FFmpeg, удаляет неподходящий binary в node_modules, запускает installer `ffmpeg-static`; chmod; ad-hoc codesign на macOS; на Windows копирует VC DLL | Файлы tarball integrity не покрывают новый FFmpeg binary. ELF в `scripts/binary-arch.cjs` не распознаётся: на Linux повторная подготовка считает FFmpeg неизвестным и скачивает заново; это setup defect/повторная сеть, не malware |
| `ensure-electron-binary.cjs` | Проверяет `path.txt`/наличие executable, запускает `electron/install.js`, читает mirror из `.npmrc`, имеет fallback npmmirror | Наличие executable само по себе не проверяет его происхождение. Установщик `electron@43.1.0` использует `@electron/get` с package `checksums.json`; нельзя выключать checksum/TLS. npm-config mirror имеет приоритет у этой зависимости |
| `ffmpeg-static@5.3.0` installer | Загружает gzip binary, README, LICENSE с GitHub eugeneware, принимает env override binary URL/tag | В прочитанном installer нет независимого pinned SHA-256 binary. Lock integrity защищает installer package, не полученный файл. Нужен утверждённый manifest binary hashes или иной проверяемый путь |
| `prepare-win-runtime.cjs` | При отсутствии sherpa runtime запускает `pnpm install --force --ignore-scripts` | Не использовать как неожиданную «проверку»: это mutation/install; нет frozen flag в исходном fallback |
| `prepare-wechat-native-runtime.cjs` | Копирует локальный external artifact из `--source`, env или `.native-runtime-source`, проверяет Mach-O headers, manifest и embedded strings, staging hashes | Не скачивает host из hardcoded domain. SHA, находящийся строкой в dylib и совпадающий с manifest того же комплекта, не является независимой подписью или доказательством соответствия исходникам |
| `after-pack.cjs` | Изменяет/чистит packaged resources, отсекает чужие архитектуры, проверяет доступность bindings, выполняет macOS codesign | Это активный packaging hook, требует отдельного review. Ad-hoc подпись `-` не подтверждает личность поставщика |
| `voice-pipeline/model-manager.ts` | Загружает ONNX/tokens через `net.fetch`, проверяет фиксированные размер/SHA-256 перед rename | Положительная integrity-защита. Последующая `isVerified` проверяет manifest и размеры, не перехэширует content при каждом открытии; не защита от локального same-size tampering |
| Optional `installPilk` | Запускает `python -m pip install --user pilk==…` | Дополнительный package execution вне pnpm, без hash-locked requirements; не запускать при аудите |
| Share deployment helper | npm/Wrangler, OAuth, создание R2/bindings/secrets, deploy, health requests | Отдельная инфраструктура/публикация; не часть безопасной desktop bootstrap-команды |

Корневой `index.js` — tracked скомпилированный preload-подобный файл. Текущий entry `package.json.main=out/main/index.js`, preload окна — `out/preload/index.js`; наличие root `index.js` не доказывает его исполнение. Не удалён как «чистка» в этом PR.

## Native inventory

[native-binaries.csv](evidence/native-binaries.csv) фиксирует размер, SHA-256 и `file` architecture для **19** tracked PE/Mach-O. Они читались как данные, не загружались через FFI и не запускались в static-only.

- Windows x64: `wx_key.dll`, `wcdb_api.dll`, `WCDB.dll`, `SDL2.dll`, четыре VC runtime DLL.
- macOS: архитектурные `wcdb/macos/{arm64,x64}/{libwcdb_api,libWCDB}.dylib`, общие fallback dylibs, universal `libwx_key.dylib`, Intel key helper, `xkey_helper` и `xkey_helper_4_1_13`.
- `xkey_helper_4_1_13.sha256` присутствует; офлайн-проверка в этом аудите подтвердила совпадение sidecar с SHA-256 файла. Wrapper не содержит обязательной проверки этого sidecar перед запуском. Sidecar в том же репозитории также не заменяет publisher signature/provenance.
- macOS send runtime `resources/runtime/darwin-arm64` отсутствует в tracked tree и игнорируется; для расширенной сборки нужны external `tm-wechat-host`, `libtmwechat.dylib`, `runtime-manifest.json`.
- Полных исходников собственных WCDB wrappers/key helpers/send host в этом checkout нет. Архитектурно корректный Mach-O/PE и наличие валидной подписи не доказывают отсутствие сетевого кода.

`KeyServiceMac` запускает arm64 helper через `osascript` с administrator privileges и Intel helper через spawn. `KeyServiceWin` загружает DLL через koffi, читает память процесса для key discovery. Это чувствительные штатные функции, для которых нужны версия WeChat/OS compatibility, явное согласие и проверяемый binary provenance. Не запускать их в аудите, не менять SIP и не устанавливать хуки.

## Допуск к следующему этапу

Новый [скрипт безопасной установки](../development/scripts/install-audited-dependencies.sh) создаёт только дерево npm-зависимостей с отключёнными lifecycle scripts. Сейчас он **не выполнялся**. Он не превращает уже установленные ранее артефакты в проверенные и не даёт разрешение запускать TraceMemo. Для native и Electron/FFmpeg activation нужен отдельный reviewed artifact manifest и следующая явная задача. Публикация заблокирована вопросами лицензии и идентичности независимо от успешности сборки.
