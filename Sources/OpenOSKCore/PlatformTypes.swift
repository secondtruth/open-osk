#if !canImport(CoreGraphics)
/// Minimal stand-ins for the CoreGraphics types used by the data model, so
/// OpenOSKCore builds on non-Apple platforms (exercised by the Linux CI job).
/// Event *posting* is Apple-only and lives behind canImport guards.
public typealias CGKeyCode = UInt16

public struct CGEventFlags: OptionSet, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static let maskShift = CGEventFlags(rawValue: 1 << 17)
    public static let maskControl = CGEventFlags(rawValue: 1 << 18)
    public static let maskAlternate = CGEventFlags(rawValue: 1 << 19)
    public static let maskCommand = CGEventFlags(rawValue: 1 << 20)
}
#endif
