import Foundation
public import Kit

public struct ActivitySignatureSummary: Sendable, Identifiable, Equatable, Hashable {
    public let signature: String
    public let slot: Slot
    public let confirmationStatus: String?
    public let blockTime: UInt64?
    public let memo: String?
    public let isSuccessful: Bool

    public init(
        signature: String,
        slot: Slot,
        confirmationStatus: String?,
        blockTime: UInt64?,
        memo: String?,
        isSuccessful: Bool
    ) {
        self.signature = signature
        self.slot = slot
        self.confirmationStatus = confirmationStatus
        self.blockTime = blockTime
        self.memo = memo
        self.isSuccessful = isSuccessful
    }

    public var id: String {
        signature
    }

    public var shortSignature: String {
        guard signature.count > 16 else {
            return signature
        }
        return "\(signature.prefix(8))...\(signature.suffix(8))"
    }

    public var statusText: String {
        if !isSuccessful {
            return "Failed"
        }
        return confirmationStatus?.capitalized ?? "Ok"
    }

    public var blockTimeText: String? {
        guard let blockTime else {
            return nil
        }
        let date = Date(timeIntervalSince1970: TimeInterval(blockTime))
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
