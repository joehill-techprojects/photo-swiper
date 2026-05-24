//
//  PhotoFetcherTests.swift
//  PhotoSwiperTests
//
//  Unit tests for `PhotoFetcher`. Covers orchestration behavior we can
//  exercise without a real photo library:
//    - Authorization gating (denied/notDetermined → empty stream, fetcher
//      never invoked; authorized/limited → fetcher invoked).
//    - PHFetchOptions configuration (oldest-first sort descriptor).
//    - Iterator returns an empty stream when the injected fetcher returns
//      an empty array, in both order modes.
//    - The injected `SeededRandomNumberGenerator` is itself deterministic,
//      which is what makes the random-mode shuffle reproducible. We test
//      the RNG directly because the iterator's shuffle path is only
//      observable when assets are present, and we cannot construct real
//      `PHAsset`s from outside PhotoKit's database.
//
//  Skipped (with `XCTSkip`): tests that require synthesizing PHAssets —
//  the cloud-shared filter and the actual shuffled-order assertion. Those
//  belong in Phase 5 polish where they can run against a device library.
//

import XCTest
import Photos
@testable import PhotoSwiper

@MainActor
final class PhotoFetcherTests: XCTestCase {

    // MARK: - Authorization gating

    func test_iteratorReturnsEmptyStreamWhenUnauthorized() async {
        let fetcherCalled = LockedFlag()
        let sut = PhotoFetcher(
            fetchAssets: { _ in
                fetcherCalled.set(true)
                return []
            },
            authorizationStatus: { .denied }
        )

        let stream = await sut.iterator(order: .oldestFirst)
        let count = await collect(stream).count

        XCTAssertEqual(count, 0, "Denied auth should produce an empty stream")
        XCTAssertFalse(
            fetcherCalled.get(),
            "AssetFetcher must NOT be called when authorization is denied"
        )
    }

    func test_iteratorReturnsEmptyStreamWhenNotDetermined() async {
        let fetcherCalled = LockedFlag()
        let sut = PhotoFetcher(
            fetchAssets: { _ in
                fetcherCalled.set(true)
                return []
            },
            authorizationStatus: { .notDetermined }
        )

        let stream = await sut.iterator(order: .random)
        let count = await collect(stream).count

        XCTAssertEqual(count, 0)
        XCTAssertFalse(
            fetcherCalled.get(),
            "AssetFetcher must NOT be called when authorization is notDetermined"
        )
    }

    func test_iteratorInvokesFetcherWhenAuthorized() async {
        let fetcherCalled = LockedFlag()
        let sut = PhotoFetcher(
            fetchAssets: { _ in
                fetcherCalled.set(true)
                return []
            },
            authorizationStatus: { .authorized }
        )

        _ = await sut.iterator(order: .oldestFirst)

        XCTAssertTrue(
            fetcherCalled.get(),
            "AssetFetcher MUST be called when authorization is authorized"
        )
    }

    func test_iteratorInvokesFetcherWhenLimited() async {
        let fetcherCalled = LockedFlag()
        let sut = PhotoFetcher(
            fetchAssets: { _ in
                fetcherCalled.set(true)
                return []
            },
            authorizationStatus: { .limited }
        )

        _ = await sut.iterator(order: .random)

        XCTAssertTrue(
            fetcherCalled.get(),
            "AssetFetcher MUST be called when authorization is limited"
        )
    }

    // MARK: - PHFetchOptions configuration

    func test_fetcherReceivesOldestFirstSortDescriptor() async throws {
        let capturedOptions = LockedBox<PHFetchOptions>()
        let sut = PhotoFetcher(
            fetchAssets: { options in
                capturedOptions.set(options)
                return []
            },
            authorizationStatus: { .authorized }
        )

        _ = await sut.iterator(order: .oldestFirst)

        let options = try XCTUnwrap(capturedOptions.get())
        let descriptors = options.sortDescriptors ?? []
        XCTAssertEqual(descriptors.count, 1, "Expected exactly one sort descriptor")
        XCTAssertEqual(descriptors.first?.key, "creationDate")
        XCTAssertEqual(descriptors.first?.ascending, true,
                       "oldest-first means ascending creationDate")
    }

    func test_fetcherReceivesSameSortDescriptorForRandomMode() async throws {
        // The PhotoFetcher always asks PhotoKit to sort by creationDate
        // ascending — the random shuffle happens in-memory afterward. This
        // pins that contract so a future refactor doesn't silently change
        // it (which would affect Phase 5 manual testing).
        let capturedOptions = LockedBox<PHFetchOptions>()
        let sut = PhotoFetcher(
            fetchAssets: { options in
                capturedOptions.set(options)
                return []
            },
            authorizationStatus: { .authorized }
        )

        _ = await sut.iterator(order: .random)

        let options = try XCTUnwrap(capturedOptions.get())
        XCTAssertEqual(options.sortDescriptors?.first?.key, "creationDate")
    }

