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
//    - Owns the lazily-created `AsyncStream<PHAsset>.AsyncIterator` produced
//      by `PhotoFetcher`. Re-created on order changes via `reloadOrder()`.
//    - Maintains `cards: [PHAsset]` — the small ring of upcoming cards that
//      `CardStack` paints. Refilled from the iterator whenever it shrinks
//      below `refillThreshold`.
//    - Wraps deck mutations in `withAnimation` so SwiftUI's diff produces a
//      smooth slide-up of the next card when the top one swipes off.
//
//  Phase 2 scope (this file):
//    - `loadInitial()` and `reloadOrder()` drive the iterator.
//    - `handleSwipe(asset:direction:)` removes the asset and refills; it
//      logs the direction but does NOT yet dispatch real actions. Phase 3
//      (TASKs 030-035) wires `DeleteAction`, `ShareAction`, and
//      `ImmichClient.upload`. Phase 3 also introduces `UndoStack`.
//
//  Per `DECISIONS.md`:
//    - D-003  iOS 17+ (uses `@Observable`)
//    - D-004  SwiftUI only
//    - D-009  PhotoKit only
//    - D-017  os.Logger
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

    // TODO(Phase 3 / TASK-032): `public let undoStack: UndoStack`.

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
    ///   - fetcher: The `PhotoFetcher` used to produce the asset stream.
    ///     Injectable for tests; defaults to the production fetcher.
    public init(
        settings: Settings? = nil,
        fetcher: PhotoFetcher = PhotoFetcher()
    ) {
        self.settings = settings ?? Settings()
        self.fetcher = fetcher
    }

    // MARK: - Lifecycle

    /// Create the iterator (if needed) and fill the initial buffer.
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
        iterator = nil
        hasMorePhotos = true

        let stream = await fetcher.iterator(order: settings.order)
        iterator = stream.makeAsyncIterator()
        await refillBuffer()
    }

    // MARK: - Swipe handling

    /// React to a swipe committed on the top card.
    ///
    /// Phase 2 behaviour: remove the asset from `cards` (wrapped in
    /// `withAnimation` so the deck slides), then pull the next asset from
    /// the iterator if the buffer dropped below the refill threshold. The
    /// direction is logged but no real action is dispatched yet.
    ///
    /// Phase 3 (TASKs 030-035) replaces the TODO below with a real switch
    /// over `direction` that calls `DeleteAction` / `ShareAction` /
    /// `ImmichClient.upload`, pushes a reverse closure onto `UndoStack`,
    /// and honours the >365d age threshold (DECISIONS D-020).
    public func handleSwipe(asset: PHAsset, direction: Direction) async {
        Self.log.info(
            "handleSwipe direction=\(String(describing: direction), privacy: .public) asset=\(asset.localIdentifier, privacy: .public)"
        )

        // TODO(Phase 3): dispatch action by direction.
        //   .left  -> DeleteAction.delete(asset)
        //   .right -> ImmichClient.upload(asset); if older than
        //             settings.oldPhotoThresholdDays days, also delete.
        //   .up    -> ShareAction.share(asset)
        // Each branch pushes a reverse closure onto UndoStack.

        // TODO(Phase 4): age check using `asset.creationDate` against
        //   `Date().addingTimeInterval(-Double(settings.oldPhotoThresholdDays) * 86_400)`
        //   to decide whether a right-swipe also triggers a device delete.

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            cards.removeAll { $0.localIdentifier == asset.localIdentifier }
        }

        if cards.count < refillThreshold {
            await refillBuffer()
        }
    }

    // MARK: - Private helpers

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

