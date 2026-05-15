public import RpcTypes

public func getMinimumBalanceForRentExemption(space: UInt64) -> Lamports {
    let accountStorageOverhead: UInt64 = 128
    let defaultExemptionThreshold: UInt64 = 2
    let defaultLamportsPerByteYear: UInt64 = 3_480
    let (spaceWithOverhead, spaceOverflow) = space.addingReportingOverflow(accountStorageOverhead)
    if spaceOverflow {
        return UInt64.max
    }
    let (perYear, yearOverflow) = spaceWithOverhead.multipliedReportingOverflow(by: defaultLamportsPerByteYear)
    if yearOverflow {
        return UInt64.max
    }
    let (requiredLamports, thresholdOverflow) = perYear.multipliedReportingOverflow(by: defaultExemptionThreshold)
    if thresholdOverflow {
        return UInt64.max
    }
    return requiredLamports
}
