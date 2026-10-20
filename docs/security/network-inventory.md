# Сетевые соединения и данные

База: `c366dd11871d75d5f511e843605b689731759622`. Это **статический перечень источников соединений**, не packet capture. Реальные пользовательские данные для исследования не использовались. Из кода исследуемого приложения сетевые запросы на этапе static-only не выполнялись.

## Как читать перечень

[network-literals.csv](evidence/network-literals.csv) содержит 317 уникальных сочетаний host/source/line/context/kind, 74 host-like значения по всем 878 tracked-файлам базового commit. ASCII URL извлекались из всех файлов; из native PE/Mach-O дополнительно проверялись UTF-16LE URL, а из TS/JS/config — hostname literals. Бинарные смещения и SHA зафиксированы отдельно. Строки из тестов, docs, SVG/XML namespace и комментариев не означают соединение. Например, `www.microsoft.com0` — артефакт грубого выделения строки в бинарнике, а не подтверждённый endpoint.

Статические URL дополнены ручной проверкой `fetch`, alias `fetchImpl`, `net.fetch`, `http/https.get/request`, `net.createConnection`, `shell.openExternal`, `window.open`, image/media sources, dependency downloaders и shell deployment commands. NUL в `ai-search-pipeline-service.ts` требует `rg -a`; этот файл не пропущен как binary.

**Конечный перечень всех возможных доменов перечислить невозможно:** пользовательские AI URL, URL из сообщений и ответы серверов допускают динамические хосты и redirects. Ниже явно перечислены эти классы, их источники и payload. Не заменять их `*` в сетевых настройках. Произвольный домен из docs — не автоматическое разрешение egress.

## Рабочее приложение: фиксированные назначения

