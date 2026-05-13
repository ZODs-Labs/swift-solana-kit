public import Foundation
internal import CryptoKit
#if canImport(Darwin)
internal import Darwin
#endif
package import SolanaErrors

public func compressedEdwardsYIsOnCurve(_ bytes: Data) -> Bool {
    guard bytes.count == 32 else {
        return false
    }
    var yBytes = bytes
    let lastByte = yBytes[31]
    yBytes[31] &= 0x7F
    let y = FieldElement(littleEndianBytes: yBytes)
    return Edwards25519.pointIsOnCurve(y: y, lastByte: lastByte)
}

public func isCompressedEdwardsYOnCurve(_ bytes: Data) -> Bool {
    compressedEdwardsYIsOnCurve(bytes)
}

package func ed25519PublicKey(seed: Data) throws(KeysError) -> Data {
    guard seed.count == 32 else {
        throw KeysError.invalidPrivateKeyByteLength(actualLength: seed.count)
    }
    return EdwardsPoint.basepoint.multiplied(by: Ed25519Scalar.clampedScalarBytes(seed: seed)).compressed()
}

// This path exists to preserve byte-for-byte parity with the deterministic RFC 8032
// signatures produced by kit/WebCrypto. It handles long-term secret scalars in Swift.
// Do not treat it as a constant-time replacement for the platform signer. Apple's
// CryptoKit signer is hardened by the platform and randomizes Ed25519 output, so
// consumers that prefer that posture over deterministic oracle bytes should select
// CryptoKitBackend(signingMode: .platform).
package func ed25519DeterministicSignature(
    message: Data,
    privateKeySeed seed: Data,
    publicKey: Data
) throws(KeysError) -> Data {
    guard seed.count == 32 else {
        throw KeysError.invalidPrivateKeyByteLength(actualLength: seed.count)
    }
    guard publicKey.count == 32 else {
        throw KeysError.publicKeyMustMatchPrivateKey
    }

    var expanded = Data(SHA512.hash(data: seed))
    var prefix = Data(expanded.suffix(32))
    defer {
        wipeSensitiveBytes(&prefix)
        wipeSensitiveBytes(&expanded)
    }
    let scalar = Ed25519Scalar.clampedScalarLimbs(seed: seed)

    let r = Ed25519Scalar.reduceHash(prefix + message)
    let encodedR = EdwardsPoint.basepoint.multiplied(by: Ed25519Scalar.bytes(from: r)).compressed()
    let k = Ed25519Scalar.reduceHash(encodedR + publicKey + message)
    let s = Ed25519Scalar.addMul(r, k, scalar)
    return encodedR + Ed25519Scalar.bytes(from: s)
}

package func ed25519Signature(message: Data, privateKeySeed seed: Data) throws(KeysError) -> Data {
    try ed25519DeterministicSignature(
        message: message,
        privateKeySeed: seed,
        publicKey: ed25519PublicKey(seed: seed)
    )
}

func wipeSensitiveBytes(_ data: inout Data) {
    data.withUnsafeMutableBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else {
            return
        }
        #if canImport(Darwin)
        _ = memset_s(baseAddress, rawBuffer.count, 0, rawBuffer.count)
        #else
        memset(baseAddress, 0, rawBuffer.count)
        #endif
    }
}

struct EdwardsPoint {
    static let identity = EdwardsPoint(x: .zero, y: .one, z: .one, t: .zero)
    static let basepoint: EdwardsPoint = {
        let x = FieldElement(littleEndianBytes: Data([
            0x1A, 0xD5, 0x25, 0x8F, 0x60, 0x2D, 0x56, 0xC9,
            0xB2, 0xA7, 0x25, 0x95, 0x60, 0xC7, 0x2C, 0x69,
            0x5C, 0xDC, 0xD6, 0xFD, 0x31, 0xE2, 0xA4, 0xC0,
            0xFE, 0x53, 0x6E, 0xCD, 0xD3, 0x36, 0x69, 0x21,
        ]))
        let y = FieldElement(littleEndianBytes: Data([
            0x58, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
            0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
            0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
            0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
        ]))
        return EdwardsPoint(x: x, y: y, z: .one, t: x * y)
    }()

