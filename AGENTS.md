# OpenOSK - Information for Coding Agents

OpenOSK is a macOS on-screen keyboard and accessibility suite written in Swift
(AppKit, SwiftPM — no Xcode project). It runs as a menu bar accessory app.

## Build & test commands

```sh
make build     # swift build (debug)
make run       # build + launch the app
make test      # swift test, with extra flags on CLT-only machines (see below)
make bundle    # release build + assemble build/OpenOSK.app via scripts/bundle.sh
make clean
```

- `.build/debug/openosk --smoke-test` starts the UI, prints `SMOKE_TEST_OK`, and
  exits 0 — use this to verify the app still launches without interacting with it.
- On machines with only Command Line Tools (no Xcode), XCTest is unavailable and
  Swift Testing lives outside default search paths. Tests use Swift Testing
  (`import Testing`), and the Makefile injects `-F/-rpath` flags pointing at
  `/Library/Developer/CommandLineTools/Library/Developer/{Frameworks,usr/lib}`.
  Do not convert tests to XCTest.

## Architecture

Two targets plus tests:

- **`OpenOSKCore`** (library, no AppKit): everything testable.
  - `KeyModel.swift` — `Key`, `KeyboardLayout`, `Modifier`, `SpecialKey`
    (virtual key codes as `kVK_*` raw values)
  - `LayoutStore.swift` — loads bundled + user layouts
    (`~/Library/Application Support/OpenOSK/Layouts`, user overrides by `id`)
  - `KeyInjector.swift` — CGEvent posting; text as Unicode events
    (layout-independent), shortcuts/specials as virtual key codes
  - `KeycodeResolver.swift` — char → key code for the *active* input source via
    `UCKeyTranslate` (Carbon); rebuilt on input-source change
  - `CompositionTracker.swift` — model of the current line/word as typed through
    OpenOSK (hardware keystrokes are invisible by design)
  - `WordPredictor.swift` — trie, frequency rank from list order + learned counts;
    `LearnedWordsStore.swift` persists learning to Application Support
  - `ShellCompleter.swift` — command/subcommand/flag completion from
    `Resources/Shell/completions.json`, mergeable with a user file
  - `TypingAids.swift` — auto-capitalization + double-space-period predicates
  - `CharacterVariants.swift` — long-press variant table (à á â …)
  - `Macro.swift` — programmable key model (`text`/`shortcut`/`open`/`delayMs`
    steps) and `ShortcutParser` ("cmd+shift+s" → flags + key)
  - `Preferences.swift` — UserDefaults-backed; posts
    `Preferences.didChangeNotification` on every set
- **`OpenOSK`** (executable, AppKit):
  - `KeyboardPanel.swift` — borderless `.nonactivatingPanel`, `canBecomeKey = false`,
    assistive-tech window level; this is what keeps focus in the target app
  - `KeyboardView.swift` — manual frame layout (no Auto Layout in the panel);
    `KeyView` handles press visuals, autorepeat, dwell (hover-to-press with
    progress pie) and long-press detection; `SuggestionBarView` with dwell
    buttons; current-text bar at the top. Character/macro keys fire on mouse-up
    (enables long-press), specials/modifiers on mouse-down (enables autorepeat).
  - `KeyboardController.swift` — central coordinator: modifier latching
    (off → latched → locked), terminal-mode detection via frontmost app bundle ID,
    suggestion routing (words vs. shell), learning, typing aids, inactivity fade,
    macro execution, auto-show wiring
  - `VariantPopup.swift` — non-activating popup with alternate characters,
    dismissed via local+global mouse monitors
  - `FocusWatcher.swift` — AXObserver on the frontmost app's focused UI element;
    drives "show keyboard when editing text"
  - `TexterController.swift` — compose window; injects into the previously
    frontmost app by typing or pasteboard+⌘V (with clipboard restore)
  - `SettingsController.swift`, `StatusBarController.swift`, `AppDelegate.swift`,
    `main.swift` (CLI flags: `--version`, `--help`, `--smoke-test`)
  - `L10n.swift` + `Resources/{en,de}.lproj/Localizable.strings` — UI strings via
    `L("English key")`; keep both languages in sync when adding strings

## Conventions & gotchas

- Resources are accessed via `Bundle.module` under the `Resources/` subdirectory
  (the package uses `.copy("Resources")`, so subpaths are preserved). The app
  bundle script copies `OpenOSK_OpenOSKCore.bundle` into `Contents/Resources/`.
- Character keys with ⌘/⌃ latched are posted as key codes (via `KeycodeResolver`);
  plain characters are typed as Unicode. Don't "simplify" this into one path —
  both are needed.
- The keyboard panel must never become key or main; all key handling happens in
  `mouseDown` on non-activating views. Anything that needs real focus (Texter,
  Settings) is a separate activating window.
- Sending events requires Accessibility trust (`AXIsProcessTrustedWithOptions`).
  The smoke test deliberately skips the prompt.
- UI strings are English for now (localization is on the TODO list); code and
  docs are always English.
