//
//  CardStack.swift
//  PhotoSwiper
//
//  A Tinder-style stack of `SwipeCard`s. Renders the top 3 cards from a
//  caller-owned queue, offset and scaled behind one another so the user
//  perceives depth. Only the top card is interactive; cards behind it are
//  hit-test-disabled so a stray drag can't grab them through the top card.
//
//  Ownership / responsibilities:
//    - CardStack is a *pure presentation* layer. It does NOT own the queue,
//      pull from the asset iterator, or decide what "next" means. That's
//      `AppState`'s job (TASK-028).
//    - The parent passes in the current visible window (top card first) as
//      `[PHAsset]` and an `onSwipe` callback. When the top card commits a
//      swipe, CardStack forwards the `(PHAsset, Direction)` upward; the
//      parent is responsible for popping the swiped asset off its queue
//      (ideally inside `withAnimation { ... }` so the slide-up of the new
//      top card animates smoothly via SwiftUI's diffing).
//
//  Diffing:
//    The `ForEach` is keyed on `asset.localIdentifier`. That stable identity
//    is what lets SwiftUI animate inserts (a new card appearing from the
//    back of the stack) and removals (the top card flying off) without
//    re-mounting cards that didn't change position.
//
//  Owned by AppState (TASK-028).
//

import Photos
import SwiftUI
import os

/// A depth-stacked deck of `SwipeCard`s.
///
/// Renders up to the first 3 elements of `cards` (top-first). The top card
/// is fully interactive; cards behind it are visually inset (offset + scale)
/// and have hit-testing disabled.
///
/// CardStack is intentionally stateless about queue management — the parent
/// owns `cards` and pops the swiped asset in response to `onSwipe`.
public struct CardStack: View {

    // MARK: - Public API

    /// The current visible window of assets, top card first.
    ///
    /// Pass the full upcoming queue or just the first few — only the first
    /// 3 are rendered. The parent is responsible for refilling this array
    /// from `AppState`'s iterator as the user swipes.
    public let cards: [PHAsset]

    /// Fired when the top card commits a swipe. The parent should pop the
    /// reported asset from its queue (preferably inside `withAnimation`).
    public let onSwipe: (PHAsset, Direction) -> Void

    /// Construct a CardStack.
    /// - Parameters:
    ///   - cards: Visible window of assets, top first. Empty array renders
    ///     a placeholder.
    ///   - onSwipe: Called once per committed swipe on the top card.
    public init(
        cards: [PHAsset],
        onSwipe: @escaping (PHAsset, Direction) -> Void
    ) {
        self.cards = cards
        self.onSwipe = onSwipe
    }

    // MARK: - Constants

    /// Maximum number of cards drawn at once.
    private static let visibleCardCount = 3

    /// Vertical offset (pt) applied to each card behind the top one.
    /// Cumulative: card index 1 sits 8pt down, index 2 sits 16pt down.
    private static let depthOffsetStep: CGFloat = 8

    /// Scale factor per depth step. Index 1 → 0.95, index 2 → 0.90.
    private static let depthScaleStep: CGFloat = 0.05

    /// Logger per DECISIONS D-017.
    private static let log = Logger(
        subsystem: "com.joehill.photoswiper",
        category: "CardStack"
    )

    // MARK: - View

    public var body: some View {
        ZStack {
            if cards.isEmpty {
                emptyState
            } else {
                stackedCards
            }
        }
    }

    // MARK: - Subviews

    /// Render up to `visibleCardCount` cards, back-to-front, so the top card
    /// (index 0) is drawn last and sits on top naturally.
    private var stackedCards: some View {
        let visible = Array(cards.prefix(Self.visibleCardCount).enumerated())

        // Reverse so back cards are added to the ZStack first; SwiftUI then
        // paints the top card (index 0) last.
        return ZStack {
            ForEach(visible.reversed(), id: \.element.localIdentifier) { pair in
                let (depth, asset) = pair
                cardView(for: asset, depth: depth)
            }
        }
    }

    @ViewBuilder
    private func cardView(for asset: PHAsset, depth: Int) -> some View {
        let isTop = depth == 0
        let offsetY = CGFloat(depth) * Self.depthOffsetStep
        let scale = 1.0 - (CGFloat(depth) * Self.depthScaleStep)

        SwipeCard(asset: asset) { direction in
            // Defensive: only the top card should ever be interactive, but
            // log+forward only when this really was the top card.
            guard isTop else { return }
            Self.log.debug(
                "Forwarding swipe \(String(describing: direction), privacy: .public) for asset \(asset.localIdentifier, privacy: .public)"
            )
            onSwipe(asset, direction)
        }
        .scaleEffect(scale)
        .offset(y: offsetY)
        .allowsHitTesting(isTop)
        // zIndex makes the painter's-order intent explicit and protects
        // against SwiftUI reordering during animated inserts/removals
        // (which would otherwise briefly paint a back card on top of the
        // outgoing top card and cause a visible pop).
        .zIndex(Double(Self.visibleCardCount - depth))
    }

    /// Minimal empty-state placeholder. TASK-063 will replace this with the
    /// "all caught up" celebration + refresh affordance.
    private var emptyState: some View {
        Text("No more photos")
            .foregroundStyle(.secondary)
    }
}