    let x: FieldElement
    let y: FieldElement
    let z: FieldElement
    let t: FieldElement

    func added(_ other: EdwardsPoint) -> EdwardsPoint {
        let a = (y - x) * (other.y - other.x)
        let b = (y + x) * (other.y + other.x)
        let c = t * (FieldElement.d + FieldElement.d) * other.t
        let d = z * (FieldElement.one + FieldElement.one) * other.z
        let e = b - a
        let f = d - c
        let g = d + c
        let h = b + a
        return EdwardsPoint(x: e * f, y: g * h, z: f * g, t: e * h)
    }

    func doubled() -> EdwardsPoint {
        let a = x.squared()
        let b = y.squared()
        let c = z.squared() * (FieldElement.one + FieldElement.one)
        let d = -a
        let e = (x + y).squared() - a - b
        let g = d + b
        let f = g - c
        let h = d - b
        return EdwardsPoint(x: e * f, y: g * h, z: f * g, t: e * h)
    }

    func multiplied(by scalarBytes: Data) -> EdwardsPoint {
        var result = EdwardsPoint.identity
        var addend = self
        for byte in scalarBytes {
            for bit in 0 ..< 8 {
                let candidate = result.added(addend)
                let mask = UInt32(0) &- UInt32((byte >> UInt8(bit)) & 1)
                result = result.selected(candidate, mask: mask)
                addend = addend.doubled()
            }
        }
        return result
    }

    func compressed() -> Data {
        let zInverse = z.inverted()
        let affineX = x * zInverse
        let affineY = y * zInverse
        var bytes = affineY.littleEndianBytes(count: 32)
        if affineX.isOdd {
            bytes[31] |= 0x80
        }
        return bytes
    }

    func selected(_ other: EdwardsPoint, mask: UInt32) -> EdwardsPoint {
        EdwardsPoint(
            x: x.selected(other.x, mask: mask),
            y: y.selected(other.y, mask: mask),
            z: z.selected(other.z, mask: mask),
            t: t.selected(other.t, mask: mask)
        )
    }
}

enum Ed25519Scalar {
    static let order: [UInt32] = [
        0x5CF5_D3ED, 0x5812_631A, 0xA2F7_9CD6, 0x14DE_F9DE,
        0x0000_0000, 0x0000_0000, 0x0000_0000, 0x1000_0000,
    ]

    static func clampedScalarBytes(seed: Data) -> Data {
        var bytes = Data(Data(SHA512.hash(data: seed)).prefix(32))
        bytes[0] &= 248
        bytes[31] &= 63
        bytes[31] |= 64
        return bytes
    }

    static func clampedScalarLimbs(seed: Data) -> [UInt32] {
        limbs(from: clampedScalarBytes(seed: seed))
    }

    static func reduce(_ bytes: Data) -> [UInt32] {
        mod(limbs(from: bytes), by: order)
    }

    static func reduceHash(_ bytes: Data) -> [UInt32] {
        reduce(Data(SHA512.hash(data: bytes)))
    }

    static func addMul(_ r: [UInt32], _ k: [UInt32], _ a: [UInt32]) -> [UInt32] {
        let product = BigUInt.multiplyFull(k, a)
        let sum = BigUInt.add(r, product)
        return mod(sum, by: order)
    }

    static func bytes(from limbs: [UInt32]) -> Data {
        littleEndianBytes(from: limbs, count: 32)
    }

