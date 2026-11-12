# Taugram: план функционала

Taugram — неофициальный клиент Telegram для macOS на базе официального Telegram-Mac, в духе AyuGram и exteraGram.
Этот документ — полный план: архитектура форка, каталог функций с точками встраивания, порядок работ и открытые решения.

Ссылки на код сверены 2026-11-12 с `submodules/telegram-ios` на коммите `24638bc69bd` и с веткой `master` этого репозитория.
Номера строк со временем уедут: ищите по имени функции.

Сокращения путей:
- `TC/` = `submodules/telegram-ios/submodules/TelegramCore/Sources/`
- `PB/` = `submodules/telegram-ios/submodules/Postbox/Sources/`

---

## 1. Принципы

1. **Минимальный дифф с апстримом.** В чужих файлах — только однострочные проверки флагов и вызовы своих функций. Вся логика живёт в своих файлах (`TC/Tau/`, `packages/Tau*`). Каждая правка в чужом файле помечается `// Taugram`.
2. **Безопасные и опасные функции разделены** (раздел 1.1). Опасные недоступны, пока пользователь не подтвердит риск в окне первого запуска.
3. **Ни одной утечки при старте.** Флаги призрака читаются синхронно до первого сетевого запроса.
4. **Данные форка не теряются при обновлении апстрима**: свои атрибуты и коллекции регистрируются под стабильными именами, которые никогда не меняются.
5. Правила [AGENTS.md](../../AGENTS.md): без комментариев в коде, новые строки с `//TODOLANG`, экраны по [TemplateController](../swift/TemplateController/README.md).

### 1.1. Безопасные и опасные функции

| Класс | Что входит | Поведение |
|---|---|---|
| **Безопасные** | Интерфейс, цвета, OLED, иконка, пин-код на чат, ID/DC, переводчики, фильтры, больше аккаунтов, MCP, значок Taugram | Доступны всегда |
| **Опасные** | Призрак, сохранение удалённых и история правок, обход защиты от пересылки, игнорирование одноразовости | Скрыты за общим рубильником `dangerousFeaturesAllowed`; каждая функция включается отдельно |

В ядре каждая опасная проверка выглядит как `allowed && feature`. Поэтому выключение рубильника мгновенно отключает всё опасное разом и работает как аварийный выключатель.

### 1.2. Окно предупреждения при первом запуске

- Показывается один раз после входа в первый аккаунт, до открытия списка чатов. Повторно — из настроек Taugram («Опасные функции → Пересмотреть решение») и при росте версии согласия, когда в класс «опасные» добавляется новая функция.
- Текст: какие функции нарушают правила Telegram, что это может привести к ограничению или блокировке аккаунта и что пользоваться ими можно только на свой страх и риск.
- Кнопки:
  - **«Отключить»** — обычная кнопка, срабатывает по Enter. Рубильник выключен, опасный раздел настроек показывает только кнопку пересмотра.
  - **«Включить»** — красная (`theme.colors.redUI`). Первые 10 секунд неактивна, на ней обратный отсчёт: «Включить (10)», «Включить (9)»… Не реагирует на Enter, только на клик.
- Закрыть окно крестиком или Esc нельзя: только выбрать одну из кнопок.
- Сохраняется в `TauSettings`: `dangerousConsent = { version, decision, date }`.
- Реализация: модальный `InputDataController`-экран в `packages/TauSettingsUI` с кастомной строкой кнопок, таймер — `SwiftSignalKit.Timer` на 1 с.

## 2. Архитектура

### 2.1. Патчи ядра: свой patch-файл вместо форка Telegram-iOS

Апстрим не форкает Telegram-iOS. Его правки ядра лежат в [scripts/telegram-ios-macos.patch](../../scripts/telegram-ios-macos.patch), а `scripts/prepare-telegram-ios.sh` накладывает его при каждом `configure_frameworks.sh`. Taugram делает так же:

- `scripts/telegram-ios-taugram.patch` — все изменения TelegramCore/Postbox форка, накладываются **после** macOS-патча.
- `scripts/prepare-telegram-ios.sh` дополняется вторым `git apply` с той же проверкой идемпотентности (`apply --reverse --check`).
- `scripts/taugram-core-patch.sh export` выгружает текущие правки сабмодуля поверх macOS-патча в `telegram-ios-taugram.patch`; `apply` накладывает с `--3way` для разрешения конфликтов после обновления сабмодуля.
- Указатель сабмодуля никогда не коммитится с нашими правками: он всегда указывает на коммит апстрима.
- Нужно дописать в [AGENTS.md](../../AGENTS.md) раздел `#commit-checks`, на который уже ссылается [CLAUDE.md](../../CLAUDE.md): что коммитится патч, а не состояние сабмодуля.

Новые файлы ядра кладутся в `TC/Tau/`: таргет TelegramCore собирается из `path: "Sources"` без `exclude`, и SwiftPM подхватывает их сам. TelegramCore собирается с `-warnings-as-errors`, поэтому код форка обязан компилироваться без предупреждений.

### 2.2. Модули форка

| Модуль | Где | Что внутри |
|---|---|---|
| `TauCoreSettings` | `TC/Tau/TauCoreSettings.swift` | Потокобезопасные флаги для ядра (`static let shared` + `NSLock`). API с ключом аккаунта: `ghost(for: accountPeerId)` |
| `TauDeletedMessageAttribute` | `TC/Tau/` | `MessageAttribute`: время удаления. Регистрируется в `declaredEncodables` (`TC/Account/AccountManager.swift:88`) |
| `TauEditHistory` | `TC/Tau/` | Прежние версии сообщений в item cache |
| `packages/TauSettings` | новый пакет, не экран | Хранение настроек, синхронная загрузка при старте, проброс в `TauCoreSettings`, сигналы для UI |
| `packages/TauSettingsUI` | экранный пакет | Экран настроек, окно согласия, история правок, список удалённых |
| `packages/TauChatLock` | экранный пакет | Пин-код на чат: хранилище, экран блокировки, настройки |
| `packages/TauThemes` | экранный пакет | Редактор палитры, OLED-режим |
| `packages/TauMCP` | новый пакет | MCP-сервер: транспорт, JSON-RPC, инструменты |
| `packages/TauBadge` | новый пакет | Реестр пользователей Taugram и значок |
| `TauHooks` | `Telegram-Mac/packages-integration/hooks/TauHooksInstall.swift` | Доступ к `AccountContext` и app-синглтонам по образцу `LiteModeHooks` |

