@testable import Addresses
import CryptoKitBackend
import Foundation
import SolanaErrors
import XCTest

final class AddressesTests: XCTestCase {
    private let backend = CryptoKitBackend()

    func testAddressValidationMatchesLengthAndByteRules() throws {
        XCTAssertFalse(isAddress("not-a-base-58-encoded-string"))
        XCTAssertFalse(isAddress("2xea9jWJ9eca3dFiefTeSPP85c6qXqunCqL2h2JNffM"))
        XCTAssertTrue(isAddress("11111111111111111111111111111111"))

        XCTAssertThrowsError(try assertIsAddress("not-a-base-58-encoded-string")) { error in
            XCTAssertEqual(solanaCode(error), AddressError.stringLengthOutOfRange(actualLength: 28).code)
        }
        XCTAssertThrowsError(try assertIsAddress("2xea9jWJ9eca3dFiefTeSPP85c6qXqunCqL2h2JNffM")) { error in
            XCTAssertEqual(solanaCode(error), AddressError.invalidByteLength(actualLength: 31).code)
        }
        XCTAssertNoThrow(try assertIsAddress("11111111111111111111111111111111"))
    }

    func testAddressCoercionReturnsValidatedAddress() throws {
        let raw = "GQE2yjns7SKKuMc89tveBDpzYHwXfeuB2PGAbGaPWc6G"
        XCTAssertEqual(try address(raw).rawValue, raw)

        for actualLength in [31, 45] {
            XCTAssertThrowsError(try address(String(repeating: "3", count: actualLength))) { error in
                XCTAssertEqual(solanaCode(error), AddressError.stringLengthOutOfRange(actualLength: actualLength).code)
            }
        }

        let byteLengthFailures = [
            (31, "tVojvhToWjQ8Xvo4UPx2Xz9eRy7auyYMmZBjc2XfN"),
            (33, "JJEfe6DcPM2ziB2vfUWDV6aHVerXRGkv3TcyvJUNGHZz"),
        ]
        for (actualLength, badAddress) in byteLengthFailures {
            XCTAssertThrowsError(try address(badAddress)) { error in
                XCTAssertEqual(solanaCode(error), AddressError.invalidByteLength(actualLength: actualLength).code)
            }
        }
    }

    func testAddressCodecMatchesBase58Bytes() throws {
        let codec = getAddressCodec()
        let encoded = try codec.encode(try address("4wBqpZM9xaSheZzJSMawUHDgZ7miWfSsxmfVF5jJpYP"))
        XCTAssertEqual(encoded, Data([
            1, 2, 3, 4, 5, 6, 7, 8,
            9, 10, 11, 12, 13, 14, 15, 16,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
        ]))

        let decoded = try codec.decode(Data([
            1, 2, 3, 4, 5, 6, 7, 8,
            9, 10, 11, 12, 13, 14, 15, 16,
            17, 18, 19, 20, 21, 22, 23, 24,
            25, 26, 27, 28, 29, 30, 31, 32,
            33, 34,
        ]))
        XCTAssertEqual(decoded.rawValue, "4wBqpZM9xaSheZzJSMawUKKwhdpChKbZ5eu5ky4Vigw")

        XCTAssertThrowsError(try codec.decode(Data(repeating: 0, count: 31))) { error in
            XCTAssertEqual(solanaCode(error), CodecsError.invalidByteLength(codecDescription: "fixCodecSize", expected: 32, bytesLength: 31).code)
        }
    }