    static func limbs(from bytes: Data) -> [UInt32] {
        var limbs: [UInt32] = []
        limbs.reserveCapacity((bytes.count + 3) / 4)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            var limb: UInt32 = 0
            for byteOffset in 0 ..< 4 where index + byteOffset < bytes.count {
                limb |= UInt32(bytes[index + byteOffset]) << UInt32(byteOffset * 8)
            }
            limbs.append(limb)
        }
        return BigUInt.trim(limbs)
    }

    static func mod(_ limbs: [UInt32], by modulus: [UInt32]) -> [UInt32] {
        let totalBits = BigUInt.bitLength(limbs)
        guard totalBits > 0 else {
            return []
        }
        var remainder: [UInt32] = []
        for bitIndex in stride(from: totalBits - 1, through: 0, by: -1) {
            remainder = BigUInt.multiplySmall(remainder, by: 2)
            if bitIsSet(limbs, bitIndex) {
                remainder = BigUInt.add(remainder, [1])
            }
            if BigUInt.compare(remainder, modulus) >= 0 {
                remainder = BigUInt.subtract(remainder, modulus)
            }
        }
        return remainder
    }

    static func bitIsSet(_ limbs: [UInt32], _ bitIndex: Int) -> Bool {
        let limbIndex = bitIndex / 32
        guard limbIndex < limbs.count else {
            return false
        }
        return (limbs[limbIndex] & (UInt32(1) << UInt32(bitIndex % 32))) != 0
    }

    static func littleEndianBytes(from limbs: [UInt32], count: Int) -> Data {
        var bytes = Data(repeating: 0, count: count)
        for index in 0 ..< count {
            let limbIndex = index / 4
            if limbIndex < limbs.count {
                bytes[index] = UInt8((limbs[limbIndex] >> UInt32((index % 4) * 8)) & 0xFF)
            }
        }
        return bytes
    }
}

enum Edwards25519 {
    static func pointIsOnCurve(y: FieldElement, lastByte: UInt8) -> Bool {
        let y2 = y.squared()
        let u = y2 - .one
        let v = FieldElement.d * y2 + .one
        guard let x = uvRatio(u: u, v: v) else {
            return false
        }
        let signBitIsSet = (lastByte & 0x80) != 0
        if x.isZero && signBitIsSet {
            return false
        }
        return true
    }

    static func uvRatio(u: FieldElement, v: FieldElement) -> FieldElement? {
        let v3 = v * v * v
        let v7 = v3 * v3 * v
        let pow = pow2To252Minus3(u * v7)
        var x = u * v3 * pow
        let vx2 = v * x * x
        let root1 = x
        let root2 = x * .sqrtMinusOne
        let useRoot1 = vx2 == u
        let useRoot2 = vx2 == -u
        let noRoot = vx2 == ((-u) * .sqrtMinusOne)
        if useRoot1 {
            x = root1
        }
        if useRoot2 || noRoot {
            x = root2
        }
        if x.isOdd {
            x = -x
        }
        if !useRoot1, !useRoot2 {
            return nil
        }
        return x
    }

    static func pow2To252Minus3(_ x: FieldElement) -> FieldElement {
        let x2 = x.squared()
        let b2 = x2 * x
        let b4 = pow2(b2, count: 2) * b2
        let b5 = pow2(b4, count: 1) * x
        let b10 = pow2(b5, count: 5) * b5
        let b20 = pow2(b10, count: 10) * b10
        let b40 = pow2(b20, count: 20) * b20
        let b80 = pow2(b40, count: 40) * b40
        let b160 = pow2(b80, count: 80) * b80
        let b240 = pow2(b160, count: 80) * b80
        let b250 = pow2(b240, count: 10) * b10
        return pow2(b250, count: 2) * x
    }

    static func pow2(_ x: FieldElement, count: Int) -> FieldElement {
        var result = x
        for _ in 0 ..< count {
            result = result.squared()
        }
        return result
    }
}

struct FieldElement: Equatable {
    static let zero = FieldElement(reducedLimbs: [])
    static let one = FieldElement(reducedLimbs: [1])
    static let d = FieldElement(reducedLimbs: [
        0x1359_78A3, 0x75EB_4DCA, 0x4141_D8AB, 0x0070_0A4D,
        0x7779_E898, 0x8CC7_4079, 0x2B6F_FE73, 0x5203_6CEE,
    ])
    static let sqrtMinusOne = FieldElement(reducedLimbs: [
        0x4A0E_A0B0, 0xC4EE_1B27, 0xAD2F_E478, 0x2F43_1806,
        0x3DFB_D7A7, 0x2B4D_0099, 0x4FC1_DF0B, 0x2B83_2480,
    ])

    static let modulus: [UInt32] = [
        0xFFFF_FFED, 0xFFFF_FFFF, 0xFFFF_FFFF, 0xFFFF_FFFF,
        0xFFFF_FFFF, 0xFFFF_FFFF, 0xFFFF_FFFF, 0x7FFF_FFFF,
    ]

