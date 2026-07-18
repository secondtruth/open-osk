# OpenOSK — Open On-Screen Keyboard

OpenOSK is an open-source on-screen keyboard and accessibility tool suite for macOS,
built for people with limited mobility — including developers. It combines ideas from
Hot Virtual Keyboard and the macOS Accessibility Keyboard with features that neither
offers, such as shell command completion for terminal work.

## Features

- **Floating on-screen keyboard** that never steals focus from the target application
  (non-activating panel, stays above full-screen apps)
- **Sticky modifiers**: tap ⇧/⌃/⌥/⌘ once to latch it for the next key, tap twice to
  lock it, a third tap releases it — full keyboard shortcuts (⌘C, ⌃⌥T, …) with single
  clicks
- **Dwell input**: optionally, hovering a key presses it after a configurable delay
  (with a progress indicator on the key) — for pointer-only users with head/eye
  trackers or joysticks who cannot click
- **Long-press character variants**: hold a/e/u/… to pick à á â ä € … from a popup
- **Typing aids**: current-text bar right on the keyboard (no need to watch a distant
  text field), auto-capitalization after sentence ends, double-space inserts a period
- **Programmable keys / macros**: layout keys can insert snippets, press shortcut
  sequences, or open apps/URLs (`"text"`, `"macro"` with `steps` in the layout JSON)
- **Word prediction** with bundled German and English word lists, capitalization
  carry-over, and **learning from your own typing** (persisted across sessions)
- **Terminal mode**: when a terminal app (Terminal, iTerm2, Warp, kitty, WezTerm,
  Ghostty, Alacritty, Hyper) is frontmost, the suggestion bar completes shell
  commands, subcommands, and flags (`git com…` → `commit`, `git commit --a…` →
  `--amend`) from a bundled, user-extensible database
- **Texter**: a companion compose window for UI elements that don't cooperate with
  on-screen keyboards (looking at you, VS Code terminal). Write or dictate text in a
  normal window, then inject it into the previously focused app — by synthetic typing
  or via clipboard paste (⌘V) with automatic clipboard restore
- **Layout-independent typing**: characters are injected as Unicode, so the keyboard
  works identically regardless of the system input source; shortcuts resolve real
  key codes from the active layout (QWERTZ ⌘Z is really ⌘Z)
- **JSON-defined layouts** (German QWERTZ and US QWERTY bundled); drop your own into
  `~/Library/Application Support/OpenOSK/Layouts/`
- **Adjustable**: key size, opacity, per-feature toggles; fades when idle; follows
  the system light/dark appearance
- Optionally **shows itself automatically** when a text field gains focus
  (Accessibility API observer)
- Runs as a menu bar app (no Dock icon); UI in English and German

## Requirements

- macOS 13 or later (Apple Silicon or Intel)
- Swift 6 toolchain (Xcode or Command Line Tools) to build
- **Accessibility access** (System Settings → Privacy & Security → Accessibility) —
  required to send keystrokes to other applications; OpenOSK prompts on first launch

## Building & running

```sh
make build     # debug build
make run       # build & launch
make test      # run unit tests (handles CLT-only machines automatically)
make bundle    # create build/OpenOSK.app for /Applications
```

Or directly with SwiftPM: `swift build`, `.build/debug/openosk`.

CLI flags: `--version`, `--help`, `--smoke-test` (start, verify initialization, exit).

> Tip: install the bundled app (`make bundle`, then copy `build/OpenOSK.app` to
> `/Applications`) so macOS remembers the Accessibility permission across rebuilds.

## Usage notes

- Drag the keyboard by its background (anywhere that isn't a key).
- The suggestion bar sits above the keys, next to the current-text display; click
  a suggestion to complete the current word or shell token.
- Long-press a letter for accents and symbol variants; enable dwell in the settings
  to press keys by hovering alone.
- Prediction only sees what you type *through OpenOSK* — text typed on a hardware
  keyboard or completed by the shell itself is invisible to it, and the tracked
  line resets when you switch apps or move the caret.
- **Texter**: menu bar icon → "Open Texter" while the target app is focused. The
  window title shows where the text will go.

## Customization

- **Layouts**: JSON files with rows of keys (`base`/`shift`/`alt`/`shiftAlt` for
  characters, `special` for named keys, `modifier` for ⇧⌃⌥⌘, `width` in key units).
  See `Sources/OpenOSKCore/Resources/Layouts/` for the format. User layouts in
  `~/Library/Application Support/OpenOSK/Layouts/` override bundled ones by `id`.
- **Shell completions**: add your own commands/subcommands/flags in
  `~/Library/Application Support/OpenOSK/shell-completions.json` (same schema as
  `Sources/OpenOSKCore/Resources/Shell/completions.json`); entries merge with and
  override the bundled database per command.
- **Word lists**: plain text, one word per line, ordered by frequency, in
  `Sources/OpenOSKCore/Resources/Wordlists/`.
- **Macro keys**: any layout key may carry `"text": "snippet"` or a full
  `"macro": { "steps": [ { "text": "…" }, { "shortcut": "cmd+s" },
  { "open": "https://…" }, { "delayMs": 200 } ] }`.

## Project layout

| Path | Contents |
| --- | --- |
| `Sources/OpenOSKCore` | UI-independent engine: layouts, event injection, prediction, shell completion, preferences |
| `Sources/OpenOSK` | AppKit app: keyboard panel, Texter, settings, menu bar |
| `Tests/OpenOSKCoreTests` | Unit tests (Swift Testing) |
| `scripts/bundle.sh` | Builds `build/OpenOSK.app` |

## License

MIT — see [LICENSE](LICENSE).