    // MARK: - Empty-input orchestration

    func test_iteratorReturnsEmptyStreamWhenFetcherReturnsEmpty_oldestFirst() async {
        let sut = PhotoFetcher(
            fetchAssets: { _ in [] },
            authorizationStatus: { .authorized }
        )

        let stream = await sut.iterator(order: .oldestFirst)
        let collected = await collect(stream)

        XCTAssertEqual(collected.count, 0)
    }

    func test_iteratorReturnsEmptyStreamWhenFetcherReturnsEmpty_random() async {
        let sut = PhotoFetcher(
            fetchAssets: { _ in [] },
            authorizationStatus: { .authorized }
        )

        var rng = SeededRandomNumberGenerator(seed: 0xDEAD_BEEF)
        let stream = await sut.iterator(order: .random, rng: &rng)
        let collected = await collect(stream)

        XCTAssertEqual(collected.count, 0)
    }

    // MARK: - Deterministic RNG (foundation for the random-mode shuffle)

    func test_seededRNGIsDeterministicForSameSeed() {
        var a = SeededRandomNumberGenerator(seed: 0x1234_5678)
        var b = SeededRandomNumberGenerator(seed: 0x1234_5678)

        let aValues = (0..<32).map { _ in a.next() }
        let bValues = (0..<32).map { _ in b.next() }

        XCTAssertEqual(aValues, bValues,
                       "Two RNGs seeded identically must emit identical sequences")
    }

    func test_seededRNGDiffersForDifferentSeeds() {
        var a = SeededRandomNumberGenerator(seed: 1)
        var b = SeededRandomNumberGenerator(seed: 2)

        let aValues = (0..<32).map { _ in a.next() }
        let bValues = (0..<32).map { _ in b.next() }

        XCTAssertNotEqual(aValues, bValues,
                          "Different seeds should produce different sequences")
    }

    func test_arrayShuffledWithSeededRNGIsStableAcrossRuns() {
        // Proves that `Array.shuffled(using:)` — the exact call PhotoFetcher
        // uses for `.random` mode — is reproducible when fed our seeded RNG.
        // This is the property the iterator relies on; once we can synth
        // PHAssets we can fold this into a real end-to-end shuffle test.
        let input = Array(0..<50)

        var rng1 = SeededRandomNumberGenerator(seed: 0xCAFE_F00D)
        let shuffled1 = input.shuffled(using: &rng1)

        var rng2 = SeededRandomNumberGenerator(seed: 0xCAFE_F00D)
        let shuffled2 = input.shuffled(using: &rng2)

        XCTAssertEqual(shuffled1, shuffled2,
                       "Same seed + same input must produce the same shuffle")
        XCTAssertNotEqual(shuffled1, input,
                          "Shuffle should actually reorder a 50-element array")
    }

    // MARK: - Skipped (require real PHAsset construction)

    func test_sourceTypeFilter_TODO() throws {
        // Filtering out `.typeCloudShared` assets is exercised in
        // PhotoFetcher's detached fetch task, but we cannot construct
        // PHAsset instances outside PhotoKit's database, so we cannot
        // assert the filter from a unit test without device library
        // access. Revisit in Phase 5 polish (TASK-???: real-asset tests).
        throw XCTSkip("Real PHAsset construction needed; see Phase 5 polish.")
    }

    func test_randomModeShufflesPHAssetsDeterministically_TODO() throws {
        // The shuffle determinism is proved indirectly by
        // `test_arrayShuffledWithSeededRNGIsStableAcrossRuns`. An
        // end-to-end version that calls `iterator(order: .random, rng:)`
        // twice with the same seed and asserts the streamed PHAsset
        // sequences are identical needs real PHAssets — deferred.
        throw XCTSkip("Real PHAsset construction needed; see Phase 5 polish.")
    }

    // MARK: - Helpers

    /// Collects an `AsyncStream` into an array. Used instead of `for await`
    /// loops to keep test bodies flat.
    private func collect<T>(_ stream: AsyncStream<T>) async -> [T] {
        var out: [T] = []
        for await element in stream {
            out.append(element)
        }
        return out
    }
}

// MARK: - Inline deterministic RNG

/// Tiny LCG used to make `.random` mode reproducible under test. Not
/// cryptographic; the only requirement is "same seed → same sequence".
/// Constants are Knuth's MMIX values.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

// MARK: - Test-local thread-safe boxes

/// `@Sendable` closure captures need thread-safe mutation. These two tiny
/// helpers replace the more verbose `NSLock`-around-a-class dance and
/// keep the test bodies readable.
private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set(_ newValue: Bool) {
        lock.lock(); defer { lock.unlock() }
        value = newValue
    }
    func get() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}

private final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T?
    func set(_ newValue: T) {
        lock.lock(); defer { lock.unlock() }
        value = newValue
    }
    func get() -> T? {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}
