#if canImport(Carbon)
import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Resolves characters to virtual key codes using the *current* system
/// keyboard layout. Needed for shortcuts (e.g. ⌘C must carry the key code
/// that means "C" in the user's active layout, which differs between
/// QWERTY and QWERTZ).
public final class KeycodeResolver {
    public struct Resolution: Equatable {
        public let keyCode: CGKeyCode
        public let needsShift: Bool
    }

    private var map: [Character: Resolution] = [:]

    public init() {
        rebuild()
    }

    /// Rebuilds the map from the active keyboard layout. Call when the input
    /// source changes.
    public func rebuild() {
        map = [:]
        guard
            let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let layoutDataRef = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData)
        else {
            loadFallback()
            return
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataRef).takeUnretainedValue() as Data
        layoutData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let layoutPtr = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return
            }
            let keyboardType = UInt32(LMGetKbdType())
            // Modifier key state values are (EventModifiers >> 8) & 0xFF; shiftKey = 0x0200.
            let modifierStates: [(UInt32, Bool)] = [(0, false), (2, true)]
            for code: UInt16 in 0..<128 {
                for (modifierState, shifted) in modifierStates {
                    var deadKeyState: UInt32 = 0
                    var actualLength: Int = 0
                    var characters = [UniChar](repeating: 0, count: 4)
                    let status = UCKeyTranslate(
                        layoutPtr,
                        code,
                        UInt16(kUCKeyActionDown),
                        modifierState,
                        keyboardType,
                        UInt32(kUCKeyTranslateNoDeadKeysMask),
                        &deadKeyState,
                        characters.count,
                        &actualLength,
                        &characters
                    )
                    guard status == noErr, actualLength == 1,
                          let scalar = UnicodeScalar(characters[0])
                    else { continue }
                    let character = Character(scalar)
                    if map[character] == nil {
                        map[character] = Resolution(keyCode: CGKeyCode(code), needsShift: shifted)
                    }
                }
            }
        }
        if map.isEmpty {
            loadFallback()
        }
    }

    /// Key code for a character, matched case-insensitively for letters.
    public func resolve(_ character: Character) -> Resolution? {
        if let exact = map[character] { return exact }
        let lowered = Character(String(character).lowercased())
        return map[lowered]
    }

    /// US-ANSI positions as a last resort if the layout cannot be read.
    private func loadFallback() {
        let ansi: [Character: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32,
            "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        ]
        for (character, code) in ansi {
            map[character] = Resolution(keyCode: code, needsShift: false)
        }
    }
}
#endif
