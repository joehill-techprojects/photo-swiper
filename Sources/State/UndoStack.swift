import Foundation
import os

/// LIFO stack of undoable swipe actions.
///
/// Each entry is a closure that, when invoked, reverses the most recent swipe
/// (typically by putting the asset back at index 0 in the deck). The stack is
/// bounded — when the depth exceeds `maxSize`, the oldest entry is dropped.
///
/// Per D-017: logs at `.debug` on push and pop with the resulting count.
@MainActor
@Observable
public final class UndoStack {
    /// A reversal closure recorded by `push` and invoked by `pop`.
    public typealias Reversal = @MainActor () async -> Void

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.joehill.photoswiper", category: "UndoStack")

    @ObservationIgnored
    private let maxSize: Int

    /// The underlying stack. Observed so `isEmpty`/`count` trigger UI updates.
    private var entries: [Reversal] = []

    public init(maxSize: Int = 50) {
        precondition(maxSize > 0, "UndoStack maxSize must be > 0")
        self.maxSize = maxSize
    }

    /// True iff there is nothing to undo.
    public var isEmpty: Bool { entries.isEmpty }

    /// Number of undoable entries (capped at `maxSize`).
    public var count: Int { entries.count }

    /// Record an undoable event. `reverse` is the closure that, when invoked,
    /// restores the prior state (typically: put the asset back at index 0 in
    /// the deck). If the stack would exceed `maxSize`, the OLDEST entry is
    /// dropped (LIFO with bounded depth).
    public func push(reverse: @escaping Reversal) {
        entries.append(reverse)
        if entries.count > maxSize {
            entries.removeFirst()
        }
        logger.debug("push -> count=\(self.entries.count, privacy: .public)")
    }

    /// Pop the most-recent entry and invoke its reverse closure. No-op if empty.
    /// - Returns: `true` iff something was reversed.
    @discardableResult
    public func pop() async -> Bool {
        guard let reverse = entries.popLast() else {
            logger.debug("pop -> empty, no-op")
            return false
        }
        logger.debug("pop -> count=\(self.entries.count, privacy: .public)")
        await reverse()
        return true
    }

    /// Drop all entries. Used by Settings → "clear undo history" or on order-reload.
    public func clear() {
        entries.removeAll()
        logger.debug("clear -> count=0")
    }
}