    func testAddressComparatorUsesStableCollation() throws {
        let input = try [
            "Ht1VrhoyhwMGMpBBi89BPdJp5R39Mu49suKx3A22W9Qs",
            "J9ZSLc9qPg3FR8UqfN6ae1QkVReUmnpLgQqFkGEPqmod",
            "6JYSQqSHY1E5JDwEfgWMieozqA1KCwiP2cH69to9eWKH",
            "7YR1xA7yzFAT4yQCsS4rpowjU1tsh5YUJd9hWMHRppcX",
            "7grJ9YUAEHxckLFqCY7fq8cM1UrragNSuPH1dvwJ8EEK",
            "AJBPNWCjVLwxff2eJynW56cMRCGmyU4y3vbuvtVdgVgb",
            "B8A2zUEDtJjR7nrokNUJYhgUQiwEBzC88rZc6WUE5ZeF",
            "BKggsVVp7yLmXtPuBDtC3FXBzvLyyye3Q2tFKUUGCHLj",
            "Ds72joawSKQ9nCDAAmGMKFiwiY6HR7PDzYDHDzZom3tj",
            "F1zKr4ZUYo5UAnH1fvYaD6R7ne137NYfS1r5HrCb8NpF",
        ].map(address)

        let comparator = getAddressComparator()
        XCTAssertEqual(input.sorted { comparator($0, $1) < 0 }.map(\.rawValue), [
            "6JYSQqSHY1E5JDwEfgWMieozqA1KCwiP2cH69to9eWKH",
            "7grJ9YUAEHxckLFqCY7fq8cM1UrragNSuPH1dvwJ8EEK",
            "7YR1xA7yzFAT4yQCsS4rpowjU1tsh5YUJd9hWMHRppcX",
            "AJBPNWCjVLwxff2eJynW56cMRCGmyU4y3vbuvtVdgVgb",
            "B8A2zUEDtJjR7nrokNUJYhgUQiwEBzC88rZc6WUE5ZeF",
            "BKggsVVp7yLmXtPuBDtC3FXBzvLyyye3Q2tFKUUGCHLj",
            "Ds72joawSKQ9nCDAAmGMKFiwiY6HR7PDzYDHDzZom3tj",
            "F1zKr4ZUYo5UAnH1fvYaD6R7ne137NYfS1r5HrCb8NpF",
            "Ht1VrhoyhwMGMpBBi89BPdJp5R39Mu49suKx3A22W9Qs",
            "J9ZSLc9qPg3FR8UqfN6ae1QkVReUmnpLgQqFkGEPqmod",
        ])
    }

    func testCurveChecksMatchKnownCompressedKeys() throws {
        let offCurveKeyBytes = [
            Data([
                0, 121, 240, 130, 166, 28, 199, 78,
                165, 226, 171, 237, 100, 187, 247, 95,
                50, 251, 221, 83, 122, 255, 247, 82,
                87, 237, 103, 22, 201, 227, 114, 153,
            ]),
            Data([
                194, 222, 197, 61, 68, 225, 252, 198,
                155, 150, 247, 44, 45, 10, 115, 8,
                12, 50, 138, 12, 106, 199, 75, 172,
                159, 87, 94, 122, 251, 246, 136, 75,
            ]),
        ]
        let onCurveKeyBytes = [
            Data([
                107, 141, 87, 175, 101, 27, 216, 58,
                238, 95, 193, 175, 21, 151, 207, 102,
                28, 107, 157, 178, 69, 77, 203, 89,
                199, 77, 162, 19, 27, 108, 57, 155,
            ]),
            Data([
                52, 94, 161, 109, 55, 62, 164, 12,
                183, 165, 56, 112, 86, 103, 19, 109,
                196, 33, 93, 42, 143, 6, 221, 172,
                173, 21, 130, 96, 170, 101, 82, 200,
            ]),
        ]

        for bytes in offCurveKeyBytes {
            XCTAssertFalse(compressedPointBytesAreOnCurve(bytes, using: backend))
        }
        for bytes in onCurveKeyBytes {
            XCTAssertTrue(compressedPointBytesAreOnCurve(bytes, using: backend))
        }
    }

    func testOffCurveAddressValidationMatchesKnownAddresses() throws {
        let onCurveAddresses = try [
            "nick6zJc6HpW3kfBm4xS2dmbuVRyb5F3AnUvj5ymzR5",
            "11111111111111111111111111111111",
            "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
            "SQDS4ep65T869zMMBKyuUq6aD6EgTu8psMjkvj52pCf",
        ].map(address)
        let offCurveAddresses = try [
            "CCMCWh4FudPEmY6Q1AVi5o8mQMXkHYkJUmZfzRGdcJ9P",
            "2DRxyJDsDccGL6mb8PLMsKQTCU3C7xUq8aprz53VcW4k",
        ].map(address)

        for value in offCurveAddresses {
            XCTAssertTrue(isOffCurveAddress(value, using: backend))
            XCTAssertEqual(try offCurveAddress(value, using: backend).rawValue, value.rawValue)
        }
        for value in onCurveAddresses {
            XCTAssertFalse(isOffCurveAddress(value, using: backend))
            XCTAssertThrowsError(try assertIsOffCurveAddress(value, using: backend)) { error in
                XCTAssertEqual(solanaCode(error), AddressError.invalidOffCurveAddress.code)
            }
        }
    }