| Домен / endpoint | Запрос и условие | Что передаётся | Источник |
| --- | --- | --- | --- |
| `api.openai.com/v1`, `api.anthropic.com/v1`, `api.deepseek.com`, `dashscope.aliyuncs.com/compatible-mode/v1`, `api.moonshot.cn/v1`, `api.minimax.chat/v1` | Пресеты выбранного AI provider; POST `/chat/completions`, `/responses` или `/messages` | Auth bearer/x-api-key/custom header, model, prompts, вопрос, выбранные сообщения и имена/время, история, tool schemas/results; vision может включать image data URL | [presets](../../src/renderer/src/features/settings/ai-model/presets.ts), [AI transport](../../src/main/services/ai-provider-service.ts#L858) |
| `opencode.ai/zen/go…` | Только если пользователь указал этот endpoint; тот же AI transport | Дополнительно `x-opencode-session` (sessionId или random UUID), default User-Agent `TraceMemo`; это не отдельный автоматический backend | [requestProvider](../../src/main/services/ai-provider-service.ts#L746) |
| `api.fish.audio/model`, `/model/{id}`, `/v1/tts` | GET список/выбранный голос; POST по synthesize | API bearer; параметры поиска голоса, язык, tags; TTS: text (до 1000 символов), reference_id, model и формат MP3 | [TTS service](../../src/main/services/text-to-speech-settings-service.ts) |
| `public-platform.r2.fish.audio` | Изображения/демо голоса из metadata | IP и HTTP metadata, путь asset; не автоматическая загрузка переписки | тот же service, преобразование voice metadata и renderer voice UI |
| `ilinkai.weixin.qq.com/ilink/bot/get_bot_qrcode?bot_type=3` | POST при login | `local_token_list` предыдущих bot tokens (до 10), app/protocol headers | [auth](../../src/main/services/wechat-ilink/auth.ts) |
| `ilinkai.weixin.qq.com/ilink/bot/get_qrcode_status` и login redirect host | GET long-poll при login | QR credential в query, при необходимости verify_code; без business bearer | [auth](../../src/main/services/wechat-ilink/auth.ts#L95) |
| iLink base URL: `/ilink/bot/getupdates` | POST long-poll при активном connector | Bot bearer, cursor `get_updates_buf`, `base_info`, app version headers, random `X-WECHAT-UIN` | [client](../../src/main/services/wechat-ilink/client.ts), [headers](../../src/main/services/wechat-ilink/headers.ts) |
| iLink: `/sendmessage` | POST ответ/сообщение | Получатель, client ID, text либо media references и media AES key, context_token, bearer, base_info | тот же client, [sender](../../src/main/services/wechat-ilink/sender.ts) |
| iLink: `/getuploadurl` | POST перед upload | Получатель, filekey, размер plaintext/ciphertext, MD5 plaintext, `aeskey`, media type, bearer/base_info | [media](../../src/main/services/wechat-ilink/media.ts#L168) |
| iLink: `/getconfig`, `/sendtyping` | POST для typing state | user ID, context token или typing_ticket, status, auth/base_info | [client](../../src/main/services/wechat-ilink/client.ts#L236) |
| iLink: `/ilink/bot/msg/notifystart`, `/notifystop` | POST при запуске/остановке connector | Bearer и base_info: lifecycle и идентификатор приложения | [client](../../src/main/services/wechat-ilink/client.ts#L276) |
| `novac2c.cdn.weixin.qq.com/c2c/upload`, `/download` | POST encrypted media / GET encrypted media | Ciphertext, encrypted query parameters, filekey; key дополнительно передаётся iLink API | [media](../../src/main/services/wechat-ilink/media.ts) |
| `huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/…` | GET `model.int8.onnx`, `tokens.txt` по downloadModel | Только путь модели и стандартные HTTP metadata; речь не загружается этой операцией | [model manager](../../src/main/voice-pipeline/model-manager.ts#L12) |
| `github.com`, `api.github.com`, GitHub release asset hosts | Packaged startup/manual update metadata; download после действия пользователя | Версия/канал/архитектурно выбранный metadata path, headers, IP; `x-user-staging-id` persistent UUID; no chat payload в просмотренном пути | [update service](../../src/main/services/app-update-service.ts), `electron-updater@6.8.9`, [feed](../../build/app-update.yml) |
| `raw.githubusercontent.com/Wxw-Gu/TraceMemo-Templates/main/catalog/v1/index.json` | GET каталога при открытии/установке; GET preview/ZIP, pinned commit | User-Agent `TraceMemo`, Accept и путь шаблона; без переписки. Catalog задаёт package SHA-256, redirects запрещены | [market](../../src/main/report-template-market-service.ts), [constant](../../src/shared/report-template-market.ts) |
| `api.weflow.top/api/report`, `/api/token` | **Только строки native-файла; исполнение не установлено** | Неизвестно: нельзя выводить поля из имени endpoint | [S-01](initial-audit.md#s-01-непроверенный-native-компонент-содержит-cloud-report-endpoints), SHA/offset в отчёте |

`api.deepseek.com` также указан в `.env.example` и legacy default provider. Заполненный URL сам по себе не вызывает запрос: требуется соответствующий рабочий путь AI. iLink AES media encryption не следует называть доказанным end-to-end шифрованием от Tencent: `getuploadurl` явно получает `aeskey`. Это media key, а не ключ локальной WeChat БД.

## Динамические назначения и автоматическая загрузка ресурсов

| Источник адреса | Операция | Данные и риск |
| --- | --- | --- |
| Пользовательский `AIProviderConfig.baseUrl` и extraHeaders | POST к выбранному AI endpoint; в transport нет общего HTTPS-only gate | Те же AI payload и auth. Произвольный recipient; HTTP/redirect downgrade требуют отдельной политики. [AIProviderService](../../src/main/services/ai-provider-service.ts#L700) |
| Login `baseurl`/`redirect_host`; iLink `upload_full_url` | Login/business requests к возвращённому host; media upload | Business bearer/context и ciphertext в соответствующих путях. Нужны проверки scheme/host каждого нового адресата; никакой конечный allowlist не следует из одной константы iLink. [client](../../src/main/services/wechat-ilink/client.ts#L104), [auth](../../src/main/services/wechat-ilink/auth.ts), [media](../../src/main/services/wechat-ilink/media.ts) |
| Sticker `cdnUrl` из содержимого сообщения | `http/https.get`, до 5 redirects, скачивание при cache miss | Исходный URL/query может идентифицировать asset/получателя. Заголовки User-Agent и Referer `https://weixin.qq.com/`; **Referer — не отдельный запрос к weixin.qq.com**. Нужны byte/DNS/redirect limits. [sticker-service](../../src/main/sticker-service.ts#L122) |
| Avatar URL из контакта, удалённая картинка | GET при report embedding/export; renderer `<img>` | IP и точный URL; не POST чатов. [group-report-service](../../src/main/group-report-service.ts#L188), [export-service](../../src/main/export-service.ts#L601) |
| `article.coverUrl`, mini-program icon, avatar и другие HTTPS image/media sources из сообщений/metadata | Browser GET при отображении | Может раскрыть факт просмотра/сетевой адрес; у ряда элементов `referrerPolicy=no-referrer`, но это не запрет сети. Main renderer CSP разрешает `https:` img/media. [RichMessageBubble](../../src/renderer/src/components/RichMessageBubble.tsx), [CSP](../../src/renderer/index.html) |
| URL remote media для iLink send | GET source, затем encrypt/upload/send | Загружается файл по адресу, его содержимое отправляется получателю через Tencent. Источником может быть URL из AI/markdown либо явного запроса. [sendMediaFromUrl](../../src/main/services/wechat-ilink/media.ts) |
| Настроенный share-card `serviceUrl` | POST `/api/cards` по publish | Upload bearer, полный PNG отчёта и JPEG thumbnail в base64, title/description, expiry. HTTPS обязателен кроме localhost/127.0.0.1. `share.example.com` — placeholder, не адрес автора. [service](../../src/main/wechat-share-card-service.ts) |
| `TRACEMEMO_QUERY_API_BASE` в POC harness | POST local-query endpoints | Вопросы/параметры и local API bearer на переопределяемый адрес; по умолчанию loopback. Это dev entry, не default app egress. [POC](../../src/main/query-agent-poc-entry.ts) |
| Redirects Hugging Face / GitHub / npm artifacts | GET файла на CDN/storage | HTTP metadata, подписанные download query. Конкретные CDN-хосты не захардкожены в first-party model manager; допустимы только после наблюдения/проверки trusted chain. Не выдаются за уже наблюдённые соединения |

## Локальные соединения

| Адрес | Назначение и payload | Граница |
| --- | --- | --- |
| `127.0.0.1:6131` (default, configurable bind/port) | HTTP API: контакты, сообщения, поиск, media, voice transcript, отчёты, automation/send. Bearer обязателен кроме `/api/v1/health` | API **включён по default settings**, но fail-closed без secure token store. CORS loopback-only не заменяет auth. [Routes](../../src/main/http-server.ts) |
| `127.0.0.1:11434/v1` | Ollama preset, POST AI context | Local AI всё равно получает plaintext контекст; другие локальные процессы/пользователь контролируют службу |
| `127.0.0.1:4290` | macOS send host: health/binding/status, POST `/sendText`, `/sendImage`, `/sendVoice` | Получатель, текст или локальный path/параметры media. В TS-запросах нет bearer. Нативный endpoint policy не подтверждён исходниками host. [manager](../../src/main/services/mac-wechat-runtime-manager.ts#L41), [send service](../../src/main/services/personal-wechat-send-service.ts) |
| `127.0.0.1:<windowsWechatPort>` | Hook `/getLoginInfo`, send endpoints из адаптера | Получатель, текст, media paths; порт валидируется как число, host фиксирован loopback. Не remote arbitrary host. [port handling](../../src/main/services/personal-wechat-send-service.ts#L49) |
| Native monitor pipe | `net.createConnection(this.monitorPipePath)` | Локальный named pipe/IPC для database change events, не фиксированный Internet socket. [WCDB client](../../src/main/wcdb4-client.ts#L1008) |
| `wxe-media://local/<random-token>` | Custom protocol для локальных media | Сопоставление opaque token → заранее зарегистрированный path, не Интернет и не произвольный URL-path. [VideoAssetService](../../src/main/video-asset-service.ts#L107) |
| `localhost:5173` | Vite renderer только в dev workflow | Dev resources/HMR. Не раскрывать dev server наружу; потенциальные Vite advisories см. dependency snapshot |

API routes включают `/api/v1/contact`, `/chatroom`, `/recent_chat`, `/chatlog`, `/group_snapshot`, `/resolve`, `/report`, `/agent/{status,send,group-report}`, `/scheduled-reports…`, `/wechat-personal/send-capability`, `/media/…`, `/query/{capabilities,messages,search,message-context,conversation-overview,voice-transcribe}`, `/capabilities`, `/monitors/group-exits…`, `/groups/<id>/member-stats`, `/automations…`, `/skill/tracememo-reader`, `/current_time` и health. Полный routing — [http-server.ts](../../src/main/http-server.ts); единый token не ограничен read-only ролью.

## Optional share-card worker

Это отдельный Cloudflare Worker + R2, а не обязательный daemon настольного приложения. [Source](../../services/share-card-worker/src/index.js), [deployment](../../docs/deployment/experimental-wechat-share-card.md).

| Домен/route | Данные |
| --- | --- |
| Настроенный public origin `/api/cards` | Загрузка отчёта с upload bearer; R2 получает card metadata и изображения |
| `/s/<uuid>`, `/l/<uuid>`, `/v/<uuid>`, `/a/<uuid>/…` | Публичное чтение до expiry, UUID — bearer-like capability; visitor identity не проверяется |
| `/api/wx-signature?url=…` | Browser передаёт текущий page URL сервису для подписи; сам сервер рассчитывает SHA-1 подпись локально |
| `api.weixin.qq.com/cgi-bin/token` | GET appid, appsecret, grant_type в query |
| `api.weixin.qq.com/cgi-bin/ticket/getticket` | GET access_token и type=jsapi; токены кэшируются worker |
| `res.wx.qq.com/open/js/jweixin-1.6.0.js` | Browser GET внешнего JS; скрипт исполняется в share page и получает share title/description/link/thumbnail через wx API. Дополнительное поведение этого удалённого JS не проверено |
| `https://wechat-cache.invalid/<cacheKey>` | Синтетический key для Cloudflare cache API, **не внешний fetch** |

Cloudflare control plane использует `api.cloudflare.com`, OAuth/login dashboard и настроенный Worker/R2 domain при деплое; хосты Wrangler зависят от его версии/маршрута входа. Deployment script и Wrangler в этом аудите не запускались. Нужны отдельные разрешения и секреты, не production реальные значения в `.env` для сборки desktop.

## Toolchain и supply-chain endpoints

Это назначения установки/CI, а не функции чтения переписки. Они не запускались после перехода в static-only.

| Домен/класс | Потребитель и payload |
| --- | --- |
| `registry.npmjs.org` (или явно настроенный registry), registry tarball hosts | pnpm/npm metadata и archives; `pnpm audit` POST dependency names/versions. Package-lock integrity проверяет tarball, а не отдельный скачиваемый executable |
| `npmmirror.com/mirrors/electron/` | Repository `.npmrc` и fallback в ensure-electron; downloads Electron version/platform/arch и checksum metadata |
| `github.com/electron/electron/releases/download`, `release-assets.githubusercontent.com` / GitHub-controlled redirects | Официальные Electron artifacts/checksums; helper допускает ELECTRON_MIRROR override. В `@electron/get` npm config mirror имеет приоритет над ELECTRON_MIRROR |
| `github.com/eugeneware/ffmpeg-static/releases/download` и redirects | `ffmpeg-static@5.3.0/install.js` скачивает binary gzip, README, LICENSE по tag/platform/arch; независимого pinned binary hash в этом installer не найдено |
| GitHub Electron/electron-builder binary repositories и redirects | electron-builder/install-app-deps, platform build helpers; точные paths зависят от сборочного target и dependency implementation |
| `pypi.org`, `files.pythonhosted.org` либо configured pip index | Optional installPilk запускает `python -m pip install --user pilk==<version>`; нет hash-pinned requirements. Не выполнять в static-only. [voice environment](../../src/main/services/personal-wechat-voice-environment-service.ts) |
| Playwright browser download CDN | `playwright install chromium` в CI; exact hosts computed зависимостью, не first-party константами. Electron smoke не требует отдельного Chromium install |
| GitHub actions infrastructure | checkout/action-setup/setup-node/upload-artifact; тестовые traces/screenshots могут содержать данные, поэтому только synthetic fixtures. Actions pinned by tag, не SHA |

## Ссылки, которые открываются по действию пользователя

- `maps.apple.com`: координаты `lat/lng` и location label в query при клике в карте; это пользовательские данные, отправляемые внешнему browser при этом действии ([RichMessageBubble](../../src/renderer/src/components/RichMessageBubble.tsx#L118), export HTML template).
- `github.com/Wxw-Gu/TraceMemo…`, `github.com/Wxw-Gu/TraceMemo-Templates…`, `github.com/FunAudioLLM/SenseVoice`, `github.com/k2-fsa/sherpa-onnx`: руководство, about, templates, release page. Встроенный chat payload туда не добавляется.
- `www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip`, `brew.sh`, `ffmpeg.org/download.html`, `www.python.org/downloads/macos/`, `aka.ms/vc14/vc_redist.x64.exe`: download/help links; не автоматический installer в просмотренном first-party коде.
- `fish.audio/app/api-keys/`: управление TTS ключом, открытие browser.
- Произвольные URL из link/share/mini-program сообщений: открытие по клику через `window.open` → `shell.openExternal`; scheme allowlist требует исправления.

`www.w3.org`, `ns.adobe.com`, `developer.mozilla.org` в XML/SVG/комментариях не являются app egress. Остальные адреса README/docs (включая badges, user guide downloads, тестовые `example.*`) сохранены в CSV с классификацией; просмотр README в GitHub/browser имеет собственные сетевые запросы, которые не следует приписывать main-процессу.

## Телеметрия и неизвестное

Подтверждены библиотечный updater UUID и protocol metadata iLink. Выгрузка DB keys/переписки на фиксированный first-party analytics backend не найдена. **Не установлено** поведение `api.weflow.top` в native library, системных проверок сертификатов и удалённого WeChat JS SDK; CRL/issuer URLs в DLL не доказывают их вызов кодом TraceMemo. Неизвестное помечено, а не объявлено безопасным.
