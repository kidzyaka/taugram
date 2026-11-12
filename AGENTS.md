# AGENTS.md

This file provides guidance to coding agents working with code in this repository.


## Code Style

### Comments
- Do NOT add comments to code except for special markers like `//TODOLANG` (for strings that need localization) or similar task markers
- Code should be self-documenting through clear naming


## Useful Documents
Read the matching document before starting the task.

| Task | Document |
|---|---|
| Creating a new screen or controller | [docs/swift/TemplateController/README.md](docs/swift/TemplateController/README.md), template in [TemplateController.swift](docs/swift/TemplateController/TemplateController.swift) |
| HLS (adaptive) video playback | [packages/HLSPlayback/README.md](packages/HLSPlayback/README.md) |


## Architecture Overview

### Project Structure
- **Telegram-Mac/** - Thin app target: launch and hook installation (`app/`), the concrete `AccountContext` (`account/`), hook installers and bridges (`packages-integration/`), strings (`en.lproj/Localizable.strings`)
- **packages/** - Swift Package Manager modules; almost every feature and UI lives here
- **packages/TGUIKit/** - UI Library
- **TelegramShare/** - Share extension
- **submodules/** - Core libraries and telegram-ios shared code (TelegramCore, Postbox, SSignalKit)
- **core-xprojects/** - Native framework build projects (OpenH264, FFmpeg, WebRTC, etc.)
- **docs/** - Guides and code templates, not part of any target

### Main Modules
Only the modules you will touch most. Find anything else with `grep -rn "func NameController" packages`.

| Module | Use it for |
|---|---|
| `TGUIKit` | Views, `TableView`, `ViewController`, modals, `Window` |
| `TelegramContext` | `AccountContextProtocol`; packages take `any AccountContextProtocol` |
| `Localization` | `strings()`, generated from `Telegram-Mac/en.lproj/Localizable.strings` by `tools/swiftgen.sh` |
| `TelegramTheme` | The `theme` global, `TelegramPresentationTheme`, `deliverOnPrepareQueue` |
| `ColorPalette`, `TelegramIconsTheme` | Palette colors and `theme.icons` |
| `InAppSettings` | App preferences stored in Postbox, `FastSettings` |
| `TelegramUtils` | Telegram helpers shared by many features (formatting, peer status text, `bestWindow`) |
| `FoundationUtils`, `Strings`, `DateUtils`, `ObjcUtils` | Pure helpers with no Telegram UI |
| `TelegramMedia`, `TelegramMediaUtils`, `TelegramMediaResources` | Players, media fetching and saving, media resources |
| `LocalAnimations` | Bundled Lottie animations |
| `InputDataUI` | `InputDataController` list and form screens, `FeatureNavigationHooks` |
| `GeneralRows` | `GeneralRowItem` and the common table rows |
| `AlertsUI` | `alert`, `verifyAlert` |
| `AvatarUI`, `ShortPeerRow`, `SelectPeersUI`, `InputView`, `InlineStickerLayer` | Avatars, peer rows, peer pickers, text input, inline custom emoji |
| `ChatModeTypes`, `ChatHistoryModel`, `MessageUtils`, `MessageTextUtils` | Chat and message model shared by several screens |
| `ChatUI`, `ChatListUI`, `SettingsUI`, `PeerInfoUI` | The big screens: chat, chat list, settings, peer info |
| `PremiumUI`, `StarsUI`, `StoriesUI`, `CallsUI`, `GalleryUI`, `WalletUI`, ... | One `*UI` package per feature screen |

### Adding a Feature
- Add the screen to the package it belongs to; create a new package only for a standalone multi-file feature, copying `packages/GroupsInCommonUI/Package.swift`, then add it to the `Packages` group and link it to the `Telegram` target
- Build screens by following [docs/swift/TemplateController](docs/swift/TemplateController/README.md)
- App-only code (`AccountContext`, app singletons) is reached through a `<Name>Hooks` struct in the package, installed from `Telegram-Mac/packages-integration/hooks/` and `app/main.swift`
- Other features' screens are opened through `FeatureNavigationHooks`, never imported

### Dependencies
- Declare only modules whose symbols you actually use; never add dependencies "just in case"
- No screen package may depend on another screen package; existing ones are debt
- Keep feature code out of hubs (`TGUIKit`, `TelegramTheme`, `TelegramContext`, `Localization`, `TelegramUtils`, `InAppSettings`, `GeneralRows`, `InputDataUI`); a hub API change recompiles ~90 packages
- `*Share` products are for the share extension only

### Moving Code into Packages
- Packages enforce runtime exclusivity (the app has it off), so `inout` access conflicts can trap after a move
- `BETA`/`STABLE`/`ALPHA`/`APP_STORE` are false in packages in Xcode UI builds; only `buildbox/build-mac.sh` sets them
- App extensions like `Peer.isForum` and `Peer.displayLetters` shadow TelegramCore members; in a package call them through hooks


## Commit Checks
Run these before every commit.

### Xcode 27 changes
- `scripts/xcode27.sh revert` before staging, `scripts/xcode27.sh apply` after committing; its deployment-target, warning and shader edits never get committed

### Telegram-iOS patch staging
Taugram changes to `submodules/telegram-ios` (TelegramCore, Postbox and the rest of the shared core) are committed as `scripts/telegram-ios-taugram.patch`, on top of upstream's `scripts/telegram-ios-macos.patch`, never as submodule state.
- `sh scripts/taugram-core-patch.sh export` after changing the submodule; stage the patch together with the app code that needs it
- `sh scripts/taugram-core-patch.sh check` must pass: the patch matches the submodule, and the submodule pointer is an upstream commit
- Never commit inside `submodules/telegram-ios`; stage the submodule pointer only when moving it to a new upstream commit
- Moving it: `sh scripts/prepare-telegram-ios.sh --reverse`, check out the new commit, `sh scripts/taugram-core-patch.sh apply`, resolve conflicts, build, `export`
- New core files go to `submodules/telegram-ios/submodules/TelegramCore/Sources/Tau/`; mark each edit in an upstream core file with `// Taugram`


## Shipping a Beta
A beta build starts when `beta` is pushed to `origin`.
1. Commit all pending work on `beta`, including any submodule bumps (`submodules/telegram-ios` carries the Rust engine)
2. Merge the feature branches being shipped into `beta`, e.g. `git merge origin/sam/new-wallet`
3. Bump the build number: increment `CFBundleVersion` in `Telegram-Mac/Info.plist` and `TelegramShare/Info.plist`, commit as `Bump the build number to <N>`
4. `git push origin beta`
