import Foundation
public import Kit

public func solDisplayString(from lamports: Lamports) -> String {
    let whole = lamports / 1_000_000_000
    let fractional = lamports % 1_000_000_000
    guard fractional > 0 else {
        return "\(whole)"
    }
    let paddedFraction = String(format: "%09llu", fractional)
    let trimmedFraction = paddedFraction.replacingOccurrences(
        of: "0+$",
        with: "",
        options: .regularExpression
    )
    return "\(whole).\(trimmedFraction)"
}
