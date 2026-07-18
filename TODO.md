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

## Done (v0.2)

- [x] Current-text toolbar on the keyboard
- [x] Auto-capitalization after sentence end; double-space inserts a period
- [x] Fade keyboard after inactivity (configurable toggle)
- [x] Dwell input with progress indicator (keys and suggestion buttons)
- [x] Long-press accent/symbol variant popup
- [x] Programmable keys: text snippets and macros (text/shortcut/open/delay steps)
- [x] Auto-show/hide keyboard on text-field focus (AX observer, opt-in)
- [x] App icon (generated), German localization of the UI

## v0.3 — accessibility depth & developer features

- [ ] **Scanning input (switch access)**: sequentially highlight key groups →
      rows → keys; one or two external switches (or any key/click) select.
      For users who cannot use a pointer at all.
- [ ] **Custom panels** (Panel Editor concept): user-defined button collections
      per task/app — e.g. a git panel, a VS Code panel; buttons carry actions
      (text, shortcut, macro, panel switch), optional image, spoken phrase
- [ ] **Per-app profiles**: layout + panel + mode switching per frontmost app
- [ ] **Themes/skins** beyond scale+opacity (key shape, colors, fonts)
- [ ] Better prediction: bigram/next-word prediction, larger frequency lists,
      optional `/usr/share/dict/words` merge
- [ ] Shell completion: discover commands from `$PATH`, file path completion,
      remember frequently used commands
- [ ] VS Code handling: detect integrated-terminal focus via AX API to enable
      terminal mode inside editors
- [ ] Word-by-word deletion key (⌥⌫); system control keys (volume, brightness,
      media) as optional layout row

## Later

- [ ] Layout editor UI (drag & drop) instead of hand-written JSON
- [ ] Multi-display awareness; remember panel position per display
- [ ] Optional key click sound feedback
- [ ] Code signing & notarization; Homebrew cask
- [ ] Cross-platform strategy: keep data formats (layouts, wordlists,
      completions) portable; extract core logic into a portable library with
      native shells per OS (see discussion in project notes)

## Ideas (from the original concept note)

- Suite umbrella "Open Accessibility Tools": keyboard as the core component,
  Texter as the first companion tool
- Special text completion for physically impaired developers using the
  terminal (partially done: command/flag completion)