    func testPublicKeyByteConversionsMatchAddressBytes() throws {
        let publicKeyBytes = Data([
            0xBB, 0x52, 0xC6, 0x2D, 0x52, 0x4F, 0x7F, 0xEA,
            0x4F, 0x2C, 0x27, 0x13, 0xD6, 0x20, 0x80, 0xAD,
            0x6A, 0x36, 0x9A, 0x0E, 0x36, 0x71, 0x74, 0x32,
            0x8D, 0x1A, 0xF7, 0xEE, 0x7E, 0x04, 0x76, 0x19,
        ])
        let publicKeyAddress = try getAddressFromPublicKey(publicKeyBytes)

        XCTAssertEqual(publicKeyAddress.rawValue, "DcESq8KFcdTdpjWtr2DoGcvu5McM3VJoBetgM1X1vVct")
        XCTAssertEqual(try getPublicKeyFromAddress(publicKeyAddress), publicKeyBytes)
        XCTAssertThrowsError(try getAddressFromPublicKey(Data(repeating: 0, count: 31))) { error in
            XCTAssertEqual(solanaCode(error), AddressError.invalidEd25519PublicKey.code)
        }
    }

    func testProgramDerivedAddressMatchesKnownCases() throws {
        let cases: [(String, [ProgramDerivedAddressSeed], String, UInt8)] = [
            ("CZ3TbkgUYpDAJVEWpujQhDSgzNTeqbokrJmYa1j4HAZc", [], "9tVtkyCGAHSDDBPwz7895aC3p2gJRjpu2v26o35FTUco", 255),
            ("EfTbwNBrSqSuCNBhWUHsBoBdSMWgRU1S47daqRNgW7aK", [], "CKWT8KZ5GMzKpVRiAULWKPg1LiHt9U3NdAtbuTErHCTq", 251),
            ("FD3PDEvpQ9JXq8tv7FpJPyZrCjWkCnAaTju16gFPdpqP", [.bytes(Data([1, 2, 3]))], "9Tj3hpMWacDiZoBe94sjwJQ72zsUVvEQYsrqyy2CfHky", 255),
            ("9HT3iB4oX1aZPH5V8eNUGByKuwhfcKjBQ3x9rfEAuNeF", [.bytes(Data([1, 2, 3]))], "EeTcRajHcPh74C5D4GqZePac1wYB7Dj9ChTaNHaTH77V", 251),
            ("EKaNRGA37uiGRyRPMap5EZg9cmbT5mt7KWrGwKwAQ3rK", [.utf8("hello")], "6V76gtKMCmVVjrx4sxR9uB868HtZbL3piKEmadC7rSgf", 255),
            ("9PyoV2rqNtoboSvg2JD7GWhM5RQvHGwgdDvK7MCfpgX1", [.utf8("hello")], "E6npEurFu1UEbQFh1DsqBvny17XxUK2QPMgxD3Edn3aG", 251),
            ("A5dcVPLJsE2vbf7hkqqyYkYDK9UjUfNxuwGtWF2m2vEz", [.utf8("\u{1F680}")], "GYpAzW57Ex4Sw3rp4pq95QrjvtsDyqZsMhSZwqz3NMsE", 255),
            ("H8gBP21L5ietkHgXcGbgQBCVVEdPUQyuP9Q5MPRLLSJu", [.utf8("\u{1F680}")], "46v3JvPtEPeQmH3euXydEbxYD6yfxeZjWSzkkYvvM5Pp", 251),
        ]

        for (programAddress, seeds, expectedAddress, expectedBump) in cases {
            let pda = try getProgramDerivedAddress(
                programAddress: try address(programAddress),
                seeds: seeds,
                using: backend
            )
            XCTAssertEqual(pda.address.rawValue, expectedAddress)
            XCTAssertEqual(pda.bump.rawValue, expectedBump)
        }

        let butterfly = try getProgramDerivedAddress(
            programAddress: try address("9PyoV2rqNtoboSvg2JD7GWhM5RQvHGwgdDvK7MCfpgX1"),
            seeds: [.utf8("butterfly")],
            using: backend
        )
        let butterFly = try getProgramDerivedAddress(
            programAddress: try address("9PyoV2rqNtoboSvg2JD7GWhM5RQvHGwgdDvK7MCfpgX1"),
            seeds: [.utf8("butter"), .utf8("fly")],
            using: backend
        )
        XCTAssertEqual(butterfly, butterFly)
    }

