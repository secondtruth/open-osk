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

## Done (v0.3)

- [x] Scanning input (switch access): row → key two-level scan, configurable
      interval and switch key (global event tap, ignores own injected events)
- [x] Custom panels (Panel Editor concept) with bundled Git and Editing panels;
      user panels dir; open state restored across launches
- [x] Per-app profiles (layout + forced terminal mode via app-profiles.json)
- [x] Bigram next-word prediction learned from typing (persisted)
- [x] $PATH command discovery for terminal completion (curated commands rank first)
- [x] Word/line deletion via Editing panel (⌥⌫ / ⌘⌫)

## v0.4 candidates

- [ ] Settings UI for per-app profiles and macro/panel editing (currently JSON)
- [ ] Panel buttons: images and spoken phrases (VoiceOver), panel-switch action
- [ ] Two-switch scanning (manual advance + select); group-level scan for panels
- [ ] Themes/skins beyond scale+opacity (key shape, colors, fonts)
- [ ] Larger frequency word lists; optional `/usr/share/dict/words` merge
- [ ] Shell completion: file path completion, frequently-used-command ranking
- [ ] VS Code: detect integrated-terminal focus via AX (profile workaround
      exists: terminalMode=true for com.microsoft.VSCode)
- [ ] System control keys (volume, brightness, media) — needs NX system events

## Later

- [ ] Layout editor UI (drag & drop) instead of hand-written JSON
- [ ] Multi-display awareness; remember panel position per display
- [ ] Optional key click sound feedback
- [ ] Code signing & notarization; Homebrew cask
- [ ] Cross-platform: first step is CI (GitHub Actions) building OpenOSKCore on
      Linux with the Apple-only files (#if canImport) excluded — cheap and keeps
      the core honest. Full ports (Windows SendInput / Wayland virtual-keyboard)
      only once there is a machine or maintainer to test on.

## Ideas (from the original concept note)

- Suite umbrella "Open Accessibility Tools": keyboard as the core component,
  Texter as the first companion tool
- Special text completion for physically impaired developers using the
  terminal (partially done: command/flag completion)
