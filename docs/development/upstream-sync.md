# Синхронизация International-форка с upstream

Репозиторий разработки: **randomspb/TraceMemoENRU**. Источник для сравнения: **Wxw-Gu/TraceMemo**. Никаких PR, push или публикаций в upstream.

## Ветки и происхождение

На старте в форке был только `main`. По явному выбору владельца создана `develop` от `c366dd11871d75d5f511e843605b689731759622`; аудит подготовлен в `docs/international-security-architecture` с base `develop`. `main` остаётся release/stable веткой; PR разработки направлять в `develop` форка, как требует унаследованный CONTRIBUTING. Default branch в GitHub пока `main`; этот PR не меняет настройки default branch и branch protection.

Предлагаемая схема дальнейшей работы:

```text
upstream/main или release tag   → upstream-import/<tag> (неизменённый upstream SHA)
                                      ↓ reviewed merge PR
                                 sync/upstream-<tag>
                                      ↓ CI + security diff review
origin/develop  ← feature/security/i18n PRs
      ↓ отдельный release review, разрешения и подписи
origin/main
```

`upstream-import/<tag>` хранит upstream history/commit без squash/rewrite; это ветка/remote-tracking reference **в форке**, не ветка для push в оригинал. Каждое обновление оформлять отдельным PR с исходным tag и full SHA. Проверять tag signature, если она опубликована, и происхождение релиза; отсутствие подписи честно отмечать. Не выполнять code/lifecycle scripts только из-за того, что tag свежий.

Не rebase/force-push опубликованные `main`/`develop`. Для sync предпочтительнее merge upstream SHA в отдельную `sync/…` ветку: это сохраняет ancestry, позволяет видеть fork delta и аккуратно применять новые upstream fixes. Rebase допустим только для личной ещё не опубликованной feature-ветки по согласованной политике, не для переписывания пользовательской истории.

Не создавать worktree автоматически: облачная задача уже изолирована, использовать существующий checkout, если пользователь не просит иное. Не переключать рабочую ветку поверх неизвестных изменений. Upstream remote при добавлении использовать read-only по рабочему процессу; команды push/gh всегда с явным `randomspb/TraceMemoENRU`.

## Минимизация конфликтов

| Изменение International | Предпочтительный seam |
| --- | --- |
| i18n | Bundled catalogs/hooks и маленькие shared adapters; ключи semantic, не переписывать parser/DTO |
| Security | Общие sender/URL/AI policy guards в main, тесты negative cases; не дублировать services |
| Identity/update feed | Централизованный fork config/packaging overrides; явные tests, чтобы upstream merge не вернул provider оригинала |
| Build/CI | Fork workflow/конфигурация с раздельными sign/publish permissions; test pipeline без release secrets |
| Native/runtime provenance | Artifact manifest + digest/signature/license records, без локальных непроверенных binary замен |

Конфигурационные seams пока предложены, не реализованы. Не копировать целиком main/index.ts, report service или большие React screens ради изменения одного слова. Не делать mass formatting upstream файлов: оно затрудняет security diff. Сохранить понятный список downstream commits с причиной, областью и тестом; не поддерживать вручную расходящуюся папку копий исходников.

## Обязательная проверка каждого upstream import

1. Read-only diff от последнего импортированного SHA: manifests/lockfile/lifecycles, network destinations, IPC/API, key stores, native binaries, CI permissions, update/publish config, licenses.
2. Новые бинарники и изменённые hashes отправлять на review, не запускать. Новые domains классифицировать по data/trigger; не расширять egress автоматически.
3. Сопоставить security fixes форка и upstream: оставить исправление, перенести на новый seam или удалить только после доказанного покрытия; конфликт не разрешать слепым `ours/theirs`.
4. После разрешения на runtime-проверки: frozen install reviewed packages, types/tests, synthetic E2E на Windows x64 и macOS arm64, offline boundaries, i18n key coverage. До этого — только static checks.
5. PR должен содержать full upstream SHA/tag, список значимых изменений и unresolved security/license blockers. Лишь после review merge в `develop`; release отдельной процедурой.

Рекомендуемые будущие regression guards: запрет `Wxw-Gu/TraceMemo` как active publish/update target International (документационные ссылки разрешены), разрешённые native hashes, API loopback/auth, AI consent recipient binding, отсутствие secrets/network-enabled translations в bundle. Эти guards не добавлены в CI этого документационного PR.

Версия fork может использовать согласованный prerelease suffix `-intl.<n>` до отдельной схемы версионирования. Updater сравнивает semver/channel: совместимость Windows/mac metadata, downgrade и cross-install должна быть проверена, не выводиться из названия suffix. Не перезаписывать upstream tags и не выпускать International от имени оригинального автора.
