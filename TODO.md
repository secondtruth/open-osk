# OpenOSK — TODO

## Done (v0.1.0 prototype)

- [x] Non-activating floating keyboard panel (no focus stealing, above full-screen)
- [x] QWERTZ (de) + QWERTY (US) layouts, JSON-defined, user-overridable
- [x] Unicode text injection + real key codes for shortcuts (active-layout aware)
- [x] Sticky modifiers: latch / lock / release cycle for ⇧⌃⌥⌘
- [x] Key autorepeat (backspace, arrows, space), hover highlight
- [x] Word prediction (de/en lists, capitalization carry-over) + learning with
      persistence, "clear learned words"
- [x] Terminal mode: shell command/subcommand/flag completion with bundled
      database + user extension file
- [x] Texter compose window (type or paste injection, clipboard restore,
      optional trailing Return)
- [x] Menu bar app, settings window (layout, key size, opacity, toggles)
- [x] Unit tests (Swift Testing), Makefile, app bundle script, docs

## Next up

- [ ] App icon; German localization of UI strings
- [ ] Auto-show/hide keyboard when a text field gains focus (AX observers)
- [ ] Dwell input: hover-to-press for users who cannot click
- [ ] Scanning input (switch access) as an alternative input mode
- [ ] Text macros / snippets (Hot Virtual Keyboard feature parity)
- [ ] Per-app profiles (layout + mode per application)
- [ ] Better prediction: bigram/next-word prediction, larger word lists,
      optional `/usr/share/dict/words` merge
- [ ] Shell completion: read $PATH for command discovery, file path completion,
      completion history from the Texter
- [ ] VS Code handling: detect integrated terminal focus (AX API) to enable
      terminal mode inside editors
- [ ] Layout editor UI (drag & drop keys) instead of hand-written JSON
- [ ] Multi-display awareness; remember panel position per display
- [ ] Optional key click sound / haptic-style visual feedback
- [ ] Code signing & notarization for distribution; Homebrew cask
- [ ] Word-by-word deletion key (⌥⌫), Fn/media row layout variant

## Ideas (from the original concept note)

- Suite umbrella "Open Accessibility Tools": keyboard as the core component,
  Texter as the first companion tool
- Special text completion for physically impaired developers using the
  terminal (partially done: command/flag completion)
