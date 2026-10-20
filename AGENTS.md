# TraceMemo International: permanent development and security rules

These rules apply to `randomspb/TraceMemoENRU`. Upstream is `Wxw-Gu/TraceMemo` for read-only comparison. Read [the initial audit](docs/security/README.md), [CONTRIBUTING](CONTRIBUTING.md), and the relevant architecture documents before making changes.

## Current stage and authorization

- The current stage is the initial **static security audit and architecture**. Do not translate the UI or change application behavior in this stage.
- Until the owner explicitly authorizes the next runtime/development stage, do not run `pnpm install`, `npm install`, `pnpm rebuild`, postinstall, other project scripts/tests/build/dev/deploy/release commands, or TraceMemo third-party/native binaries. Do not make network requests from the inspected application code. Preparation of an install script is not permission to execute it.
- Reading code, lockfiles, binary headers/strings and calculating hashes is allowed. System analysis tools must treat target binaries as data, never execute or load them. Review any new analysis helper before using it.
- Never connect real WeChat profiles, inspect real chats/keys, capture live account credentials, modify SIP, inject hooks, or attach key acquisition helpers during an audit. Use clearly named synthetic fixtures in a separately authorized test stage.
- Never send user messages, attachments, account identifiers, DB/image keys, API tokens or local profile files outside the environment. Dependency/Git metadata queries must not include these values. Do not probe suspected telemetry endpoints to see what happens.

## Git and review

- Use the existing checkout: cloud tasks are already isolated. Do not create a worktree unless explicitly requested.
- Base work on the fork's `develop`, use a separate descriptive branch, and preserve user changes. Stable/release history remains on `main`.
- PRs target **`randomspb/TraceMemoENRU:develop`**. Use explicit repository arguments, e.g. `gh pr create --repo randomspb/TraceMemoENRU --base develop`. Never push or submit a PR to `Wxw-Gu/TraceMemo`.
- Do not merge, publish releases, change signing/update targets, or upload artifacts without the owner's explicit authorization for that action. A request to prepare a PR does not authorize merge/release.
- One logical change per PR; no drive-by formatting, dependency upgrades, binary replacements or lockfile changes. Follow CONTRIBUTING commit style. Explain the problem, change, validation and unresolved limitations in the PR.
- `AGENTS.md` is intentionally tracked in this fork although inherited `.gitignore` ignores it. Stage this file explicitly with `git add -f AGENTS.md` when needed; do not remove the ignore rule merely to stage it.

## Trust boundaries

- Do not describe a string/advisory as an exploited vulnerability. Cite exact source path and baseline SHA; distinguish confirmed code behavior, conditional risk and unverified native/runtime behavior.
- Network changes require a documented trigger, recipient, data categories, secrets, redirect policy and consent boundary in `docs/security/network-inventory.md`. Do not silently add telemetry, remote translations, chat uploads, fallback endpoints or wildcard allowlists.
- Keep network policy, secret handling, IPC authorization and file access checks in main. Renderer checks and TypeScript annotations are not security enforcement. Use typed allowlisted preload capabilities, sender-frame/origin checks and runtime input validation in future fixes.
- External URL handling must enforce allowed schemes and prevent credential-bearing redirects/downgrades. Remote AI use requires main-side operation/recipient/data-scope authorization; account setup is not blanket permission to upload all chats.
- Never expose DB/image/API keys through ordinary logs, errors, PRs or audit documents. Inspect variable names/presence rather than dumping environments or credential files. `safe-log.ts` handles pipe failures; it is not a redaction service.
- Secrets belong in OS-backed secure storage with explicit failure behavior, file permissions/ACL and tested migrations. Do not introduce plaintext fallback, store real keys in `VITE_*`, or infer Linux `safeStorage` security from availability alone.
- Treat local HTTP API, local send hosts and remote Agent Hub senders as separate authorization boundaries. Loopback/CORS is not a replacement for authentication/scoped authorization. Keep sensitive HTTP endpoints authenticated and reject arbitrary filesystem/SQL inputs.
- Derived caches, OCR, transcripts, reports, backups and logs contain sensitive data even when original WeChat DBs are encrypted. Define retention/clear/revoke behavior; use only synthetic data in artifacts.

## Dependencies, binaries and distribution

- Analyze package scripts and changed dependencies before any explicitly authorized install. Use a frozen lockfile and lifecycle-disabled bootstrap; do not follow it with blanket rebuild. The proposed [safe script](docs/development/scripts/install-audited-dependencies.sh) is for a future authorized clean environment and does not establish runtime readiness.
- Preserve TLS, package integrity, checksums and signatures. Do not bypass verification, replace expected hashes, or use arbitrary mirrors to make setup pass.
- Require source/provenance, independent hashes/signatures, architecture and redistribution license for native components and separately downloaded executables/models. Do not load the unresolved `resources/libwcdb_api.dylib` cloud-report component with user data. Review all fallback library paths.
- No release is authorized until upstream/third-party licensing and native provenance are resolved. Do not assign a new license to code without rights. Do not assume a public GitHub fork grants all redistribution rights.
- The inherited updater/publish configuration points to upstream. Before any future International packaging, isolate identity/update/publish/signing/profile namespaces in a separate reviewed task; never run current `release:*` commands.

## i18n and upstream maintenance

- Follow [i18n architecture](docs/development/international-i18n.md): bundled locale catalogs `en-US`, `ru-RU`, `zh-CN`; shared formatting/presentation adapters; no remote catalog backend.
- Do not translate machine codes, IPC/API routes/fields, native ABI, storage identifiers, timestamps, raw chat content or WeChat parsing regex as part of UI localization. Prompt/agent-language behavior is a separate reviewed change.
- Keep downstream edits small and additive. Import upstream releases through separate reviewed sync PRs with exact SHA, security/network/license diff and regression evidence; do not rewrite published main/develop history.
- Required checks follow change scope and current authorization. During static-only, use static document/link/syntax checks, not project scripts. Later, run only reviewed relevant tests with synthetic inputs; macOS arm64 and Windows x64 builds require target-platform evidence. Never report skipped/unrun/zero-test checks as passing.

Report outcomes and unresolved limitations to the owner in Russian. Keep source/architecture terms precise; do not claim complete absence of telemetry or data leakage while opaque native components remain unreviewed.