Пакеты UI (`ChatUI`, `ChatListUI`, `PeerInfoUI`) зависят только от `TauSettings`. Он не экранный и не хаб, правило «экран не зависит от экрана» не нарушается. Экраны других пакетов открываются через `FeatureNavigationHooks`.

**Тема в двух копиях:** `packages/TelegramTheme/Sources/TelegramThemeShare/*` — копия исходников `TelegramTheme` для share extension. Изменения палитры и темы нужно вносить в обе.

### 2.3. Хранение настроек

Настройки хранятся в `UserDefaults` по образцу `FastSettings` (`packages/InAppSettings/Sources/InAppSettings/FastSettings.swift:125`), как `SGSimpleSettings` в Swiftgram.

Почему не Postbox shared data, как `DockSettings`: она асинхронная. Первое значение приходит уже после того, как аккаунт начал синхронизацию, и при запуске клиент успевает отправить «онлайн» и «прочитано». Настройки читаются синхронно в `main.swift` до `NSApplicationMain` и сразу передаются в `TauCoreSettings`.

### 2.4. Хранение данных форка

| Данные | Где | Почему |
|---|---|---|
| Флаг «удалено» | `TauDeletedMessageAttribute` на самой записи сообщения (`transaction.updateMessage`) | Сообщение остаётся в истории Postbox и рисуется обычным путём, после перезапуска не пропадает |
| История правок | Item cache, коллекция `applicationSpecificItemCacheCollectionId(…)` (`TC/SyncCore/SyncCore_Namespaces.swift:742`) | Не раздувает строки сообщений и не теряется при `mergedServerMessageUpdate`. Своя таблица в Postbox невозможна: id таблиц зашиты в init Postbox |
| Сохранённые одноразовые медиа | Каталог `Taugram/Kept` в контейнере приложения, ключ — id сообщения | MediaBox чистит кэш по своим правилам, а сохранённое должно жить, пока его не удалят вручную |
| Пин-код чатов | Keychain по образцу `PasscodeCredentialStore` (`submodules/telegram-ios/submodules/PasscodeCore/Sources/Passcode.swift:247`): HMAC с секретом устройства → PBKDF2-SHA256 → AES-GCM | Готовая проверенная схема с лимитом попыток и биометрией |
| Список заблокированных чатов, регулярки, настройки MCP | `UserDefaults` (`TauSettings`) | Немного данных, нужны синхронно |
| Палитры пользователя | Файлы `.palette` в контейнере + `ThemePaletteSettings` | Совместимо с экспортом и импортом апстрима |

### 2.5. Ветки и обновления апстрима

- `master` — основная ветка Taugram. Функции разрабатываются в `taugram/<feature>`.
- Ремоут `upstream` → `macosswift/telegram`. Мерж апстрима раз в 1–2 недели отдельным PR, затем `taugram-core-patch.sh apply` с `--3way` и пересборка.
- Исправления, полезные апстриму (как `xcode27.sh`), — отдельными коммитами, чтобы их можно было отправить PR-ом.

---

## 3. Фаза 0 — фундамент

| # | Задача | Статус |
|---|---|---|
| 0.1 | Сборка чистого апстрима на Xcode 27 | ✅ |
| 0.2 | Исправление `xcode27.sh` для `mtproto-engine` | ✅ ветка `fix/xcode27-mtproto-engine` |
| 0.3 | Свой `api_id` из `secrets.xcconfig` | ✅ ветка `taugram/api-credentials` |
| 0.4 | Убрать `openssl@1.1` из `setup_build_env.sh`, описать снятие карантина с `scripts/flatc` | ✅ ветка `taugram/foundation` |
| 0.5 | Ребрендинг: имя, bundle id, team, app group | ✅ ветка `taugram/foundation` |
| 0.6 | Инфраструктура патчей ядра (2.1) | ✅ ветка `taugram/foundation` |
| 0.7 | Плавающая ошибка proc-macro в `wallet-engine` под Xcode | ✅ ветка `taugram/foundation`: Xcode передавал `MACOSX_DEPLOYMENT_TARGET=12.0` в хостовую сборку xtask, а `rust-objcopy` из Rust 1.96.1 при strip смещал строковую таблицу `__LINKEDIT`, и dyld macOS 27 не грузил proc-macro |

### 0.5. Ребрендинг — полный список

- **Bundle id и team:** 23 вхождения `ru.keepcoder.Telegram` в 11 файлах и `DEVELOPMENT_TEAM = 6N38VWS5BX` в `Telegram.xcodeproj/project.pbxproj`, entitlements (app groups, keychain), [Config.swift](../../packages/ApiCredentials/Sources/ApiCredentials/Config.swift) (`bundleId`, `teamId`).
- **Bundle seed:** `submodules/BuildConfig/Sources/BuildConfig.m:299,305` жёстко возвращает `6N38VWS5BX`. От него зависит ключ шифрования локальных данных (`getApplicationSecretKey`).
- **Имя:** `appName` в `packages/TelegramUtils/Sources/TelegramUtils/System.swift:17`, `MainMenu.xib`, `AlertsUI/.../Alerts.swift:18`, About (`AboutModalController.swift`), `Spotlight.swift:43`, `CrashRecovery.swift:60`, `PRODUCT_NAME`.
- **Иконка:** `AppIcon.icon` и `Assets.xcassets` без бумажного самолётика (подробнее в 5.7).
- **Обновления:** `SUFeedURL` в `Telegram-Mac/{Debug,Release,Beta}.xcconfig` и `configurations/*.xcconfig` указывает на `mac-updates.telegram.org`. До своего appcast — выключить Sparkle, иначе апдейтер поставит официальную сборку поверх форка.
- **Чужие ключи:** `Resources/config/GoogleService-Info.plist`, `APPCENTER_SECRET` в `configurations/{Beta,Stable}.xcconfig`, `webcredentials:telegram.org` в sandbox-entitlements.
- **URL-схемы** `tg://`, `telegram://`: решить, регистрировать ли их (конфликт с официальным клиентом, если стоят оба).
- **Сборочные скрипты:** `buildbox/*.sh` захардкодили `Telegram.app`.
- **Сделано (0.5):** бандл `Taugram.app` (`PRODUCT_NAME = Taugram`, а `PRODUCT_MODULE_NAME = Telegram` — xib и `Telegram.OpmizeDatabaseView` ссылаются на модуль по имени), заголовки главного меню подменяются в `MMMenuItem` (они приходят из языкового пакета), обновления выключены пустым `SFEED_URL` и флагом `appUpdatesEnabled` в `AppUpdateViewController.swift` — он гасит оба источника, Sparkle и канал Telegram. `GoogleService-Info.plist` и `APPCENTER_SECRET` удалены. Не тронуты: `DEVELOPMENT_TEAM` в `core-xprojects` (статические библиотеки не подписываются) и в сабмодуле Sparkle — для сборки из Xcode UI там нужно переопределение команды.
- **Песочница:** release-конфигурация подписывается `Telegram-Sandbox.entitlements` для всех каналов (`buildbox/build-mac.sh:62-66`). `network.server` в ней разрешён — это нужно MCP.

