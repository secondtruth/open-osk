# Contributing to OpenOSK

Thanks for your interest! OpenOSK is an accessibility project — an on-screen
keyboard and tool suite for people with limited mobility. Contributions of all
kinds are welcome: code, layouts, word lists, shell completions, translations,
bug reports, and real-world accessibility feedback (especially the latter —
this software is only as good as it is usable for its target audience).

## Building & testing

```sh
make build     # debug build
make run       # build & launch
make test      # unit tests (Swift Testing, not XCTest)
make bundle    # build/OpenOSK.app
```

Requirements: macOS 13+ and a Swift 6 toolchain. Plain SwiftPM works too
(`swift build` / `swift test`); no Xcode project is involved.

After UI changes, run the launch check:

```sh
.build/debug/openosk --smoke-test   # prints SMOKE_TEST_OK and exits 0
```

CI runs on every push: macOS (build + tests) and Linux (full package build +
tests). `OpenOSKCore` must keep building on Linux — Apple-only code goes behind
`#if canImport(...)`, portable shims live in `PlatformTypes.swift`.

## What goes where

- `Sources/OpenOSKCore` — the engine: layouts, prediction, completion,
  macros, preferences. **No AppKit here** — this is the testable, portable part.
- `Sources/OpenOSK` — the AppKit app: panel, Texter, editors, menu bar.
- `Sources/OpenOSKCore/Resources/` — bundled layouts, word lists, shell
  completions, panels. All plain JSON/text; great first contributions.
- `Tests/OpenOSKCoreTests` — Swift Testing suites; add tests for core changes.

See [AGENTS.md](AGENTS.md) for architecture details and invariants (e.g. why
the keyboard panel must never become the key window).

## Data contributions (no Swift required)

- **Layouts** (`Resources/Layouts/*.json`): new language layouts are very
  welcome — rows of keys with `base`/`shift`/`alt`/`shiftAlt`.
- **Word lists** (`Resources/Wordlists/<lang>.txt`): one word per line,
  ordered by frequency (most common first).
- **Shell completions** (`Resources/Shell/completions.json`): commands,
  subcommands, flags.
- **Panels** (`Resources/Panels/*.json`): task-oriented button collections.
- **Translations**: `Sources/OpenOSK/Resources/<lang>.lproj/Localizable.strings`
  — keep all languages in sync when adding UI strings.

## Conventions

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `ci:`, `perf:`, `style:`).
- Code comments and documentation are written in English.
- Match the surrounding code style; avoid trivial comments.
- UI strings go through `L("English key")` with entries in both `en` and `de`.

## Accessibility feedback

If you use OpenOSK with assistive hardware (switches, eye/head trackers) or
have motor impairments that make certain interactions hard, your experience
reports are the most valuable input this project can get. Open an issue and
describe your setup and what worked or didn't — no technical detail required.
