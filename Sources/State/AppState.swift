//
//  AppState.swift
//  PhotoSwiper
//
//  Top-level `@Observable` application state and the single source of truth
//  for the visible photo deck. Sits between `PhotoFetcher` (which produces
//  an `AsyncStream<PHAsset>`) and `CardStack` (which renders the top N cards
//  and reports swipes back).
//
//  Responsibilities:
//    - Owns `Settings` (deck order, Immich URL, age threshold).
//    - Owns `UndoStack` (LIFO of reverse closures for the undo button).
//    - Owns `PendingDeleteStore` — bucket of left-swiped assets queued for
//      batch deletion (D-024). Left swipes park here; the user commits the
//      whole bucket via the trash toolbar button.
//    - Owns the lazily-created `AsyncStream<PHAsset>.AsyncIterator` produced
//      by `PhotoFetcher`. Re-created on order changes via `reloadOrder()`.
//    - Maintains `cards: [PHAsset]` — the small ring of upcoming cards that
//      `CardStack` paints. Refilled from the iterator whenever it shrinks
//      below `refillThreshold`.
//    - Wraps deck mutations in `withAnimation` so SwiftUI's diff produces a
//      smooth slide-up of the next card when the top one swipes off.
//
//  Phase 3 scope (this file):
//    - `loadInitial()` and `reloadOrder()` drive the iterator;
//      `reloadOrder()` also clears the undo stack (its entries reference
//      assets from the previous order). The pending-delete bucket survives
//      order changes — the user expects "I queued N photos for delete;
//      switching to oldest-first shouldn't lose them".
//    - `handleSwipe(asset:direction:)` parks left-swipes in
//      `pendingDelete` (D-024 — no PhotoKit call yet), dispatches
//      `ShareAction` on up, a placeholder log on right (Phase 4 swaps in
//      `ImmichClient.upload` via TASK-046), and a skip log on down (D-022).
//      Each branch pushes a reverse closure onto `undoStack`.
//    - `commitPendingDelete()` hands the whole bucket to PhotoKit in one
//      call (one iOS confirmation for N photos). `discardPendingDelete()`
//      empties the bucket without deleting anything.
//    - `undo()` pops the most-recent reverse closure for the toolbar button.
//
//  Per `DECISIONS.md`:
//    - D-003  iOS 17+ (uses `@Observable`)
//    - D-004  SwiftUI only
//    - D-009  PhotoKit only
//    - D-017  os.Logger
//    - D-024  batched delete bucket + single iOS confirmation
//

import Foundation
import Observation
import Photos
import SwiftUI
import os

/// Top-level application state.
///
/// Single `@MainActor @Observable` root. Views observe this directly via
/// `@State` (created once at the app/root view) — no `@ObservedObject`,
/// no `EnvironmentObject`.
@MainActor
@Observable
public final class AppState {

    // MARK: - Owned models

    /// User-facing settings (deck order, Immich URL, age threshold).
    public let settings: Settings

    /// LIFO stack of reverse closures for the last N swipes. Pushed from
    /// `handleSwipe` (except on benign no-ops like delete-cancel); popped by
    /// `undo()` from the toolbar button in `ContentView`.
    public let undoStack: UndoStack

    /// Batched pending-delete bucket (D-024). Left swipes park assets here;
    /// `commitPendingDelete()` hands the whole bucket to PhotoKit in a
    /// single `performChanges` call (one iOS confirmation for N photos).
    public let pendingDelete: PendingDeleteStore

    // MARK: - Public deck state (read-only to the outside)

    /// The current visible window of cards, top first. `CardStack` consumes
    /// this directly. Mutations are always wrapped in `withAnimation` so the
    /// deck slide animates.
    public private(set) var cards: [PHAsset] = []

    /// `true` while `loadInitial()` or `reloadOrder()` is pulling the first
    /// batch from the iterator. Drives the root `ProgressView`.
    public private(set) var isLoading: Bool = false

    /// `false` once the underlying `AsyncStream` has been fully drained.
    /// Used by views (and future "all caught up" UI) to distinguish "still
    /// fetching" from "truly empty".
    public private(set) var hasMorePhotos: Bool = true

    // MARK: - Private dependencies / state

    @ObservationIgnored
    private let fetcher: PhotoFetcher

    /// Lazily created on the first `loadInitial()` call. Re-created by
    /// `reloadOrder()` when the user changes the order in `SettingsView`.
    @ObservationIgnored
    private var iterator: AsyncStream<PHAsset>.AsyncIterator?

    /// Target number of cards to keep buffered ahead of `CardStack` (which
    /// only renders the first 3). Refill kicks in below `refillThreshold`.
    @ObservationIgnored
    private let bufferSize: Int = 5

    @ObservationIgnored
    private let refillThreshold: Int = 3

    private static let log = Logger(
        subsystem: "com.joehill.photoswiper",
        category: "AppState"
    )

    // MARK: - Init

