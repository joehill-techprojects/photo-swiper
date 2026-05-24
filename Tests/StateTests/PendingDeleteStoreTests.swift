//
//  PendingDeleteStoreTests.swift
//  PhotoSwiperTests
//
//  Unit tests for `PendingDeleteStore`. Real `PHAsset`s cannot be
//  constructed outside PhotoKit's database, so these tests exercise only
//  the persistence path — initialization from UserDefaults, the empty
//  case, the stale-identifier case (PhotoKit silently drops unresolvable
//  IDs), `clear()`, and the stability of the on-disk key.
//
//  The full add/removeLast/remove(matching:) round-trip is covered by
//  on-device manual QA (see Phase 5 BACKLOG); we can't fake PHAssets here.
//

import XCTest
import Photos
@testable import PhotoSwiper

@MainActor
final class PendingDeleteStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PendingDeleteStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Init

    func testInit_emptyDefaults_emptyBucket() {
        let sut = PendingDeleteStore(defaults: defaults)

        XCTAssertEqual(sut.count, 0)
        XCTAssertTrue(sut.isEmpty)
    }

    func testInit_staleIdentifiers_emptyBucket() {
        // Pre-seed defaults with garbage IDs that PhotoKit cannot resolve.
        // The store should silently drop them (matching production
        // behavior when the user deletes a queued asset in Photos.app
        // while PhotoSwiper is backgrounded).
        defaults.set(
            ["nope-1", "nope-2", "nope-3"],
            forKey: PendingDeleteStore.userDefaultsKey
        )

        let sut = PendingDeleteStore(defaults: defaults)

        XCTAssertEqual(sut.count, 0)
        XCTAssertTrue(sut.isEmpty)
    }

    // MARK: - clear

    func testClear_writesEmptyArray() {
        // Pre-seed with garbage so init reads something, then clear and
        // verify the on-disk array was rewritten to [].
        defaults.set(
            ["nope-1", "nope-2"],
            forKey: PendingDeleteStore.userDefaultsKey
        )
        let sut = PendingDeleteStore(defaults: defaults)

        sut.clear()

        let stored = defaults.stringArray(forKey: PendingDeleteStore.userDefaultsKey)
        XCTAssertEqual(stored, [], "clear() must rewrite defaults to an empty array")
        XCTAssertEqual(sut.count, 0)
        XCTAssertTrue(sut.isEmpty)
    }

    func testClear_emptyBucket_idempotent() {
        let sut = PendingDeleteStore(defaults: defaults)

        sut.clear()
        sut.clear()

        let stored = defaults.stringArray(forKey: PendingDeleteStore.userDefaultsKey)
        XCTAssertEqual(stored, [], "clear() on an empty bucket must still write []")
        XCTAssertEqual(sut.count, 0)
    }

    // MARK: - Spec stability

    func testUserDefaultsKey_isStable() {
        // The key is part of the persistence contract across app
        // versions — a typo refactor would silently orphan every user's
        // pending bucket on upgrade.
        XCTAssertEqual(
            PendingDeleteStore.userDefaultsKey,
            "PhotoSwiper.PendingDelete.identifiers"
        )
    }
}
