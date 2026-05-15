public func pipe<TInitial>(_ initial: TInitial) -> TInitial {
    initial
}

public func pipe<TInitial, R1>(
    _ initial: TInitial,
    _ initialToR1: (TInitial) throws -> R1
) rethrows -> R1 {
    try initialToR1(initial)
}

public func pipe<TInitial, R1, R2>(
    _ initial: TInitial,
    _ initialToR1: (TInitial) throws -> R1,
    _ r1ToR2: (R1) throws -> R2
) rethrows -> R2 {
    try r1ToR2(initialToR1(initial))
}

public func pipe<TInitial, R1, R2, R3>(
    _ initial: TInitial,
    _ initialToR1: (TInitial) throws -> R1,
    _ r1ToR2: (R1) throws -> R2,
    _ r2ToR3: (R2) throws -> R3
) rethrows -> R3 {
    try r2ToR3(r1ToR2(initialToR1(initial)))
}

public func pipe<TInitial, R1, R2, R3, R4>(
    _ initial: TInitial,
    _ initialToR1: (TInitial) throws -> R1,
    _ r1ToR2: (R1) throws -> R2,
    _ r2ToR3: (R2) throws -> R3,
    _ r3ToR4: (R3) throws -> R4
) rethrows -> R4 {
    try r3ToR4(r2ToR3(r1ToR2(initialToR1(initial))))
}

public func pipe<TInitial, R1, R2, R3, R4, R5>(
    _ initial: TInitial,
    _ initialToR1: (TInitial) throws -> R1,
    _ r1ToR2: (R1) throws -> R2,
    _ r2ToR3: (R2) throws -> R3,
    _ r3ToR4: (R3) throws -> R4,
    _ r4ToR5: (R4) throws -> R5
) rethrows -> R5 {
    try r4ToR5(r3ToR4(r2ToR3(r1ToR2(initialToR1(initial)))))
}

public func pipe<TInitial, R1, R2, R3, R4, R5, R6>(
    _ initial: TInitial,
    _ initialToR1: (TInitial) throws -> R1,
    _ r1ToR2: (R1) throws -> R2,
    _ r2ToR3: (R2) throws -> R3,
    _ r3ToR4: (R3) throws -> R4,
    _ r4ToR5: (R4) throws -> R5,
    _ r5ToR6: (R5) throws -> R6
) rethrows -> R6 {
    try r5ToR6(r4ToR5(r3ToR4(r2ToR3(r1ToR2(initialToR1(initial))))))
}

public func pipe<TInitial, R1, R2, R3, R4, R5, R6, R7>(
    _ initial: TInitial,
    _ initialToR1: (TInitial) throws -> R1,
    _ r1ToR2: (R1) throws -> R2,
    _ r2ToR3: (R2) throws -> R3,
    _ r3ToR4: (R3) throws -> R4,
    _ r4ToR5: (R4) throws -> R5,
    _ r5ToR6: (R5) throws -> R6,
    _ r6ToR7: (R6) throws -> R7
) rethrows -> R7 {
    try r6ToR7(r5ToR6(r4ToR5(r3ToR4(r2ToR3(r1ToR2(initialToR1(initial)))))))
}

public func pipe<TInitial, R1, R2, R3, R4, R5, R6, R7, R8>(
    _ initial: TInitial,
    _ initialToR1: (TInitial) throws -> R1,
    _ r1ToR2: (R1) throws -> R2,
    _ r2ToR3: (R2) throws -> R3,
    _ r3ToR4: (R3) throws -> R4,
    _ r4ToR5: (R4) throws -> R5,
    _ r5ToR6: (R5) throws -> R6,
    _ r6ToR7: (R6) throws -> R7,
    _ r7ToR8: (R7) throws -> R8
) rethrows -> R8 {
    try r7ToR8(r6ToR7(r5ToR6(r4ToR5(r3ToR4(r2ToR3(r1ToR2(initialToR1(initial))))))))
}

public func pipe<TInitial, R1, R2, R3, R4, R5, R6, R7, R8, R9>(
    _ initial: TInitial,
    _ initialToR1: (TInitial) throws -> R1,
    _ r1ToR2: (R1) throws -> R2,
    _ r2ToR3: (R2) throws -> R3,
    _ r3ToR4: (R3) throws -> R4,
    _ r4ToR5: (R4) throws -> R5,
    _ r5ToR6: (R5) throws -> R6,
    _ r6ToR7: (R6) throws -> R7,
    _ r7ToR8: (R7) throws -> R8,
    _ r8ToR9: (R8) throws -> R9
) rethrows -> R9 {
    try r8ToR9(r7ToR8(r6ToR7(r5ToR6(r4ToR5(r3ToR4(r2ToR3(r1ToR2(initialToR1(initial)))))))))
}

public func pipe<TInitial, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10>(
    _ initial: TInitial,
    _ initialToR1: (TInitial) throws -> R1,
    _ r1ToR2: (R1) throws -> R2,
    _ r2ToR3: (R2) throws -> R3,
    _ r3ToR4: (R3) throws -> R4,
    _ r4ToR5: (R4) throws -> R5,
    _ r5ToR6: (R5) throws -> R6,
    _ r6ToR7: (R6) throws -> R7,
    _ r7ToR8: (R7) throws -> R8,
    _ r8ToR9: (R8) throws -> R9,
    _ r9ToR10: (R9) throws -> R10
) rethrows -> R10 {
    try r9ToR10(r8ToR9(r7ToR8(r6ToR7(r5ToR6(r4ToR5(r3ToR4(r2ToR3(r1ToR2(initialToR1(initial))))))))))
}
