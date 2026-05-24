//
//  UndoStackTests.swift
//  PhotoSwiperTests
//
//  Unit tests for `UndoStack` — the LIFO bounded stack of swipe-reversal
//  closures. Covers:
//    - Empty stack: count/isEmpty and a safe no-op pop.
//    - Push then pop: the reverse closure actually runs.
//    - LIFO ordering across multiple pushes.
//    - Bounded eviction: when maxSize is exceeded, oldest entries are
//      dropped and never executed.
//    - clear() drops everything; subsequent push works normally.
//
//  Note on `precondition(maxSize > 0)`: XCTest can't trap preconditions
//  without a custom death-test harness, so we don't exercise it here.
//  The precondition is documentation + crash-on-misuse, and the test for
//  it would not pay for itself.
//

import XCTest
@testable import PhotoSwiper

@MainActor
final class UndoStackTests: XCTestCase {

    // MARK: - Empty stack

    func testEmptyStackInitialState() async throws {
        let sut = UndoStack()
        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.count, 0)
    }

    func testPopOnEmptyStackReturnsFalse() async throws {
        let sut = UndoStack()
        let popped = await sut.pop()
        XCTAssertFalse(popped, "Pop on empty stack must return false")
        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.count, 0)
    }

    // MARK: - Push then pop

    func testPushThenPopInvokesReversal() async throws {
        let sut = UndoStack()
        let counter = Counter()

        sut.push { counter.value += 1 }
        XCTAssertFalse(sut.isEmpty)
        XCTAssertEqual(sut.count, 1)

        let popped = await sut.pop()

        XCTAssertTrue(popped)
        XCTAssertEqual(counter.value, 1, "Reversal closure must have run exactly once")
        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.count, 0)
    }

    // MARK: - LIFO ordering

    func testPopOrderIsLIFO() async throws {
        let sut = UndoStack()
        let log = Log()

        sut.push { log.append(1) }
        sut.push { log.append(2) }
        sut.push { log.append(3) }
        XCTAssertEqual(sut.count, 3)

        _ = await sut.pop()
        _ = await sut.pop()
        _ = await sut.pop()

        XCTAssertEqual(log.entries, [3, 2, 1], "Pops must run reversals in reverse push order")
        XCTAssertTrue(sut.isEmpty)
    }

    // MARK: - Bounded eviction

    func testBoundedEvictionDropsOldestEntries() async throws {
        let sut = UndoStack(maxSize: 2)
        let log = LetterLog()

        sut.push { log.append("A") }
        XCTAssertEqual(sut.count, 1)

        sut.push { log.append("B") }
        XCTAssertEqual(sut.count, 2)

        // Pushing C should evict A (oldest).
        sut.push { log.append("C") }
        XCTAssertEqual(sut.count, 2, "Count must remain bounded at maxSize")

        // Pushing D should evict B (now oldest).
        sut.push { log.append("D") }
        XCTAssertEqual(sut.count, 2, "Count must remain bounded at maxSize")

        // Pop all — only the two most-recent (D, C) should run, in LIFO order.
        _ = await sut.pop()
        _ = await sut.pop()
        let extra = await sut.pop()

        XCTAssertFalse(extra, "Stack must be empty after popping all retained entries")
        XCTAssertEqual(log.entries, ["D", "C"],
                       "Evicted entries (A, B) must never run; survivors pop LIFO")
        XCTAssertTrue(sut.isEmpty)
    }

    // MARK: - clear()

    func testClearEmptiesStack() async throws {
        let sut = UndoStack()
        let counter = Counter()

        sut.push { counter.value += 1 }
        sut.push { counter.value += 1 }
        sut.push { counter.value += 1 }
        XCTAssertEqual(sut.count, 3)

        sut.clear()

        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.count, 0)

        let popped = await sut.pop()
        XCTAssertFalse(popped)
        XCTAssertEqual(counter.value, 0, "Cleared closures must not run")
    }

    func testPushAfterClearWorksNormally() async throws {
        // Documents that clear() doesn't leave the stack in a broken state —
        // a subsequent push must transition isEmpty back to false and pop
        // must execute the new closure. @Observable handles invalidation
        // automatically; this test pins the behavioral contract.
        let sut = UndoStack()
        let counter = Counter()

        sut.push { counter.value += 99 }
        sut.clear()
        XCTAssertTrue(sut.isEmpty)

        sut.push { counter.value += 1 }
        XCTAssertFalse(sut.isEmpty)
        XCTAssertEqual(sut.count, 1)

        let popped = await sut.pop()
        XCTAssertTrue(popped)
        XCTAssertEqual(counter.value, 1, "Only the post-clear closure should have run")
    }
}

// MARK: - Test helpers

/// Shared mutable counter for closure-side-effect assertions. `@MainActor`
/// matches `UndoStack`'s isolation so closures can mutate without ceremony.
@MainActor
private final class Counter {
    var value: Int = 0
}

/// Shared ordered log of integer identifiers — used to assert LIFO order.
@MainActor
private final class Log {
    var entries: [Int] = []
    func append(_ id: Int) { entries.append(id) }
}

/// Shared ordered log of string identifiers — used in the eviction test
/// where letters read more clearly than integers.
@MainActor
private final class LetterLog {
    var entries: [String] = []
    func append(_ letter: String) { entries.append(letter) }
}