    let limbs: [UInt32]

    init(littleEndianBytes bytes: Data) {
        var limbs: [UInt32] = []
        limbs.reserveCapacity(8)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            var limb: UInt32 = 0
            for byteOffset in 0 ..< 4 where index + byteOffset < bytes.count {
                limb |= UInt32(bytes[index + byteOffset]) << UInt32(byteOffset * 8)
            }
            limbs.append(limb)
        }
        self.limbs = BigUInt.reduce(limbs)
    }

    init(reducedLimbs limbs: [UInt32]) {
        self.limbs = BigUInt.trim(limbs)
    }

    init(limbs: [UInt32]) {
        self.limbs = BigUInt.reduce(limbs)
    }

    var isZero: Bool {
        limbs.isEmpty
    }

    var isOdd: Bool {
        (limbs.first ?? 0) & 1 == 1
    }

    func squared() -> FieldElement {
        self * self
    }

    func inverted() -> FieldElement {
        var result = FieldElement.one
        var base = self
        var exponent = Data(repeating: 0xFF, count: 32)
        exponent[0] = 0xEB
        exponent[31] = 0x7F
        for byte in exponent {
            for bit in 0 ..< 8 {
                if (byte & (UInt8(1) << UInt8(bit))) != 0 {
                    result = result * base
                }
                base = base.squared()
            }
        }
        return result
    }

    func littleEndianBytes(count: Int) -> Data {
        Ed25519Scalar.littleEndianBytes(from: limbs, count: count)
    }

    func selected(_ other: FieldElement, mask: UInt32) -> FieldElement {
        let lhs = fixedWidthLimbs()
        let rhs = other.fixedWidthLimbs()
        let selected = zip(lhs, rhs).map { left, right in
            left ^ (mask & (left ^ right))
        }
        return FieldElement(reducedLimbs: selected)
    }

    private func fixedWidthLimbs() -> [UInt32] {
        (0 ..< 8).map { index in
            index < limbs.count ? limbs[index] : 0
        }
    }

    static prefix func - (value: FieldElement) -> FieldElement {
        if value.isZero {
            return value
        }
        return FieldElement(reducedLimbs: BigUInt.subtract(modulus, value.limbs))
    }

    static func + (lhs: FieldElement, rhs: FieldElement) -> FieldElement {
        FieldElement(limbs: BigUInt.add(lhs.limbs, rhs.limbs))
    }

    static func - (lhs: FieldElement, rhs: FieldElement) -> FieldElement {
        if BigUInt.compare(lhs.limbs, rhs.limbs) >= 0 {
            return FieldElement(reducedLimbs: BigUInt.subtract(lhs.limbs, rhs.limbs))
        }
        let borrowed = BigUInt.add(lhs.limbs, modulus)
        return FieldElement(limbs: BigUInt.subtract(borrowed, rhs.limbs))
    }

    static func * (lhs: FieldElement, rhs: FieldElement) -> FieldElement {
        FieldElement(limbs: BigUInt.multiply(lhs.limbs, rhs.limbs))
    }
}

enum BigUInt {
    static func trim(_ limbs: [UInt32]) -> [UInt32] {
        var out = limbs
        while out.last == 0 {
            out.removeLast()
        }
        return out
    }

    static func compare(_ lhs: [UInt32], _ rhs: [UInt32]) -> Int {
        let lhs = trim(lhs)
        let rhs = trim(rhs)
        if lhs.count != rhs.count {
            return lhs.count < rhs.count ? -1 : 1
        }
        if lhs.isEmpty {
            return 0
        }
        for index in stride(from: lhs.count - 1, through: 0, by: -1) {
            if lhs[index] != rhs[index] {
                return lhs[index] < rhs[index] ? -1 : 1
            }
            if index == 0 {
                break
            }
        }
        return 0
    }