    func testProgramDerivedAddressRejectsInvalidSeeds() throws {
        XCTAssertThrowsError(
            try getProgramDerivedAddress(
                programAddress: try address("FN2R9R724eb4WaxeDmDYrUtmJgoSzkBiQMEHELV3ocyg"),
                seeds: Array(repeating: .utf8(""), count: 17),
                using: backend
            )
        ) { error in
            XCTAssertEqual(solanaCode(error), AddressError.maxNumberOfPDASeedsExceeded(actual: 18, maxSeeds: 16).code)
        }

        for oversizedSeed in [ProgramDerivedAddressSeed.bytes(Data(repeating: 0, count: 33)), .utf8(String(repeating: "a", count: 33))] {
            XCTAssertThrowsError(
                try getProgramDerivedAddress(
                    programAddress: try address("5eUi55m4FVaDqKubGH9r6ca1TxjmimmXEU9v1WUZJ47Z"),
                    seeds: [oversizedSeed],
                    using: backend
                )
            ) { error in
                XCTAssertEqual(solanaCode(error), AddressError.maxPDASeedLengthExceeded(actual: 33, index: 0, maxSeedLength: 32).code)
            }
        }
    }

    func testCreateAddressWithSeedMatchesKnownCases() throws {
        let baseAddress = try address("Bh1uUDP3ApWLeccVNHwyQKpnfGQbuE2UECbGA6M4jiZJ")
        let programAddress = try address("FGrddpvjBUAG6VdV4fR8Q2hEZTHS6w4SEveVBgfwbfdm")
        let expectedAddress = "HUKxCeXY6gZohFJFARbLE6L6C9wDEHz1SfK8ENM7QY7z"

        XCTAssertEqual(
            try createAddressWithSeed(baseAddress: baseAddress, programAddress: programAddress, seed: .utf8("seed"), using: backend).rawValue,
            expectedAddress
        )
        XCTAssertEqual(
            try createAddressWithSeed(baseAddress: baseAddress, programAddress: programAddress, seed: .bytes(Data([0x73, 0x65, 0x65, 0x64])), using: backend).rawValue,
            expectedAddress
        )

        XCTAssertThrowsError(
            try createAddressWithSeed(baseAddress: baseAddress, programAddress: programAddress, seed: .utf8(String(repeating: "a", count: 33)), using: backend)
        ) { error in
            XCTAssertEqual(solanaCode(error), AddressError.maxPDASeedLengthExceeded(actual: 33, index: 0, maxSeedLength: 32).code)
        }

        XCTAssertThrowsError(
            try createAddressWithSeed(
                baseAddress: baseAddress,
                programAddress: try address("4vJ9JU1bJJE96FbKdjWme2JfVK1knU936FHTDZV7AC2"),
                seed: .utf8("seed"),
                using: backend
            )
        ) { error in
            XCTAssertEqual(solanaCode(error), AddressError.pdaEndsWithPDAMarker.code)
        }
    }

    func testProgramDerivedAddressBumpValidatesRange() {
        XCTAssertNoThrow(try ProgramDerivedAddressBump(0))
        XCTAssertNoThrow(try ProgramDerivedAddressBump(255))
        XCTAssertThrowsError(try ProgramDerivedAddressBump(-1)) { error in
            XCTAssertEqual(solanaCode(error), AddressError.pdaBumpSeedOutOfRange(bump: -1).code)
        }
        XCTAssertThrowsError(try ProgramDerivedAddressBump(256)) { error in
            XCTAssertEqual(solanaCode(error), AddressError.pdaBumpSeedOutOfRange(bump: 256).code)
        }
    }
}

private func solanaCode(_ error: any Error) -> Int? {
    (error as? any SolanaErrorCoded)?.code
}
