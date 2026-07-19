#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
import Testing

@testable import OpenOSKCore

@Suite struct MacroTests {
    @Test func parsesSimpleShortcut() throws {
        let parsed = try #require(ShortcutParser.parse("cmd+s"))
        #expect(parsed.flags == .maskCommand)
        #expect(parsed.character == "s")
        #expect(parsed.special == nil)
    }

    @Test func parsesMultipleModifiers() throws {
        let parsed = try #require(ShortcutParser.parse("cmd+shift+alt+k"))
        #expect(parsed.flags.contains(.maskCommand))
        #expect(parsed.flags.contains(.maskShift))
        #expect(parsed.flags.contains(.maskAlternate))
        #expect(parsed.character == "k")
    }

    @Test func parsesSpecialKeys() throws {
        #expect(try #require(ShortcutParser.parse("cmd+return")).special == .return)
        #expect(try #require(ShortcutParser.parse("ctrl+tab")).special == .tab)
        #expect(try #require(ShortcutParser.parse("esc")).special == .escape)
        #expect(try #require(ShortcutParser.parse("cmd+backspace")).special == .delete)
    }

    @Test func parsesPlusAsKey() throws {
        let parsed = try #require(ShortcutParser.parse("cmd++"))
        #expect(parsed.flags == .maskCommand)
        #expect(parsed.character == "+")
    }

    @Test func rejectsMalformedShortcuts() {
        #expect(ShortcutParser.parse("") == nil)
        #expect(ShortcutParser.parse("foo+s") == nil)
        #expect(ShortcutParser.parse("cmd+xyz") == nil)
    }

    @Test func textKeyBecomesPlainTextMacro() throws {
        let key = Key(text: "Viele Grüße", label: "Gruß")
        guard case .macro(let macro)? = key.kind else {
            Issue.record("Expected macro kind")
            return
        }
        #expect(macro.isPlainText)
        #expect(macro.steps.first?.text == "Viele Grüße")
    }

    @Test func macroWithShortcutIsNotPlainText() {
        let macro = Macro(steps: [
            MacroStep(text: "hello"),
            MacroStep(shortcut: "cmd+s"),
        ])
        #expect(!macro.isPlainText)
    }

    @Test func macroKeyDecodesFromJSON() throws {
        let json = """
        {
          "label": "Sig",
          "macro": { "steps": [ { "text": "Cheers" }, { "shortcut": "cmd+return", "delayMs": 100 } ] }
        }
        """
        let key = try JSONDecoder().decode(Key.self, from: Data(json.utf8))
        guard case .macro(let macro)? = key.kind else {
            Issue.record("Expected macro kind")
            return
        }
        #expect(macro.steps.count == 2)
        #expect(macro.steps[1].shortcut == "cmd+return")
        #expect(macro.steps[1].delayMs == 100)
    }
}