    /// Create the app state.
    ///
    /// - Parameters:
    ///   - settings: The settings model. Pass `nil` (default) to construct a
    ///     fresh `UserDefaults.standard`-backed instance inside this `@MainActor`
    ///     init — required because `Settings.init` is main-actor-isolated and
    ///     can't be called from a default-parameter expression in a non-isolated
    ///     context.
    ///   - undoStack: The undo stack. Same nil-sentinel pattern as `settings`
    ///     (BUG-008): `UndoStack.init` is `@MainActor`-isolated so we can't
    ///     name `UndoStack()` as a default-parameter expression.
    ///   - pendingDelete: The batched-delete bucket. Same nil-sentinel pattern
    ///     (BUG-008): `PendingDeleteStore.init` is `@MainActor`-isolated.
    ///   - fetcher: The `PhotoFetcher` used to produce the asset stream.
    ///     Injectable for tests; defaults to the production fetcher.
    public init(
        settings: Settings? = nil,
        undoStack: UndoStack? = nil,
        pendingDelete: PendingDeleteStore? = nil,
        fetcher: PhotoFetcher = PhotoFetcher()
    ) {
        self.settings = settings ?? Settings()
        self.undoStack = undoStack ?? UndoStack()
        self.pendingDelete = pendingDelete ?? PendingDeleteStore()
        self.fetcher = fetcher
    }

    // MARK: - Lifecycle

    /// Create the iterator (if needed) and fill the initial buffer.
    ///
    /// On first ever launch, triggers the iOS photo-library permission
    /// prompt if status is `.notDetermined` — without this, the app would
    /// silently render an empty deck because `PhotoFetcher` returns an
    /// empty stream for unauthorised callers (and never prompts on its
    /// own). The proper onboarding UI is TASK-062 in Phase 5; this is
    /// the minimum viable hook.
    ///
    /// Idempotent: calling more than once with an already-populated deck is
    /// a no-op (logs at `.debug`). Call from the root view's `.task`.
    public func loadInitial() async {
        guard iterator == nil else {
            Self.log.debug("loadInitial called but iterator already exists; skipping")
            return
        }

        isLoading = true
        defer { isLoading = false }

        // First-launch permission prompt. `requestAuthorization` is a no-op
        // if status is anything other than `.notDetermined`.
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .notDetermined {
            let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            Self.log.info(
                "Photo authorization requested, result=\(granted.rawValue, privacy: .public)"
            )
        }

        Self.log.info(
            "loadInitial starting (order=\(self.settings.order.rawValue, privacy: .public))"
        )

        let stream = await fetcher.iterator(order: settings.order)
        iterator = stream.makeAsyncIterator()
        hasMorePhotos = true

        await refillBuffer()

        Self.log.info(
            "loadInitial done; cards=\(self.cards.count, privacy: .public), hasMore=\(self.hasMorePhotos, privacy: .public)"
        )
    }

    /// Re-create the iterator with the current `Settings.order` and reset
    /// the visible deck. Call after the user changes the order in
    /// `SettingsView` and dismisses the sheet.
    public func reloadOrder() async {
        Self.log.info(
            "reloadOrder (order=\(self.settings.order.rawValue, privacy: .public))"
        )

        isLoading = true
        defer { isLoading = false }

        withAnimation { cards.removeAll() }
        // A deck reset invalidates pending undos: the old asset references
        // may not appear in the new order, and "undo" across order changes
        // has no meaningful semantic.
        undoStack.clear()
        iterator = nil
        hasMorePhotos = true

        let stream = await fetcher.iterator(order: settings.order)
        iterator = stream.makeAsyncIterator()
        await refillBuffer()
    }

    // MARK: - Swipe handling

    /// React to a swipe committed on the top card.
    ///
    /// Removes the asset from `cards` immediately (so the UI updates without
    /// waiting on the async action), then dispatches the matching action
    /// per direction:
    ///   - `.left`  → park in `pendingDelete` bucket (D-024); no PhotoKit
    ///                call here — the user batch-commits later via the trash
    ///                toolbar button
    ///   - `.right` → Phase 3 placeholder log; Phase 4 (TASK-046) swaps in
    ///                `ImmichClient.upload`
    ///   - `.up`    → `ShareAction.share` (iOS share sheet)
    ///   - `.down`  → skip (D-022, no side effect)
    ///
    /// Every direction pushes a reverse closure onto `undoStack` so the
    /// toolbar undo button restores the card. The `.left` reverse closure
    /// also removes the asset from `pendingDelete` so undo is real — the
    /// photo never left the user's library.
    public func handleSwipe(asset: PHAsset, direction: Direction) async {
        Self.log.info(
            "handleSwipe direction=\(String(describing: direction), privacy: .public) asset=\(asset.localIdentifier, privacy: .public)"
        )

        // TODO(Phase 4 / TASK-047): age check using `asset.creationDate` against
        //   `Date().addingTimeInterval(-Double(settings.oldPhotoThresholdDays) * 86_400)`
        //   to decide whether a right-swipe also triggers a device delete.

        // Remove from the deck FIRST so the UI updates immediately. The action
        // dispatches afterwards — for .left it may show an iOS confirmation
        // sheet; for .up it presents a share sheet; either way the card is
        // already gone from view.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            cards.removeAll { $0.localIdentifier == asset.localIdentifier }
        }

