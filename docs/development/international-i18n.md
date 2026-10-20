# Архитектура i18n для TraceMemo International

Статус: **проект решения**, реализация/перевод в этот PR не входят. Поддерживаемые locale: `en-US`, `ru-RU`, `zh-CN`. Основание — структура проверенного commit `c366dd11871d75d5f511e843605b689731759622`, см. [аудит](../security/README.md).

## Текущая структура и ограничения

React 19 renderer обращается к Electron main через preload; shared DTO задают интерфейсы. В main находятся native/DB adapters, API, фоновые workers, lifecycle, меню/диалоги и отчёты. Renderer содержит как JSX, так и самостоятельные helpers и report generation hooks. i18n библиотеки в корневых dependency declarations сейчас нет.

Текст распределён между JSX, main errors/dialogs, report HTML/resources, shared labels, AI prompts и deterministic parsing. Форматирование даты часто жёстко `zh-CN`: report history/info/settings, search formatters, automation/monitor UI; `GroupStatsService` сортирует `zh-Hans-CN`. HTML renderer не содержит `lang`. Windows packaging сохраняет только `zh-CN`, `en-US` Electron languages, `ru-RU` отсутствует. Это точки внедрения, а не основание массово менять все строки.

Нельзя механически переводить китайские regex и строки WeChat протокола. Например, [agent-hub-routing](../../src/main/services/agent-hub-routing.ts) использует китайскую лексику для маршрутизации команд, [message-parser](../../src/main/message-parser.ts) распознаёт реальные WeChat payload. Их изменение — отдельная продуктовая задача с тестами. Перевод UI не должен менять распознавание исходных чатов.

## Предлагаемые границы

```text
src/shared/i18n/          Locale union, message keys/params, pure formatting contracts
src/renderer/src/i18n/   React provider/hooks; bundled en-US, ru-RU, zh-CN catalogs
src/main/i18n/           Pure translator for menus/dialogs/background notifications
                         (без импорта React и renderer globals)
```

Это будущие директории. Не создавать вторую бизнес-логику для каждого языка. Выбрать `i18next` + `react-i18next` как основной кандидат для последующего небольшого ADR/PR: поддерживает plural rules и shared core; зафиксировать точные версии, лицензии и lockfile только после supply-chain review. Не добавлять HTTP backend/plugin для загрузки переводов: каталоги входят в bundle и работают offline. `Intl.DateTimeFormat/NumberFormat/PluralRules` использовать через маленькие общие wrappers, а не вводить вторую библиотеку для тех же задач.

| Слой | Что локализовать | Что сохранять стабильным |
| --- | --- | --- |
| React | Подписи, кнопки, accessible labels, empty/loading/error presentations | IPC channel names, selectors/data-testid, DTO fields |
| Main | Меню, tray, native dialogs, notifications | Пути storage, account identifiers, native ABI, аргументы helpers |
| Shared/API | Отображение error code в UI; при необходимости additive messageKey/params | HTTP status, machine error codes, schema versions, маршруты и существующие clients |
| Reports | Labels/locale formatting новых отчётов, явный locale при генерации | Имена placeholders/template IDs, версии manifest, исторический snapshot |
| AI | Язык отображения результата как отдельный будущий параметр | Tool JSON schemas, protocol fields, security prompts и retrieval semantics |
| WeChat parsing | Только UI-представление разобранного результата | Оригинальный текст, wxid, server event patterns, timestamps |

## Выбор языка и хранение

Порядок: явный `settings.locale` → точное совпадение поддерживаемого system locale → согласованное соответствие `en*`/`ru*`/`zh*` → документированный fallback `en-US`. Для существующих профилей безопаснее сохранить `zh-CN` при первом добавлении поля; это **предложение миграции**, которое надо утвердить тестами, чтобы обновление не сменило язык молча. Разделить поддержку UI-language, content language и timezone: переключение на русский не меняет пояс и календарную семантику расписаний.

Main валидирует enum, сохраняет setting атомарно, уведомляет renderer typed locale event. Renderer не получает произвольный filesystem path каталога; worker получает locale только если формирует пользовательский текст. Смена языка не перезапускает DB session, не сбрасывает ключи и не отправляет сеть. Использовать существующий settings pipeline с additive field и миграционными тестами.

Каталоги группировать по областям `common`, `connection`, `settings`, `search`, `reports`, `automation`, `apiCenter`, `security`. Стабильные semantic keys (`connection.invalidDatabaseKey`) удобнее китайского исходного текста как ключа. Полные предложения с typed parameters; не конкатенировать переведённые части и не помещать wxid/сырой контент в ключи.

Для русского обязательны формы `one/few/many/other`, для английского `one/other`, для китайского — применимые правила выбранного движка. Interpolation выводится через React text nodes; избегать `dangerouslySetInnerHTML`. Переводы не должны содержать executable markup, URLs поставщиков или условия авторизации. Rich text — только заранее разрешённые компоненты, external links проходят общий main URL guard.

## Форматирование и совместимость

- Эпоха/ISO timestamp в API остаётся прежней; display format использует explicit locale/timezone. Переход на `ru-RU` не должен менять фильтр «сегодня» или время cron.
- Сортировка contact names по locale может менять порядок и paginated results. Переводить сначала presentation; алгоритмическую сортировку/кеш-ключи менять отдельным PR с проверкой стабильности.
- API machine codes оставить независимыми от locale. Не ломать внешние агенты заменой русским текстом существующих codes. Новые error enums добавлять аддитивно, переиспользовать существующие, когда они есть.
- Ошибки из native/OS/remote provider показывать как безопасное detail с локализованной оболочкой; не переводить и не выводить необработанный secret-bearing provider response.
- Исторические HTML/PNG не регенерировать при смене UI locale. Для новых snapshot сохранять report locale и формат/version, без изменений raw messages.
- Китайские промпты/intent regex отделены от UI catalogs. Поддержка англо-/русскоязычных agent commands — отдельный этап с теми же tool/data boundaries и отдельными fixtures.

## План внедрения малыми PR

1. После security fixes: locale type/settings migration + bundled provider, один простой экран About/настройка языка; `zh-CN` catalog переносит исходные тексты без изменения смысла.
2. Подключить main menus/dialogs; добавить `ru-RU` в packaging languages и проверить Electron/Intl data на целевых ОС.
3. Последовательно переносить connection, settings, search, reports, automation; каждый PR меняет presentation и related tests, не native/AI логику.
4. Отдельно: locale отчётов и язык ответов AI, без изменения prompt security и protocol parsing в UI PR.

Критерии приёмки следующего этапа: все три catalogs имеют одинаковые keys/params, отсутствующие ключи ломают CI; unit tests plural/date/time, UI tests смены языка и сохранения, bounds для длинных русских строк, screen reader labels, по одному smoke flow на locale. Business regression tests подтверждают одинаковые IPC requests и DB results при разных locale. Библиотека и новые tests пока не устанавливались и не запускались.