    static func add(_ lhs: [UInt32], _ rhs: [UInt32]) -> [UInt32] {
        let count = max(lhs.count, rhs.count)
        var out = Array(repeating: UInt32(0), count: count + 1)
        var carry: UInt64 = 0
        for index in 0 ..< count {
            let sum = UInt64(index < lhs.count ? lhs[index] : 0) + UInt64(index < rhs.count ? rhs[index] : 0) + carry
            out[index] = UInt32(sum & 0xFFFF_FFFF)
            carry = sum >> 32
        }
        if carry > 0 {
            out[count] = UInt32(carry)
        }
        return trim(out)
    }

    static func subtract(_ lhs: [UInt32], _ rhs: [UInt32]) -> [UInt32] {
        var out = Array(repeating: UInt32(0), count: lhs.count)
        var borrow: Int64 = 0
        for index in 0 ..< lhs.count {
            var value = Int64(lhs[index]) - Int64(index < rhs.count ? rhs[index] : 0) - borrow
            if value < 0 {
                value += Int64(1) << 32
                borrow = 1
            } else {
                borrow = 0
            }
            out[index] = UInt32(value)
        }
        return trim(out)
    }

    static func multiplySmall(_ limbs: [UInt32], by multiplier: UInt32) -> [UInt32] {
        guard multiplier != 0, !limbs.isEmpty else {
            return []
        }
        var out = Array(repeating: UInt32(0), count: limbs.count + 1)
        var carry: UInt64 = 0
        for index in limbs.indices {
            let product = UInt64(limbs[index]) * UInt64(multiplier) + carry
            out[index] = UInt32(product & 0xFFFF_FFFF)
            carry = product >> 32
        }
        if carry > 0 {
            out[limbs.count] = UInt32(carry)
        }
        return trim(out)
    }

    static func multiplyFull(_ lhs: [UInt32], _ rhs: [UInt32]) -> [UInt32] {
        guard !lhs.isEmpty, !rhs.isEmpty else {
            return []
        }
        var out = Array(repeating: UInt32(0), count: lhs.count + rhs.count + 1)
        for i in lhs.indices {
            var carry: UInt64 = 0
            for j in rhs.indices {
                let index = i + j
                let product = UInt64(lhs[i]) * UInt64(rhs[j]) + UInt64(out[index]) + carry
                out[index] = UInt32(product & 0xFFFF_FFFF)
                carry = product >> 32
            }
            var index = i + rhs.count
            while carry > 0 {
                let sum = UInt64(out[index]) + carry
                out[index] = UInt32(sum & 0xFFFF_FFFF)
                carry = sum >> 32
                index += 1
            }
        }
        return trim(out)
    }

    static func multiply(_ lhs: [UInt32], _ rhs: [UInt32]) -> [UInt32] {
        let out = multiplyFull(lhs, rhs)
        return reduce(out)
    }

    static func reduce(_ limbs: [UInt32]) -> [UInt32] {
        var current = trim(limbs)
        for _ in 0 ..< 4 {
            if bitLength(current) <= 255 {
                break
            }
            let low = low255(current)
            let high = shiftRight255(current)
            current = add(low, multiplySmall(high, by: 19))
        }
        while compare(current, FieldElement.modulus) >= 0 {
            current = subtract(current, FieldElement.modulus)
        }
        return trim(current)
    }

    static func bitLength(_ limbs: [UInt32]) -> Int {
        guard let last = trim(limbs).last else {
            return 0
        }
        return (trim(limbs).count - 1) * 32 + (32 - last.leadingZeroBitCount)
    }

    static func low255(_ limbs: [UInt32]) -> [UInt32] {
        var low = Array(limbs.prefix(8))
        if low.count < 8 {
            low.append(contentsOf: repeatElement(0, count: 8 - low.count))
        }
        low[7] &= 0x7FFF_FFFF
        return trim(low)
    }

    static func shiftRight255(_ limbs: [UInt32]) -> [UInt32] {
        if limbs.count <= 7 {
            return []
        }
        var out: [UInt32] = []
        var index = 7
        while index < limbs.count {
            let lower = UInt64(limbs[index] >> 31)
            let upper = index + 1 < limbs.count ? UInt64(limbs[index + 1]) << 1 : 0
            out.append(UInt32((lower | upper) & 0xFFFF_FFFF))
            index += 1
        }
        return trim(out)
    }
}
