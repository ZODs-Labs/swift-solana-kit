@testable import PluginCore
import XCTest
import os

final class PluginCoreDetailedBehaviorTests: XCTestCase {
    func testCreateClientPreservesInitialValueAndCreateEmptyClientMatchesDefault() {
        let initial = createClient(PluginClientProperties(["fruit": .string("banana")]))
        let empty = createEmptyClient()

        XCTAssertEqual(initial.value["fruit"], .string("banana"))
        XCTAssertEqual(empty.value, EmptyPluginClientValue())
        XCTAssertEqual(createClient().value, empty.value)
    }

    func testPluginsReplaceClientShapeWhenTheyDoNotPreserveInput() {
        let client = createClient()
            .use { _ in PluginClientProperties(["fruit": .string("apple")]) }
            .use { _ in PluginClientProperties(["vegetable": .string("carrot")]) }

        XCTAssertNil(client.value["fruit"])
        XCTAssertEqual(client.value["vegetable"], .string("carrot"))
        XCTAssertEqual(client.value.keys, ["vegetable"])
    }

    func testAsyncPluginsAreLazyUntilTheValueIsResolved() async throws {
        let calls = OSAllocatedUnfairLock(initialState: [String]())
        let client = createClient()
            .useAsync { _ in
                calls.withLock { $0.append("first") }
                return PluginClientProperties(["fruit": .string("apple")])
            }
            .use { properties in
                calls.withLock { $0.append("second") }
                return extendClient(properties, PluginClientProperties(["dessert": .string("pie")]))
            }

        XCTAssertEqual(calls.withLock { $0 }, [])

        let resolved = try await client.value()

        XCTAssertEqual(resolved.value["fruit"], .string("apple"))
        XCTAssertEqual(resolved.value["dessert"], .string("pie"))
        XCTAssertEqual(calls.withLock { $0 }, ["first", "second"])
    }

    func testSyncAndAsyncPluginErrorsStopLaterPlugins() async {
        XCTAssertThrowsError(
            try createClient(1)
                .use(pluginCoreThrowingSyncPlugin)
                .value
        ) { error in
            XCTAssertTrue(error is PluginCoreTestError)
        }

        let calls = OSAllocatedUnfairLock(initialState: [String]())
        let asyncClient = createClient()
            .useAsync { _ -> PluginClientProperties in
                calls.withLock { $0.append("first") }
                throw PluginCoreTestError()
            }
            .use { properties in
                calls.withLock { $0.append("second") }
                return properties
            }

        do {
            _ = try await asyncClient.value()
            XCTFail("Expected async plugin failure")
        } catch {
            XCTAssertTrue(error is PluginCoreTestError)
            XCTAssertEqual(calls.withLock { $0 }, ["first"])
        }
    }

    func testExtendingPropertiesDoesNotMutateEitherInput() {
        let original = PluginClientProperties(["fruit": .string("apple")])
        let additions = PluginClientProperties(["fruit": .string("banana"), "vegetable": .string("carrot")])

        let extended = original.extending(with: additions)

        XCTAssertEqual(original["fruit"], .string("apple"))
        XCTAssertNil(original["vegetable"])
        XCTAssertEqual(additions["fruit"], .string("banana"))
        XCTAssertEqual(extended["fruit"], .string("banana"))
        XCTAssertEqual(extended["vegetable"], .string("carrot"))
        XCTAssertEqual(extended.keys, ["fruit", "vegetable"])
    }

    func testCleanupsDoNotRunBeforeDisposeAndPreserveTheWrappedValue() {
        let calls = OSAllocatedUnfairLock(initialState: [String]())
        let client = withCleanup(PluginClientProperties(["fruit": .string("apple")])) {
            calls.withLock { $0.append("cleanup") }
        }

        XCTAssertEqual(client.value["fruit"], .string("apple"))
        XCTAssertEqual(calls.withLock { $0 }, [])

        client.dispose()

        XCTAssertEqual(calls.withLock { $0 }, ["cleanup"])
    }

    func testAddingCleanupReturnsANewClientWithoutChangingTheOriginalOrder() {
        let calls = OSAllocatedUnfairLock(initialState: [String]())
        let original = withCleanup(EmptyPluginClientValue()) {
            calls.withLock { $0.append("first") }
        }
        let extended = original.addingCleanup {
            calls.withLock { $0.append("second") }
        }

        original.dispose()
        XCTAssertEqual(calls.withLock { $0 }, ["first"])

        calls.withLock { $0.removeAll() }
        extended.dispose()
        XCTAssertEqual(calls.withLock { $0 }, ["second", "first"])
    }
}

private struct PluginCoreTestError: Error, Equatable {}

private func pluginCoreThrowingSyncPlugin(_ value: Int) throws -> Int {
    throw PluginCoreTestError()
}