## 4. Фаза 1 — каркас

Статус: ✅ все шесть пунктов в ветке `taugram/foundation`, проверено на живом аккаунте: окно согласия (Esc и клик по фону не закрывают, «Включить» заблокирована 10 с), рубильник доходит до ядра, строка «Taugram» и поиск (в том числе по «ghost») открывают экран.

1. `TC/Tau/TauCoreSettings.swift` — флаги ядра, по умолчанию всё выключено, рубильник опасных функций.
2. `packages/TauSettings` — модель настроек, синхронная загрузка, установка в ядро. Вызов из `Telegram-Mac/app/main.swift` до `NSApplicationMain`, рядом с установкой hooks (`main.swift:16–103`).
3. `packages/TauSettingsUI` — экран «Taugram» на `InputDataController`. Разделы: Внешний вид, Чаты, Профиль, Конфиденциальность (пин-коды), Для агентов (MCP), Опасные функции, Отладка.
4. Окно согласия (1.2).
5. Строка в главных настройках: новый case в `AccountInfoEntry` (`packages/SettingsUI/Sources/SettingsUI/AccountViewController.swift:140`), свободный `stableId`, вставка перед `.general` (≈:654), подсветка в `navigationWillChangeController()` (:1224).
6. Поиск по настройкам: секция в `SettingsSearchableItems.swift` и namespace в `InAppSettings/.../SettingsSearchableItemId.swift`.

---

## 5. Каталог функций

