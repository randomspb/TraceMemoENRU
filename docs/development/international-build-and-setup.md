# Сборки и безопасная подготовка следующего этапа

Текущий режим — **первоначальный статический аудит**. Нельзя запускать install/rebuild/postinstall, проектные tests/build/dev/deploy/release scripts, native-компоненты или запросы из исследуемого кода. Этот документ не отменяет ограничение; команды ниже предназначены для следующей явно разрешённой задачи.

## Что проверено в сборочной архитектуре

Electron + React + TypeScript собирается electron-vite; `main`, `preload`, `renderer`, knowledge и voice worker entry points определены в [electron.vite.config.ts](../../electron.vite.config.ts). CI использует Node 22, pnpm 7.33.7, Windows/macOS, types/unit/component/integration/Electron E2E. CI **не** доказывает signed installer build и native compatibility на любой версии WeChat.

Upstream release API на дату аудита показывает `v2.5.1`: существуют macOS arm64 DMG (203760413 bytes) и ZIP (196930296 bytes), Intel macOS DMG/ZIP, Windows NSIS EXE (149955954 bytes), update yml и blockmaps. Это доказательство опубликованных artifacts, не воспроизводимости из текущего checkout. Артефакты не скачивались и не запускались в этом аудите; подписи, состав и происхождение их binaries не проверены.

| Target | Что предусмотрено кодом | Что ещё требуется |
| --- | --- | --- |
| macOS arm64 | `build:mac:arm64`: typecheck → platform FFmpeg preparation → electron-vite → electron-builder DMG+ZIP; tracked arm64 WCDB и xkey helper | Нативный arm64 macOS runner; review external artifacts, подписей, лицензий, OS/WeChat compatibility; Developer ID/notarization для собственного распространения |
| macOS arm64 send runtime variant | Отдельные script/config с `TM_SEND_RUNTIME_BUILD=1`, include local `resources/runtime/darwin-arm64` | В tracked tree runtime отсутствует. Нужны отдельно проверенные host/dylib/manifest из законного источника; нельзя считать обычную сборку полной send-runtime сборкой |
| Windows x64 | `build:win`: typecheck → Windows sherpa+FFmpeg preparation → electron-vite → отдельный builder NSIS config; DLL resources имеются | Windows x64 runner; native dependencies и Microsoft redistributable permissions; code signing и installer/update smoke. Если optional sherpa отсутствует, исходный helper делает install mutation |
| Linux cloud | Возможны статический review, обработка текстов и подготовка документации | Это не доказательство macOS signing/Windows installer. Linux native WeChat library в репозитории отсутствует; cross-build не заменяет target tests |

`npmRebuild:false` в packaging делает наличие корректных prebuilt dependencies особенно важным. React/TS JS-build не проверяет правильность архитектуры каждого native binding. `.npmrc` и package supportedArchitectures имеют разный охват платформ; final artifacts проверять, а не предполагать, что optional install всегда сохранил нужный runtime. macOS config `notarize:false`, entitlements позволяют JIT/unsigned executable memory/DYLD; Windows config ограничивает Electron languages zh-CN/en-US. Для будущего русского UI нужен `ru-RU`.

Все `release:*` scripts содержат/наследуют публикацию в **Wxw-Gu/TraceMemo**. Их запуск запрещён. До любого packaging International требуется separate identity/update/publish configuration, без publish credentials в test jobs. Будущие локальные packaging команды должны явно использовать `--publish never` и reviewed fork config; их здесь не выполняли.

## Отдельный безопасный install script

[install-audited-dependencies.sh](scripts/install-audited-dependencies.sh) подготовлен для следующего этапа. Он:

- требует уже установленный Node 22 и ровно pnpm 7.33.7, ничего не bootstrap-ит через `curl | sh`/corepack auto-install;
- требует чистые manifest/lockfile и отсутствие `node_modules`, чтобы не переиспользовать выполненные ранее artifacts;
- использует frozen lockfile, explicit registry, `--ignore-scripts`, `--ignore-pnpmfile`, strict TLS и store integrity; не выполняет activation/rebuild;
- не запускает helpers, Electron, FFmpeg, root postinstall, проектные tests или build;
- сохраняет cache/store вне исходников и проверяет отсутствие diff manifest/lockfile после команды.

Скрипт **не выполнялся**; выполнена только shell syntax/static проверка. На текущей onboarding машине уже есть зависимости от прежней настройки, поэтому он намеренно откажется их считать чистым безопасным состоянием. Не удалять их автоматически: для следующего этапа выбрать свежую задачу/среду либо отдельно согласованное сохранение/удаление старых outputs. Даже `--ignore-scripts` не гарантирует, что пакеты не содержат вредоносный код; оно предотвращает автоматические lifecycle execution при скачивании.

`ignore-scripts` оставит некоторые native/tooling components неготовыми. Это ожидаемый результат ограниченного bootstrap, **не рабочая desktop среда**. Не завершать его автоматическим `pnpm rebuild`, поскольку это вновь запустит все lifecycle scripts.

## Порядок следующего допуска

1. Разобрать license/provenance и `api.weflow.top` native finding; утвердить список бинарников, независимые SHA/signatures и источники. Не использовать реальные профили.
2. Обновить применимые vulnerable зависимости отдельным PR с анализом lockfile, без произвольных overrides и checksum замен. Отдельно определить toolchain и TLS/proxy trust.
3. В явно разрешённой следующей задаче выполнить safe JS dependency bootstrap в чистой среде. Не предоставлять release secrets и реальные API keys; держать производственные профили вне среды.
4. Для каждого необходимого lifecycle/FFmpeg/Electron activation — разрешённая отдельная команда и проверяемые artifacts; фиксация всех destinations. Отказаться от непроверенных fallback mirrors/artifacts, не отключать TLS/integrity.
5. После разрешения runtime tests — synthetic-only локальные mocks, блокировка внешней сети, offline/render/API auth/negative tests. Platform builds и подписывание выполнять на целевых ОС, без публикации.
6. Публикация — только после отдельного явного решения владельца и устранения юридических/безопасностных blockers. Создание PR этого не разрешает.

## Что уже запускалось до статического ограничения

Существующие целевые проверки до уточнения режима: 6 unit files / 50 tests, 3 integration files / 96 tests, 5 worker tests — pass. Они использовали temp fixtures/mocks/loopback, не реальные WeChat данные. После уточнения повторных проектных запусков не было. Более ранние onboarding результаты сборки/тестов относятся к подготовке среды, а не являются новой верификацией macOS/Windows artifacts в этом аудите.
