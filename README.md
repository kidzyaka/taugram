<div align="center">
  <img src="Telegram-Mac/Assets.xcassets/AppIcon.appiconset/Logo_1024.png"
      width="128"
      height="128"
      alt="Taugram icon">

  <h1 align="center">Taugram</h1>

  <p>An unofficial Telegram client for macOS with ghost mode, saved deleted messages, chat locks and deep theming.</p>
</div>

Taugram is a fork of [Telegram for macOS](https://github.com/macosswift/telegram) in the spirit of AyuGram and exteraGram. It does everything the official app does and adds its own settings screen: **Settings → Taugram**.

Taugram is not affiliated with Telegram.

## Features

### Everyday

These are always available.

| Feature | What it does |
|---|---|
| **OLED mode** | True black backgrounds with no blur. The theme stays locked until you turn the mode off, then your previous theme comes back. |
| **Color editor** | Change every color of the current theme and see the result across the whole app as you pick. Import and export `.palette` files. |
| **App icons** | Classic, Ocean, Midnight, Synthwave, Terminal and more, without Telegram Premium. |
| **Chat lock** | Hide chosen chats behind a passcode, with Touch ID per chat if you want it. Locked chats show no previews in the chat list or in notifications. |
| **ID and data center** | Profiles show the ID in Bot API format and the data center. Click the ID to copy it. |
| **Seconds in message time** | Message timestamps show seconds. |
| **Hide stories** | Removes stories from the chat list. |

Chat lock protects the interface, not the disk. The local database is encrypted only when the app passcode is on.

### Dangerous

These are hidden until you accept the risk. See [Risks](#risks).

| Feature | What it does |
|---|---|
| **Ghost mode** | Stops sending read receipts, online status and typing. Stories, voice messages and mentions aren't marked as seen, and channel views aren't counted. Each part has its own switch; ⌥⌘G toggles them all. |
| **Deleted messages** | Messages that others delete stay in the chat, marked as deleted with the time of deletion. |
| **Edit history** | Keeps up to 50 earlier versions of an edited message. Open them from the message menu. |
| **Protected content** | Copy and save from chats that restrict it. Forwarding a protected message sends a copy instead. |
| **Self-destructing media** | View self-destructing photos and videos on the Mac, and open them without telling the sender. Secret chats have a separate switch. |

### In progress

- An MCP server so that AI agents can read your chats and, with your approval, send messages. It is local and off by default.
- A mark for Taugram's creator and contributors.
- Signed builds with automatic updates.

The full plan is in [docs/taugram/ROADMAP.md](docs/taugram/ROADMAP.md) (in Russian).

## Risks

The dangerous features break the [Telegram API Terms of Service](https://core.telegram.org/api/terms). Telegram can restrict or ban an account that uses them. You use them at your own risk.

Taugram asks about this once, on first launch. **Enable** stays inactive for 10 seconds, and the dialog can't be dismissed without choosing. If you choose **Disable**, the dangerous features stay hidden.

You can change the decision later in **Settings → Taugram → Dangerous Features**. That switch also turns off every dangerous feature at once.

## Privacy

- Taugram has no servers of its own.
- Taugram adds no analytics or crash reporting. The AppCenter and Firebase keys of the official app are removed.
- Automatic updates are off until Taugram has its own update feed. To update, pull and rebuild.

## How to Build

Full details, requirements and troubleshooting are in [INSTALL.md](INSTALL.md).

1. Install Xcode 16 or newer, Homebrew and a Rust toolchain (rustup). On Xcode 27, read [XCODE27.md](XCODE27.md) first.
2. Clone with submodules:
   ```bash
   git clone --recurse-submodules https://github.com/kidzyaka/taugram.git
   ```
3. Get your own `api_id` and `api_hash` at [my.telegram.org/apps](https://my.telegram.org/apps). The repository ships none, and the app stops at launch without them. Copy the template and fill them in:
   ```bash
   cp Telegram-Mac/secrets.xcconfig.example Telegram-Mac/secrets.xcconfig
   ```
4. Prepare the machine and build the native libraries once:
   ```bash
   sh scripts/setup_build_env.sh --build
   ```
5. Open `Telegram-Mac.xcworkspace` in Xcode, select your own team for signing and build the `Telegram` scheme.

## How the Fork Is Organized

Taugram keeps its diff from upstream small, so that upstream updates merge cheaply.

- Taugram's own code lives in `packages/TauSettings` and `packages/TauSettingsUI`.
- Changes to TelegramCore and Postbox are kept as a patch, [scripts/telegram-ios-taugram.patch](scripts/telegram-ios-taugram.patch), on top of upstream's macOS patch. The `telegram-ios` submodule always points to an upstream commit.
- Every edit in an upstream core file is marked with `// Taugram`.

Conventions for working in this repository are in [AGENTS.md](AGENTS.md).

## Contributing

Report bugs and suggest features in [GitHub Issues](https://github.com/kidzyaka/taugram/issues). Please don't report Taugram bugs to Telegram.

Pull requests follow [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Taugram is licensed under the GNU General Public License, version 2.0. See [LICENSE](LICENSE).

It is built on [Telegram for macOS](https://github.com/macosswift/telegram) by the Telegram team.
