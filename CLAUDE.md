# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.
`AGENTS.md` is the primary reference — read it for architecture, build/test
commands, and conventions. Key points, incorporated from there:

## Project

OpenOSK — open-source on-screen keyboard & accessibility suite for macOS.
Swift + AppKit via SwiftPM (no Xcode project). Menu bar accessory app.

## Commands

- `make build` / `make run` / `make test` / `make bundle` / `make clean`
- `.build/debug/openosk --smoke-test` — headless-ish launch check, prints
  `SMOKE_TEST_OK` and exits 0. Use after UI changes.
- Tests use **Swift Testing** (`import Testing`), not XCTest — XCTest is not
  available with Command Line Tools. `make test` adds the required search-path
  flags automatically.

## Structure

- `Sources/OpenOSKCore` — testable engine (layouts, CGEvent injection, word
  prediction, shell completion, preferences). No AppKit.
- `Sources/OpenOSK` — AppKit app (non-activating keyboard panel, Texter,
  settings, menu bar).
- `Tests/OpenOSKCoreTests` — unit tests.
- Bundled data: `Sources/OpenOSKCore/Resources/{Layouts,Wordlists,Shell}`.

## Invariants

- The keyboard panel must never take key/main status — that's what keeps focus
  (and injected keystrokes) in the target application.
- Two injection paths on purpose: Unicode events for plain text
  (layout-independent), virtual key codes for shortcuts/special keys.
- Keep `OpenOSKCore` free of AppKit so it stays testable.
- Update `TODO.md` when completing or discovering tasks.