Колонка ToS: **✗1.4** — прямо запрещено §1.4 [API Terms](https://core.telegram.org/api/terms); **✗Ayu** — AyuGram сам считает это нарушением developer ToS; **серое** — обход чужой защиты; **OK** — локально или косметически.
Оценка: **S** — до дня, **M** — несколько дней, **L** — неделя и больше.

### 5.1. Призрак ⚠️ опасное

| Функция | Точка в ядре | ToS | Оценка |
|---|---|---|---|
| Не отправлять «прочитано» | `pushPeerReadState` `TC/State/SynchronizePeerReadState.swift:254` → вернуть `.single(readState)`: операция подтверждается и не зацикливается | ✗1.4 | M |
| …обходы этой точки | `ReplyThreadHistory.swift:392,401` (saved, discussion); `ApplyMaxReadIndexInteractively.swift:222,226,258,262,300,304` (топики, «непрочитанное»); `MarkAllChatsAsRead.swift:28,38` | ✗1.4 | S |
| Не отмечать голосовые/кружки прослушанными, упоминания и реакции просмотренными | `ManagedSynchronizeConsumeMessageContentsOperations.swift:112`, `ManagedConsumePersonalMessagesActions.swift:254,323`, `ManagedSynchronizeMarkAllUnseenPersonalMessagesOperations.swift:119,286,382` | ✗1.4 | S |
| Не накручивать просмотры каналов | `AccountViewTracker.swift:739` `getMessagesViews(increment:)` → `.boolFalse` | ✗1.4 | S |
| Не отмечать live-location просмотренной | `AccountViewTracker.swift:966` | ✗1.4 | S |
| Не отмечать истории | `_internal_markStoryAsSeen` `TC/TelegramEngine/Messages/Stories.swift:2110` (и `incrementStoryViews` :2126) | ✗1.4 | S |
| Не быть онлайн | `updatePresence` `TC/State/ManagedAccountPresence.swift:45`. Сам `shouldKeepOnlinePresence` не трогать: он ещё управляет `receivedQueue` (`AccountStateManager.swift:431`) и keepalive | ✗1.4 | S |
| Уходить в офлайн автоматически | Тот же файл: после вынужденного онлайна (отправка сообщения) через N секунд слать `updateStatus(offline: true)` | ✗1.4 | S |
| Не отправлять «печатает» | `requestActivity` `TC/State/ManagedLocalInputActivities.swift:144` (`setTyping` :184, `setEncryptedTyping` :193) | ✗1.4 | S |
| «Прочитать при ответе» | `EnqueueMessage.swift:901–911` (готовый блок «read on send» для support-аккаунтов): разовое исключение из блокировки push | ✗1.4 | M |
| Быстрый переключатель | Меню в строке меню macOS, меню Dock, иконка в шапке списка чатов | OK | S |
| Предупреждение перед открытием истории | `StoriesUI/.../StoryModalController.swift` | OK | S |
| Призрак на аккаунт | Ключ `accountPeerId` в `TauCoreSettings` | — | M |
| Отправка отложенным сообщением (+12 с), чтобы не появляться в сети | `EnqueueMessage`, атрибут `OutgoingScheduleInfoMessageAttribute` | ✗1.4 | M |

**Сделано (первая версия):** запросы блокирует `network.tauGhost(\.flag).request(…)` (`TC/Tau/TauGhostNetwork.swift`) — в режиме призрака он сразу возвращает ошибку, а точки, где ошибка уже гасится, доделывают локальную часть как обычно. «Прочитано»: push не отправляется, а сверка `validatePeerReadState` при локальной отметке впереди сервера подтверждает операцию вместо бесконечного `.retry`. «Онлайн» уходит как `offline: true` каждые 30 с, это же возвращает в офлайн после отправки. Просмотры каналов запрашиваются с `increment: false`. Переключатель — пункт «Ghost Mode» (⌥⌘G) в меню приложения. Пока не сделано: призрак на аккаунт (флаги общие для всех аккаунтов), массовое «прочитать все реакции и голоса» (`readReactions`/`readPollVotes` при ошибке уходят в повтор), «прочитать при ответе», предупреждение перед открытием истории, отложенная отправка.

**Известные ловушки (из опыта AyuGram):**
- Отправка сообщения переводит в онлайн на сервере. Это не исправить, только «уходить в офлайн автоматически» или отложенная отправка.
- `validatePeerReadState` (`SynchronizePeerReadState.swift:185`) может вернуть локальное состояние «прочитано» обратно в «непрочитано» после сверки с сервером (у AyuGram issue #134/#372). Нужен локальный реестр «прочитано до id» и защита при валидации.
- Реакция или ответ на историю отмечают её просмотренной на сервере.
- Расшифровка голосовых (Premium) отмечает их прослушанными.

### 5.2. История сообщений ⚠️ опасное

| Функция | Точки | ToS | Оценка |
|---|---|---|---|
| Сохранять удалённые | `TC/State/Sync/StateReplay+Messages.swift`: `applyDeleteMessagesWithGlobalIds` :276, `applyDeleteMessages` :287, `.UpdateMinAvailableMessage` :294 → вместо удаления `updateMessage` с `TauDeletedMessageAttribute` и без `removeCachedResources` | ✗Ayu | L |
| …защита от вторичных удалений | `HistoryViewStateValidation.swift:995,1178` (`validateBatch`, `validateReplyThreadBatch`), `StoredMessageConfirmation.swift:213` (`deleteStoredMessagesAsReceivedDeletion`), `UpdateCachedPeerData.swift:973` (minAvailable). Без этого сохранённые сообщения исчезнут при прокрутке или после проверки истории | ✗Ayu | M |
| …перенос атрибута при правках | `mergedServerMessageUpdate` `TC/State/ServerMessageMerge.swift:9` пересобирает атрибуты из серверной копии; переносить наш, как `TranslationMessageAttribute` | — | S |
| История правок | `applyEditMessage` `StateReplay+Messages.swift:307`: до слияния сохранить прежний текст и entities в item cache | ✗Ayu | M |
| Метка «удалено», полупрозрачность | `ChatRowItem.swift:2761–2789` (рядом с «edited»), кадр в `ChatRightView.swift` `Frames` :228–460 | OK | M |
| «История изменений» в контекстном меню | `ChatMessageMenuItems.swift` `sevenBlock` :1600–1614 | OK | S |
| Список удалённых в чате, очистка | Новый экран в `TauSettingsUI`; пункт в меню чата | OK | M |
| Уведомление об удалении | `Telegram-Mac/account/SharedNotificationManager.swift:827` (`deliver()`), сигнал `AccountStateManager.deletedMessages` :280 | OK | S |
| Сохранять медиа удалённых | Не вызывать `removeCachedResources` для сохраняемых сообщений; автозагрузка не входит в объём | ✗Ayu | M |

**Сделано (первая версия):** удалённое помечается `TauDeletedMessageAttribute` (дата удаления) вместо удаления строки (`TC/Tau/TauMessageHistory.swift`). Перехват стоит в replay (`applyDeleteMessagesWithGlobalIds`, `applyDeleteMessages`, `applyUpdateMinAvailableMessage`), в `deleteStoredMessagesAsReceivedDeletion` (через него идут подтверждение при загрузке истории и «хвост» сброса `differenceTooLong`), в обеих ветках `HistoryViewStateValidation` (сохранённому ставится свежий `ChannelMessageStateVersionAttribute`, чтобы сверка не повторялась) и в minAvailable `UpdateCachedPeerData`. Служебные сообщения, секретные чаты и локальные id удаляются как обычно; кэш медиа у сохранённых не чистится. Метку `TauDeletedMessageAttribute` в `mergeMessageAttributes` не переносим нарочно: если сервер снова присылает сообщение (своё сообщение во время сброса), метка снимается сама. История правок — `TauEditHistoryMessageAttribute` (до 50 версий), пишется в `applyEditMessage` только при смене текста или entities и переносится через `mergeMessageAttributes`. В чате — метка «deleted» рядом с «edited» (красная, у исходящих в пузыре — серая) и дата удаления в подсказке времени; в меню — «Edit History» (окно с версиями) и «Deleted …». Переключатели — раздел MESSAGE HISTORY в настройках Taugram. Не сделано: правки, пропущенные офлайн (приходят загрузкой истории, а не `updateEditMessage`), полупрозрачность удалённых, список удалённых в чате и очистка, уведомление об удалении, скрытие действий «ответить/изменить» у удалённых.

**Как отличить чужое удаление от своего:** своё удаление сначала стирает строку локально (`DeleteMessagesInteractively.swift:165`), а ответ сервера приходит голым pts без id. Значит, если сообщение ещё лежит в базе на момент replay, его удалил кто-то другой. Удалять и потом вставлять обратно нельзя: Postbox блокирует повторную вставку через `recentlyDeletedMessages` (`PB/Postbox.swift:234`). Только `updateMessage`.

### 5.3. Защита контента и одноразовость ⚠️ опасное

#### Обход защиты от пересылки и копирования

Сервер отвергает пересылку защищённых сообщений (`CHAT_FORWARDS_RESTRICTED`, обработка в `PendingMessageManager.swift:1529–1605`). «Скрыть отправителя» тоже серверная пересылка (флаги в `PendingMessageManager.swift:1278–1307`), она не помогает. Поэтому обход состоит из двух частей:

| Часть | Как | Оценка |
|---|---|---|
| Локальная разблокировка | Отключить проверки защиты: `canForwardMessage` `packages/MessageUtils/Sources/MessageUtils/MessagePermissions.swift:68` (noforwards :104–121), `Message.isCopyProtected` `MessageExtras.swift:10`, `PeerExtras.swift:34`, галерея `MGalleryItem.swift:345` и гейты в `GalleryViewer.swift` (:417, :1026, :1150, :1448, :1492, :1650), меню `ChatMessageMenuItems.swift:418`, выделение текста `ChatSelectText.swift:298`, `PeerMediaRowContent.swift:83`. Одна функция `TauContentProtection.isBypassed(message)` вместо разбросанных правок | M |
| «Пересылка» как новая отправка | Для защищённых сообщений «Переслать» превращается в «Отправить копию»: текст и entities копируются, медиа скачивается (если нет в кэше) и загружается заново. Путь к файлу — `mediaBox.resourcePath` (`PB/MediaBox.swift:497`), обёртка `LocalFileReferenceMediaResource`, отправка через `Sender.enqueue(media:)` (`SenderController.swift:665,673`), как в `Sender.generateMedia` (:314–404). Альбомы отправляются группой. Подписи «переслано от» нет | L |

#### Игнорирование одноразовости

| Режим | Как | Оценка |
|---|---|---|
| Смотреть без отметки | Не вызывать consume при открытии: `SingleTimeMediaViewer.swift:493`, `GalleryViewer.swift:1003`, `AudioPlayerController.swift:1824` → `MarkMessageContentAsConsumedInteractively.swift:6`. Отправитель не узнает, что медиа открыли, таймер не стартует | S |
| Сохранять после истечения | В облачных чатах `ManagedAutoremoveMessageOperations.swift:88–114` только подменяет медиа на `TelegramMediaExpiredContent`, файл в MediaBox остаётся до чистки кэша. Перед подменой копировать файл в `Taugram/Kept` и хранить ссылку; в UI показывать сохранённую копию с меткой | M |
| Секретные чаты | Там удаление идёт через `_internal_deleteMessages` с `removeCachedResources(force: true)` (`DeleteMessages.swift:42–54`). Пропускать удаление по таймеру (`ManagedAutoremoveMessageOperations.swift:84–86`) и входящее удаление (`ProcessSecretChatIncomingDecryptedOperations.swift:283`) | M |
| Кнопка «Сохранить» для одноразового медиа | Пункт меню и кнопка в `SingleTimeMediaViewer` → «Сохранить как…» через `FileSaveActions.swift:14` | S |

Отдельные переключатели для каждого режима. Секретные чаты — отдельный, с дополнительным предупреждением: там приватность собеседника защищена сильнее всего.

**Сделано (первая версия):** раздел PROTECTED CONTENT в настройках Taugram. «Allow Copying and Saving» гасит три общие проверки — `Message.isCopyProtected()` в ядре, `Message.isCopyProtected(cachedData:)` (MessageUtils) и `Peer.isCopyProtected(cachedData:)` (TelegramUtils), плюс проверку в переводчике, — через них идут копирование, выделение, меню, галерея, перетаскивание и медиа профиля. Настоящую защиту возвращает `isCopyProtected(ignoringTaugram: true)`. «Переслать» для защищённых сообщений отправляет копию (`ChatHistoryModel/TauForwardCopy.swift`, вход из `Sender.forwardMessages`): текст с entities, фото и файлы скачиваются и загружаются заново через `LocalFileReferenceMediaResource`, альбомы сохраняют `groupingKey`, геопозиция и контакт уходят как есть; если среди выбранных нет защищённых — обычная пересылка. «Open Self-Destructing Media Unseen» пропускает `markMessageContentAsConsumedInteractively` для сообщений с `AutoclearTimeoutMessageAttribute` (и `AutoremoveTimeoutMessageAttribute` в секретных чатах, если включён отдельный красный переключатель): таймер не стартует, отправитель не получает отметку, медиа остаётся в чате. Не сделано: кнопка «Сохранить» в окне одноразового медиа, сохранение после истечения (`Taugram/Kept`), пропуск удаления по таймеру в секретных чатах, экспорт чата из защищённых, превью и миниатюры у копий видео, таймаут, если файл не скачивается.

### 5.4. Пин-код на чат ✅ безопасное

**Модель:** один общий пин-код для заблокированных чатов (по желанию — Touch ID) и список заблокированных `peerId`. Отдельный пин на каждый чат — опция второй очереди.

**Хранилище:** как у пин-кода приложения — `PasscodeCredentialStore` (`PasscodeCore/Sources/Passcode.swift:247`): KDF в `PasscodeCrypto.swift:30–50`, проверка :485, лимит попыток и задержка :476–504, биометрия `.biometryCurrentSet` :195. Собственный сервис Keychain, чтобы не смешивать с пин-кодом приложения.

**Экран блокировки:** переиспользовать `PasscodeLockView` (`packages/PasscodeUI/Sources/PasscodeUI/PasscodeLockController.swift:79`) и Touch ID через `LAContext` (:427).

**Где ставить замок.** В `navigateToChat` недостаточно: `ChatController` создаётся напрямую из уведомлений (`AppDelegate.swift:870–898`), ссылок (`InAppLinks.swift:595,1690,1870,2207`), отдельных окон (`SupportAccountContext.swift:99`), превью при наведении (`ChatListRowItem.swift:2720–2758`) и ~40 hook-установщиков. Поэтому:
1. **Главный замок — в самом `ChatController`** (`packages/ChatUI/Sources/ChatUI/ChatController.swift:2487`, `viewDidLoad` :3223): если чат заблокирован и не разблокирован в текущей сессии, поверх контента ставится экран ввода пин-кода, история не подписывается до разблокировки. Покрывает все пути и подклассы (`ChatAdditionController`, `ChatScheduleController`, `.preview`).
2. **Ранний замок в `navigateToChat`** (`Telegram-Mac/app/ApplicationContext.swift:29–124`, по образцу проверки чувствительного контента :90–121) — для аккуратного UX без мигания контента.
3. Режим `.preview` (наведение в списке чатов) для заблокированного чата не открывается вообще.

**Утечки, которые нужно закрыть:**

| Где | Точка |
|---|---|
| Превью в списке чатов, ответы, панель пересылки | Одна функция `chatListText` `packages/MessageTextUtils/Sources/MessageTextUtils/TextUtils.swift:274` → «🔒 Чат заблокирован» |
| Миниатюры медиа в списке чатов | `ChatListRowItem.swift:1026–1069`, превью топиков :949–950 |
| Уведомления | `SharedNotificationManager.swift:716` (условие скрытия превью) и :757–760: без текста и картинки |
| Глобальный поиск сообщений | `SearchController.swift:1171,1547`: исключить заблокированные чаты из результатов |
| Общие медиа, загрузки, хранилище | `PeerMediaController.swift:956`, `DownloadsController.swift:209–237`, `StorageUsageController.swift:1056` |
| Spotlight | `Telegram-Mac/utils/Spotlight.swift:37–46` индексирует только названия чатов; заблокированные — не индексировать |

**Когда запирать снова:** при уходе из чата, через N минут неактивности (как у пин-кода приложения, `SharedNotificationManager.swift:271–306`), при блокировке экрана (:341), при блокировке приложения.

**Ограничение, о котором честно говорим в UI:** это защита интерфейса. База Postbox на диске шифруется, только если включён пин-код всего приложения.

Оценка: L.

### 5.5. Подробная настройка цветов ✅ безопасное

**Что есть сейчас:** редактора палитры по ключам нет. Можно менять акцент и градиент исходящих пузырей (`CustomAccentColorModalController.swift:182–256`) и импортировать `.palette` (скрыто в `DeveloperViewController.swift:277–295`). Цвет входящих сообщений поменять нельзя.

**Что делаем:** редактор всех ключей `ColorPalette` (120 цветов, `packages/ColorPalette/Sources/ColorPalette/ColorPalette.swift:213`).
- **Группы:** Пузыри (входящие и исходящие: фон, рамка, подсветка, текст, ссылки, серый текст, иконки, выделение, код, вложения, волна голосового, ответы), Чат (фон, служебные сообщения, поле ввода), Список чатов, Боковая панель, Общее (акцент, текст, разделители, красный, зелёный).
- **Выбор цвета:** `NSColorPanel` с альфой, ввод hex, пипетка; для градиента исходящих — 1–4 точки.
- **Живой предпросмотр:** образец чата сверху экрана, как в `ThemePreviewModalController.swift:255`.
- **Сохранение:** как своя тема поверх выбранной базовой (`ThemePaletteSettings`, `ThemeSettings.swift:957`), экспорт и импорт `.palette` (`toString` :879, `importPalette` `ParseAppearanceColors.swift:343`), по желанию — облачная тема через `createTheme` (`TC/Themes.swift:287`).

**Что придётся поправить в апстримном коде палитры:**
- Автокоррекция контраста (`ColorPalette.swift:1056–1110`) и принудительная альфа ≥ 0.6 у пузырей (:1144–1214) перезаписывают цвета пользователя → флаг «уважать цвета пользователя» для своих палитр.
- `withAccentColor` (:1542) пересчитывает цвета пузырей → не применять поверх ручных правок.
- Экспорт теряет градиент исходящих: `toString` читает значения через Mirror как `NSColor`, а градиент — `[NSColor]`. Похоже на баг апстрима — проверить и отправить исправление.
- Новые ключи (если появятся) добавлять в `_computeColorSignature` (:232–360) и декодер `ColorPaletteNativeCodable` (`ThemeSettings.swift:600–765`).
- Все правки — в `TelegramTheme` и в его копии `TelegramThemeShare`.

Оценка: L.

### 5.6. OLED-режим ✅ безопасное

Отдельный режим, а не ещё одна тема: при включении он **запирает настройки тем и цветов** и ставит максимально чёткую тёмную схему для OLED и mini-LED.

**Палитра `oledPalette`** (новый case в `TelegramBuiltinTheme`, `ColorPalette.swift:1824`, рядом с `darkPalette` :2298):
- Фон окна, чата, списка чатов — `#000000`. Обои — нет.
- Поверхности (пузыри входящих, поле ввода, панели): 2–3 уровня близкого к чёрному, например `#0E0E10` / `#16161A` / `#1F1F24`. Без серых «туманных» фонов, которые на OLED светятся.
- Текст `#F2F2F2`, вторичный текст не темнее `#A0A0A8`: контраст ≥ 4.5:1 (WCAG AA) на чёрном.
- Исходящие пузыри — затемнённый акцент, текст на них ≥ 4.5:1.
- Разделители тонкие, `#26262B`. Подсветка выделения — без полупрозрачной заливки на весь ряд.

**Без прозрачности:** выключить `System.blurEnabled` и `System.liquidGlass` (`packages/TGUIKit/Sources/System.swift:100,117`), отдельно `forceBlur: true` в `MainViewController.swift:25,344`, затемнение модалок `.ultraDark` (`Modal.swift:1223`), `palette.vibrant` в панели эмодзи и стикеров. Синхронизация как у Lite Mode (`SharedAccountContext.swift:97–107`).

**Блокировка смены темы:**
- Главная точка: `updateThemeInteractivetly` (`ThemeSettings.swift:1258`) и `updateTheme(with:)` (`Appearance.swift:2201`) — в OLED-режиме принимают только OLED-палитру.
- UI-входы показывают «Отключите OLED-режим, чтобы менять тему»: `AppAppearanceViewController`, `AccountViewController.swift:428`, `SettingsSearchableItems.swift:516,530`, ссылки `InAppLinks.swift:1704,1942–1952`, виджет `WidgetAppearance.swift:249–359`, быстрый переключатель `MainViewController.swift:749`, `AutoNightViewController.swift:241,264`.
- Фоновые писатели игнорируются: автоночь и системная тема (`AppDelegate.swift:712–795`, :1283), облачные темы (`AccountContext.swift:810–826`), темы чатов (`ChatController.swift:2846,13293`, `ChatThemeSelectorController.swift:558`).
- При выключении OLED возвращается снимок прежних настроек темы.

Оценка: M.

**Сделано (первая версия):** палитра `Taugram OLED` собирается из `darkPalette` через экспорт и `importPalette` с заменой фонов (`TauOLED.swift`); прежняя тема сохраняется снимком через `AdaptedPostboxEncoder` и возвращается при выключении; запрет держит единственный хук `themeSettingsUpdateGuard` в `updateThemeInteractivetly`, через который идут и UI, и автоночь, и облачные темы; размытие и Liquid Glass выключаются в `syncLiquidGlassWithLite`. Не сделано: подсказка «Отключите OLED-режим» во входах смены темы (сейчас выбор темы молча не применяется), темы отдельных чатов, `TelegramThemeShare`.

### 5.7. Выбор иконки приложения ✅ безопасное

**Что есть:** смена иконки в Dock уже реализована: `Dock.swift:9` (`applicationIconImage` и `NSWorkspace.setIcon`), строка в `AppAppearanceViewController.swift:560–575`, выбор `selectAppIcon` :766 с проверкой Premium :768. Иконки грузятся с сервера Telegram (`DockControl.swift:47`), Premium определяется по имени файла (:33).

**Что делаем:**
- Набор своих иконок Taugram в бандле (Icon Composer, светлые, тёмные и tinted-варианты системы).
- Источник иконок — локальный набор вместо серверного, без Premium-проверки.
- Выбор — в разделе «Внешний вид» настроек Taugram и в существующей строке оформления.

**Проверить:** `NSWorkspace.setIcon` меняет бандл приложения (добавляет файл иконки). Проверить, не ломает ли это проверку подписи Gatekeeper и обновления Sparkle; после обновления иконку, скорее всего, придётся применять заново.

Оценка: S.

### 5.8. Значок «пользуется Taugram» ✅ безопасное, требует своего бэкенда

**Можно ли сделать:** да, но только через свой реестр. В Telegram нет поля профиля, куда клиент мог бы незаметно записать метку для других клиентов. AyuGram и exteraGram решают похожую задачу так же: AyuGram скачивает JSON со списками разработчиков и спонсоров (`update.ayugram.one/rc/...`), у exteraGram есть API `api.exteragram.app/api/v1/profiles/compact`. Отличие Taugram — самостоятельная регистрация каждого пользователя.

**Схема:**
1. **Регистрация с подтверждением личности через бота.** С согласия пользователя клиент отправляет `/start` боту `@TaugramBot`. Telegram сам передаёт боту настоящий `user_id` отправителя, подделать его нельзя — значит, никто не пометит чужой аккаунт. Чат с ботом клиент сразу архивирует и отключает в нём уведомления.
2. **Отказ:** выключение переключателя отправляет боту `/stop`, ID удаляется из реестра.
3. **Публикация:** реестр — статический файл, подписанный ключом Ed25519. Клиент скачивает его целиком раз в сутки и проверяет собеседников **локально**. Сервер не узнаёт, чьи профили смотрит пользователь.
4. **Без своего сервера:** бот опрашивается GitHub Actions по расписанию (`getUpdates` хранит апдейты 24 часа), реестр публикуется на GitHub Pages. Задержка до 15 минут, стоимость нулевая. Если пользователей станет много — перейти на маленький сервер.
5. **Значок:** рядом с именем там же, где значки Premium и верификации: `PremiumStatusControl.swift:479`, `ChatListRowView.swift:1883,1898`, шапка чата, профиль, имена авторов в группах.

**Приватность — что честно сказать в UI:**
- По умолчанию передача **выключена** и предлагается в окне первого запуска отдельно от опасных функций.
- Реестр по сути публичный: любой, кто скачает файл, увидит ID пользователей Taugram. Хэширование не спасает — пространство `user_id` перебирается за минуты. Пользователь соглашается на публичность.
- Отправка сообщения боту — действие от имени пользователя, поэтому только после явного включения.

Оценка: L (клиент M + бот и публикация M).

### 5.9. MCP-доступ для агентов ✅ безопасное по ToS, но с собственной защитой

MCP-сервер внутри клиента, чтобы агенты (Claude Code, Cursor и другие) могли читать чаты и, с разрешения, отправлять сообщения.

**Своя реализация, без официального Swift SDK:** он тянет `swift-nio`, `swift-log`, `swift-system`, `eventsource` из сети (а сборка проекта офлайн), требует macOS 13 и для нового кода использует Apache-2.0, несовместимую с GPLv2. Серверной части MCP нужно немного: JSON-RPC 2.0, `initialize`, `tools/list`, `tools/call`, уведомления. Пакет `packages/TauMCP`, несколько сотен строк.

**Транспорт:**
- Основной — **Streamable HTTP на `127.0.0.1`** через `NWListener` (Network.framework). Release-сборка в песочнице, но `network.server` разрешён. Только loopback, проверка заголовков `Host` и `Origin` (защита от DNS rebinding по спецификации MCP), токен `Authorization: Bearer` генерируется клиентом.
- Дополнительно, позже — **stdio-мост** `taugram-mcp` в бандле для MCP-клиентов без HTTP: пересылает stdio в HTTP-эндпоинт.
- В настройках — кнопка «Скопировать конфиг» с готовым JSON для Claude Code и других клиентов.

**Инструменты:**

| Инструмент | Что делает | По умолчанию |
|---|---|---|
| `list_accounts` | Аккаунты клиента (`SharedAccountContext.activeAccounts`, `SharedAccountContext.swift:126`) | вкл |
| `list_chats` | Чаты с фильтрами: папка, непрочитанные, лимит (`engine.messages.chatList`, `TelegramEngineMessages.swift:592`) | вкл |
| `get_chat` | Информация о чате или пользователе | вкл |
| `read_history` | Сообщения чата, пагинация по id (`aroundMessageHistoryViewForLocation`, `AccountViewTracker.swift:2286`) | вкл |
| `search_messages` | Поиск по всем чатам или в одном (`searchMessages`, `TelegramEngineMessages.swift:210`) | вкл |
| `get_unread_summary` | Сводка непрочитанного | вкл |
| `send_message` | Отправка текста с ответом на сообщение (`enqueueMessages`, `EnqueueMessage.swift:761`; пример без UI — `UNUserNotifications.swift:97`) | **выкл** |
| `mark_read` | Отметить прочитанным с учётом режима призрака | **выкл** |
| `download_media` | Скачать медиа и вернуть путь или содержимое небольшого файла | выкл |

Для аккаунтов кроме основного — `TelegramEngine(account:)` (`TelegramEngine.swift:8`): `AccountContext` есть только у основного.

**Чтение через MCP никогда не отправляет «прочитано»:** история читается из Postbox, а «прочитано» уходит только из UI-вызовов (`applyMaxReadIndex` и др.).

**Защита (агенты уязвимы к prompt injection через входящие сообщения):**
- MCP выключен по умолчанию; включение — с объяснением рисков.
- Белый список чатов, доступных агенту; заблокированные пин-кодом чаты недоступны всегда.
- Отправка: подтверждение каждого сообщения в окне Taugram или «доверенные чаты» без подтверждения.
- Лимит частоты отправки, защита от флуда (иначе бан за спам).
- Журнал всех вызовов в настройках, кнопка «Отозвать токен».

Оценка: L.

### 5.10. Интерфейс ✅ безопасное

| Функция | Точка | Оценка |
|---|---|---|
| ID собеседника | Уже есть: `FastSettings.canViewPeerId` (`FastSettings.swift:407`), строки в `UserInfoEntries.swift:3106`, `GroupInfoEntries.swift:2347`, `ChannelInfoEntries.swift:1398`. Вынести в настройки Taugram, добавить копирование в формате Bot API | S |
| DC собеседника | Новая строка рядом с ID; источник — `datacenterId` у ресурса аватара | S |
| Секунды во времени | `chatDateFormatter` `packages/TelegramUtils/Sources/TelegramUtils/DateSelectorUtil.swift:32` (`.short` → `.medium`) | S |
| Скрыть истории в списке чатов | `PeerListState.hasStories` `ChatListUI/.../PeersListController.swift:322` | S |
| Скрыть Premium/Stars/подарки | Строки настроек `AccountViewController.swift:691–716`, кнопка подарка `ChatPresentationInterfaceState.swift:459`, бейджи `PremiumStatusControl.swift:479` | M |
| Радиус пузырей | Захардкожен в `TelegramTheme/.../ChatMessageBubbleImages.swift:13–14`; поле в `ThemeSettings.swift:957` | M |
| Выбор переводчика | Шов уже есть: `AppConfigTranslateState` (`.alternative` = Google, `Translate.swift:321`). Выбор провайдера и перевод чата без Premium | M |
| Больше 3 аккаунтов | `AccountsLimit.swift:3`, `AccountUtils.swift:8`, проверки в `AccountViewController.swift:593,1067`, `QuickSwitcherModalController.swift:436,603` (лимит только клиентский) | S |
| Фильтры сообщений по регуляркам | Фильтровать вход **до** цикла в `ChatHistoryEntry.messageEntries` (`ChatHistoryEntry.swift:656`), в `ChatController.swift:4360`: внутри цикла сломается группировка соседей | M |
| Скрыть заблокированных в группах | Там же; список из `BlockedPeersContext` (`AccountContext.swift:206`) | S |
| Настройка контекстного меню | `chatMenuItems` `ChatMessageMenuItems.swift:395` | M |
| Подтверждение отправки стикера/GIF/голосового | `ChatController`, отправка медиа | S |
| JSON сообщения (отладка) | Пункт меню в разделе «Отладка» | S |
| Ускорение загрузок | Размер частей и параллелизм в `TC/Network/FetchV2.swift`, `MultipartUpload.swift` (как у Swiftgram) | M |

### 5.11. Не делаем

| Функция | Почему |
|---|---|
| Удаление спонсорских сообщений | §3.3 API Terms; в 2021 Telegram грозил отключить API клиентам без рекламы. Со своим `api_id` это самый быстрый путь к отзыву ключа |
| «Локальный Premium» | Меняет только `isPremium` в `AccountContext.swift:901`, сервер лимиты держит. Пользы мало, путаницы много |
| Подглядывание «был в сети» через исключения приватности | ✗1.4 и действие от имени пользователя, о котором он не знает |

---

## 6. Порядок работ

| Этап | Содержание | Итог |
|---|---|---|
| 0 | Ребрендинг, инфраструктура патча ядра | Сборка «Taugram» рядом с официальным клиентом |
| 1 | Каркас: настройки, рубильник, окно согласия | Экран «Taugram», флаги доходят до ядра |
| 2 | Быстрые безопасные: иконка, ID/DC, секунды, скрыть истории, OLED | Первая сборка, которой приятно пользоваться. ✅ иконка, ID/DC, секунды, истории, OLED (первая версия, см. 5.6) |
| 3 | Призрак | Полный режим призрака с быстрым переключателем. ✅ первая версия, см. 5.1; проверено со второго устройства 2026-11-12 |
| 4 | Удалённые и правки | Сохранение, отображение, история правок, список удалённых. ✅ первая версия, см. 5.2 |
| 5 | Защита контента и одноразовость | Копирование, «пересылка» копией, просмотр без отметки, сохранение. ✅ первая версия, см. 5.3 |
| 6 | Пин-код на чат | Замок во всех путях открытия, закрытые утечки |
| 7 | Редактор цветов | Все 120 ключей, предпросмотр, экспорт |
| 8 | MCP | HTTP-сервер, инструменты, защита, журнал |
| 9 | Значок Taugram | Бот, реестр, значок |
| 10 | Остальной интерфейс (5.10) | По приоритету |
| 11 | Распространение | Подпись, нотаризация, Sparkle на GitHub Pages, Releases, CI |

Этапы 6–9 не зависят друг от друга и от 3–5 и могут идти параллельно.

## 7. Проверка

- **Два тестовых аккаунта**, не основной: A — в Taugram, B — в официальном клиенте.
- **Призрак:** для каждой функции — «A делает действие, B не видит статуса»: прочитано, печатает, онлайн, просмотр истории, прослушивание голосового, просмотры в канале. Утечка при старте: запуск с включённым призраком, B не видит A в сети.
- **Удалённые:** B удаляет у всех → у A сообщение остаётся с меткой; перезапуск A → метка на месте; прокрутка далеко вверх и обратно → не исчезло. A удаляет своё → удаляется по-настоящему.
- **Одноразовость:** B отправляет view-once → A смотрит в режиме «без отметки» → у B нет «просмотрено»; после истечения у A есть сохранённая копия.
- **Защита:** канал с запретом пересылки → копирование текста, сохранение медиа и «пересылка» копией работают, у получателя нет «переслано от».
- **Пин-код:** чат заблокирован → не открывается ни одним путём из 5.4 (список, поиск, уведомление, ссылка, новое окно, наведение); превью, уведомления, поиск и медиа не раскрывают содержимое.
- **OLED:** все экраны без серых фонов и размытия; смена темы недоступна ни из одного входа; после выключения — прежняя тема.
- **MCP:** запрос без токена и с чужим `Origin` отклоняется; чтение не меняет статус «прочитано» у B; отправка без подтверждения невозможна.
- **Окно согласия:** «Включить» недоступна 10 секунд; Esc и крестик не закрывают; «Отключить» прячет опасные функции.
- **Регрессии:** при выключенных функциях всё работает как в апстриме.
- Юнит-тесты для `TauCoreSettings`, решения «удалить или пометить», KDF пин-кода и JSON-RPC слоя MCP.

## 8. Открытые решения

| # | Вопрос | Варианты |
|---|---|---|
| D1 | Опасные функции и свой `api_id` | Публичный релиз с опасными функциями грозит отзывом ключа по §4. Варианты: (а) выпускать для узкого круга; (б) публичная сборка с опасными функциями, принимая риск; (в) официальные ключи, как AyuGram, — нарушение §2.1 |
| D2 | Название, bundle id, иконка | ✅ `Taugram`, `com.kidzyaka.taugram`, временная иконка τ |
| D3 | Подпись | ✅ пока Personal Team `AF4N4AKWPQ`; Developer ID нет — раздача другим и нотаризация отложены до этапа 11 |
| D4 | Регистрировать ли `tg://` | ✅ да, схемы остаются в `Info.plist` |
| D5 | Медиа удалённых сообщений | Только то, что уже было в кэше, или заранее скачивать всё |
| D6 | TerraGram (iOS) | Если это родственный проект, патч ядра можно делить между двумя клиентами |
| D7 | Уведомление о скриншоте в секретных чатах | Отправлять ли собеседнику уведомление о скриншоте (`sendScreenshotNotification`, `PendingMessageManager.swift:2116`), когда включено игнорирование одноразовости |
| D8 | Значок Taugram: хостинг | GitHub Actions + Pages (бесплатно, задержка до 15 мин) или свой сервер |
| D9 | Пин-код | Один общий на все заблокированные чаты или отдельный на каждый |
