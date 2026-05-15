@testable import PluginCore
import XCTest
import os

final class PluginCoreTests: XCTestCase {
    func test_createClient_startsWithValueAndAppliesSyncPlugins() throws {
        let client = createClient()
            .use { _ in PluginClientProperties(["fruit": .string("apple")]) }
            .use { properties in
                extendClient(properties, PluginClientProperties(["vegetable": .string("carrot")]))
            }

        XCTAssertEqual(client.value["fruit"], .string("apple"))
        XCTAssertEqual(client.value["vegetable"], .string("carrot"))
    }

    func test_createClient_supportsAsyncPluginChaining() async throws {
        let client = try await createClient()
            .use { _ in PluginClientProperties(["fruit": .string("apple")]) }
            .useAsync { properties in
                extendClient(properties, PluginClientProperties(["vegetable": .string("carrot")]))
            }
            .use { properties in
                extendClient(properties, PluginClientProperties(["grain": .string("rice")]))
            }
            .value()

        XCTAssertEqual(client.value["fruit"], .string("apple"))
        XCTAssertEqual(client.value["vegetable"], .string("carrot"))
        XCTAssertEqual(client.value["grain"], .string("rice"))
    }

    func test_extendClient_additionsOverrideExistingKeys() {
        let result = extendClient(
            PluginClientProperties(["fruit": .string("apple"), "vegetable": .string("carrot")]),
            PluginClientProperties(["fruit": .string("banana")])
        )

        XCTAssertEqual(result["fruit"], .string("banana"))
        XCTAssertEqual(result["vegetable"], .string("carrot"))
        XCTAssertEqual(result.keys, ["fruit", "vegetable"])
    }

    func test_withCleanup_callsCleanupsInLIFOOrder() {
        let recorder = OSAllocatedUnfairLock(initialState: [String]())
        let client = withCleanup(withCleanup(EmptyPluginClientValue()) {
            recorder.withLock { $0.append("first") }
        }) {
            recorder.withLock { $0.append("second") }
        }

        client.dispose()

        XCTAssertEqual(recorder.withLock { $0 }, ["second", "first"])
    }
}
