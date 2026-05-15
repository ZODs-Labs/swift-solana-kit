public import CodecsCore
import CodecsDataStructures
public import CodecsNumbers
public import Foundation
public import RpcTypes
import SolanaErrors

let bitvecDiscriminator = 1
let bitvecNumBits = 1_024 * 1_024
let bitvecLength = bitvecNumBits / 64
let slotHistoryAccountDataStaticSize = 1 + 8 + bitvecLength * 8 + 8 + 8

func readU8(_ bytes: Data, _ offset: Int) throws -> (Int, Int) {
    try getU8Decoder().read(bytes, at: offset)
}

func writeU8(_ value: Int, into bytes: inout Data, at offset: Int) throws -> Int {
    try getU8Encoder().write(value, into: &bytes, at: offset)
}

func readBool(_ bytes: Data, _ offset: Int) throws -> (Bool, Int) {
    try getBooleanDecoder().read(bytes, at: offset)
}

func writeBool(_ value: Bool, into bytes: inout Data, at offset: Int) throws -> Int {
    try getBooleanEncoder().write(value, into: &bytes, at: offset)
}

func readU32(_ bytes: Data, _ offset: Int) throws -> (Int, Int) {
    try getU32Decoder().read(bytes, at: offset)
}

func writeU32(_ value: Int, into bytes: inout Data, at offset: Int) throws -> Int {
    try getU32Encoder().write(value, into: &bytes, at: offset)
}

func readU64(_ bytes: Data, _ offset: Int) throws -> (UInt64, Int) {
    try getU64Decoder().read(bytes, at: offset)
}

func writeU64(_ value: UInt64, into bytes: inout Data, at offset: Int) throws -> Int {
    try getU64Encoder().write(value, into: &bytes, at: offset)
}

func readI64(_ bytes: Data, _ offset: Int) throws -> (Int64, Int) {
    try getI64Decoder().read(bytes, at: offset)
}

func writeI64(_ value: Int64, into bytes: inout Data, at offset: Int) throws -> Int {
    try getI64Encoder().write(value, into: &bytes, at: offset)
}

func readU128(_ bytes: Data, _ offset: Int) throws -> (UInt128Value, Int) {
    try getU128Decoder().read(bytes, at: offset)
}

func writeU128(_ value: UInt128Value, into bytes: inout Data, at offset: Int) throws -> Int {
    try getU128Encoder().write(value, into: &bytes, at: offset)
}

func readF64(_ bytes: Data, _ offset: Int) throws -> (Double, Int) {
    try getF64Decoder().read(bytes, at: offset)
}

func writeF64(_ value: Double, into bytes: inout Data, at offset: Int) throws -> Int {
    try getF64Encoder().write(value, into: &bytes, at: offset)
}

func readBlockhash(_ bytes: Data, _ offset: Int) throws -> (Blockhash, Int) {
    try getBlockhashDecoder().read(bytes, at: offset)
}

func writeBlockhash(_ value: Blockhash, into bytes: inout Data, at offset: Int) throws -> Int {
    try getBlockhashEncoder().write(value, into: &bytes, at: offset)
}

func checkedInt(_ value: UInt64, codecDescription: String) throws -> Int {
    guard value <= UInt64(Int.max) else {
        throw CodecsError.numberOutOfRange(
            codecDescription: codecDescription,
            min: "0",
            max: String(Int.max),
            value: String(value)
        )
    }
    return Int(value)
}

func exactByteLength(_ bytes: Data, expected: Int, codecDescription: String) throws {
    if bytes.count != expected {
        throw CodecsError.invalidByteLength(codecDescription: codecDescription, expected: expected, bytesLength: bytes.count)
    }
}
