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

## Done (v0.4)

- [x] Themes: System, High Contrast, Dark, Light
- [x] Media/system keys (volume, brightness, playback) + bundled System panel
- [x] Two-switch scanning (advance key + select key)
- [x] Macro steps: toggle panel ("panel"), speak phrase ("say")
- [x] File path completion (absolute and ~ paths) in terminal mode
- [x] Frequently-used-command ranking (persisted usage counts)
- [x] Optional /usr/share/dict/words prediction fallback
- [x] Key click sound (optional); panel position persisted across launches
- [x] Settings shortcuts to app-profiles.json and the panels folder
- [x] GitHub Actions CI: macOS build+test, Linux build of OpenOSKCore
      (core is canImport-guarded; data model builds without CoreGraphics)

## Done (v0.5)

- [x] Profile editor UI (table: bundle id, layout, terminal mode; "add
      frontmost app")
- [x] Panel editor UI (buttons with row/label/symbol/action/value; custom
      JSON macros preserved on round-trip)
- [x] Panel buttons with SF Symbol images
- [x] VS Code & friends: integrated-terminal detection via focused AX element
- [x] Cross-platform core: whole package (app stubbed) builds and all tests
      run on Linux; CI runs swift test on both OSes
- [x] CONTRIBUTING.md

## Done (v0.6)

- [x] Scanning across open panels
- [x] Keys and suggestions exposed to VoiceOver / Voice Control (role, spoken
      name, press action)
- [x] Themed suggestion chips with dwell progress; variant popup follows the theme
- [x] System theme blurs the desktop behind the panel; key corner radii scale
      with key size; media keys use SF Symbols instead of emoji
- [x] High Contrast: readable current-text bar, solid latched-modifier color
- [x] Settings window with toolbar tabs, slider value labels, dependent
      controls disabled with their switch, confirmation before clearing
      learned words
- [x] Custom panels remember their position; rebuilding no longer resets it
- [x] Preference changes carry the changed key: no full keyboard rebuild per
      slider tick
- [x] Word prediction is deterministic for short prefixes (best-first search
      by rank); "Clear learned words" also clears the in-memory counts
- [x] `--snapshot DIR` renders themes and settings panes to PNGs

## v0.7 candidates

- [ ] Variant popup for dwell and scanning users (long-press needs a held
      mouse button today)
- [ ] Larger frequency-ordered word lists (de/en)
- [ ] Macro editor for multi-step macros (editor currently maps single-step
      actions; complex macros remain JSON)

## Later

- [ ] Layout editor UI (drag & drop) instead of hand-written JSON
- [ ] Code signing & notarization; Homebrew cask
- [ ] Cross-platform ports (Windows SendInput / Wayland virtual-keyboard) once
      there is a machine or maintainer to test on — the Linux CI job already
      keeps OpenOSKCore building off-macOS.

## Ideas (from the original concept note)

- Suite umbrella "Open Accessibility Tools": keyboard as the core component,
  Texter as the first companion tool
- Special text completion for physically impaired developers using the
  terminal (partially done: command/flag completion)