        switch direction {
        case .left:
            // D-024: park in the pending-delete bucket. PhotoKit is NOT
            // called here — `commitPendingDelete()` handles the whole batch
            // in one call with a single iOS confirmation sheet.
            pendingDelete.add(asset)
            undoStack.push { [weak self] in
                guard let self else { return }
                self.pendingDelete.remove(matching: asset.localIdentifier)
                await self.restore(asset)
            }

        case .right:
            // D-023: Phase 3 placeholder. Phase 4 (TASK-046) swaps in ImmichClient.upload.
            Self.log.info("right-swipe placeholder (would upload to Immich) asset=\(asset.localIdentifier, privacy: .public)")
            undoStack.push { [weak self] in
                await self?.restore(asset)
            }

        case .up:
            do {
                try await ShareAction.share(asset)
                undoStack.push { [weak self] in
                    await self?.restore(asset)
                }
            } catch {
                Self.log.error("share failed: \(String(describing: error), privacy: .public)")
                // Sheet didn't even appear; restore the card.
                await restore(asset)
            }

        case .down:
            // D-022: skip. No side effect; just log and let the card leave the deck.
            Self.log.info("down-swipe skip asset=\(asset.localIdentifier, privacy: .public)")
            undoStack.push { [weak self] in
                await self?.restore(asset)
            }
        }

        if cards.count < refillThreshold {
            await refillBuffer()
        }
    }

    /// Pop the most-recent undo entry and run its reverse closure.
    /// Convenience for the toolbar undo button in `ContentView`.
    public func undo() async {
        await undoStack.pop()
    }

    // MARK: - Batched delete (D-024)

    /// Commit all pending-delete assets in a single PhotoKit batch.
    /// iOS shows ONE confirmation sheet for the whole batch. On success,
    /// the bucket is cleared. On user-cancel, the bucket is preserved
    /// so the user can retry. On other failure, the bucket is preserved
    /// and the error is logged.
    ///
    /// Also clears the undo stack on success — those reverse closures
    /// reference assets now in Recently Deleted; restoring their cards
    /// would show broken thumbnails.
    public func commitPendingDelete() async {
        let snapshot = pendingDelete.assets
        guard !snapshot.isEmpty else {
            Self.log.debug("commitPendingDelete called with empty bucket; no-op")
            return
        }

        Self.log.info("commitPendingDelete count=\(snapshot.count, privacy: .public)")
        do {
            try await DeleteAction.delete(snapshot)
            pendingDelete.clear()
            undoStack.clear()
            Self.log.info("commitPendingDelete success")
        } catch DeleteError.userCancelled {
            Self.log.info("commitPendingDelete user-cancelled; bucket preserved")
        } catch {
            Self.log.error("commitPendingDelete failed: \(String(describing: error), privacy: .public); bucket preserved")
        }
    }

    /// Discard the pending-delete bucket without deleting any photos.
    /// The photos stay in the user's library. Also drops any UndoStack
    /// entries that referenced these assets — actually, simplest: drop
    /// the entire UndoStack since the cards being undone may already be
    /// off-deck.
    ///
    /// (Edge case: a user with mixed swipes — left, right, up — taps
    /// Discard. We clear the bucket and the undo stack. The right and
    /// up swipes are "stuck off-deck" but those actions either did
    /// nothing real (right placeholder) or already happened (up share
    /// sheet shown). Acceptable.)
    public func discardPendingDelete() {
        Self.log.info("discardPendingDelete count=\(self.pendingDelete.count, privacy: .public)")
        pendingDelete.clear()
        undoStack.clear()
    }

    // MARK: - Private helpers

    /// Restore a previously-swiped asset to the front of the deck.
    /// Called from undo closures and from .left failure paths.
    private func restore(_ asset: PHAsset) async {
        // Guard against duplicate restore (e.g. delete failure + undo)
        guard !cards.contains(where: { $0.localIdentifier == asset.localIdentifier }) else {
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            cards.insert(asset, at: 0)
        }
        Self.log.debug("restore asset=\(asset.localIdentifier, privacy: .public)")
    }

    /// Pull from the iterator until `cards.count >= bufferSize` or the
    /// stream is exhausted. Updates `hasMorePhotos` when the stream ends.
    private func refillBuffer() async {
        guard var it = iterator else { return }
        defer { iterator = it }

        var added: [PHAsset] = []
        while cards.count + added.count < bufferSize {
            if let next = await it.next() {
                added.append(next)
            } else {
                hasMorePhotos = false
                break
            }
        }

        guard !added.isEmpty else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            cards.append(contentsOf: added)
        }

        Self.log.debug(
            "refillBuffer added=\(added.count, privacy: .public), total=\(self.cards.count, privacy: .public)"
        )
    }
}

