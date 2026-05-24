//
//  SwipeCard.swift
//  PhotoSwiper
//
//  A single Tinder-style card that displays one photo and converts finger
//  drags into discrete swipe actions: left (delete), right (upload), up
//  (share). The card resolves its image lazily from a `PHAsset` so we never
//  hold UIImage bytes in long-lived state — important when the user blasts
//  through hundreds of photos in a session.
//
//  Drag mechanics:
//    - DragGesture tracks translation; a release past ~120pt commits.
//    - On commit, the card animates off-screen in the chosen direction
//      and fires the callback. Below threshold it springs back to center.
//    - A subtle color/icon overlay scales with drag distance so the user
//      sees which action is about to fire before they release.
//
//  Owned by CardStack (TASK-025); consumed via AppState (TASK-028).
//

import Photos
import SwiftUI
import UIKit
import os

/// The three swipe outcomes the card can produce.
///
/// Used by `SwipeCard`, `CardStack`, and `AppState` to dispatch the
/// matching action (delete / upload / share).
public enum Direction {
    /// Swipe left — delete from the photo library.
    case left
    /// Swipe right — upload to Immich.
    case right
    /// Swipe up — share to the other household member via Messages.
    case up
}

/// A draggable photo card. Renders a `PHAsset` and reports the user's
/// swipe direction to the parent via `onSwipe`.
///
/// The view is a leaf — plain `@State` is sufficient, no `@Observable`.
/// Image bytes are loaded in `.task` and released on disappear so a long
/// session doesn't accumulate memory.
public struct SwipeCard: View {

    // MARK: - Public API

    /// The photo to display.
    public let asset: PHAsset

    /// Fired once when the user's drag crosses the commit threshold and
    /// the card has animated off-screen.
    public let onSwipe: (Direction) -> Void

    /// Construct a card for the given asset.
    /// - Parameters:
    ///   - asset: The `PHAsset` to render. Image is fetched lazily.
    ///   - onSwipe: Callback fired once per committed swipe.
    public init(asset: PHAsset, onSwipe: @escaping (Direction) -> Void) {
        self.asset = asset
        self.onSwipe = onSwipe
    }

    // MARK: - Internal state

    @State private var image: UIImage?
    @State private var dragOffset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero
    @State private var isGone: Bool = false
    @State private var imageRequestID: PHImageRequestID?

    // MARK: - Constants

    /// Distance (in points) a drag must reach to commit a swipe.
    private static let commitThreshold: CGFloat = 120

    /// Distance the card travels off-screen when a swipe commits.
    private static let flyAwayDistance: CGFloat = 1000

    /// Logger per DECISIONS D-017.
    private static let log = Logger(
        subsystem: "com.joehill.photoswiper",
        category: "SwipeCard"
    )

    // MARK: - View

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                cardBackground
                imageLayer(in: geo.size)
                overlayHints
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
            .offset(x: currentOffset.width, y: currentOffset.height)
            .rotationEffect(.degrees(rotationDegrees), anchor: .bottom)
            .gesture(dragGesture)
            .task {
                await loadImage(targetSize: geo.size)
            }
            .onDisappear {
                cancelImageRequest()
            }
        }
    }

    // MARK: - Subviews

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(uiColor: .secondarySystemBackground))
    }

    @ViewBuilder
    private func imageLayer(in size: CGSize) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
        } else {
            ProgressView()
        }
    }

    /// Colored tint + SF Symbol that grows as the drag crosses
    /// toward a commit. Subtle: max opacity ~0.6 at the commit threshold.
    private var overlayHints: some View {
        ZStack {
            hintLayer(
                color: .red,
                systemImage: "trash.fill",
                opacity: leftHintOpacity,
                alignment: .leading
            )
            hintLayer(
                color: .green,
                systemImage: "icloud.and.arrow.up.fill",
                opacity: rightHintOpacity,
                alignment: .trailing
            )
            hintLayer(
                color: .blue,
                systemImage: "paperplane.fill",
                opacity: upHintOpacity,
                alignment: .top
            )
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func hintLayer(
        color: Color,
        systemImage: String,
        opacity: Double,
        alignment: Alignment
    ) -> some View {
        ZStack(alignment: alignment) {
            color.opacity(opacity * 0.35)
            Image(systemName: systemImage)
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.white)
                .opacity(opacity)
                .padding(32)
        }
    }

    // MARK: - Drag gesture

    /// Supports interruption: `committedOffset` is the resting position
    /// (which can be mid-flight if the user grabs again before the
    /// spring-back finishes), and `dragOffset` is the live delta during
    /// the current drag.
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                // Use predictedEndTranslation so fast flicks with small
                // physical distance still commit (DragGesture extrapolates
                // from velocity). A slow drag still has to physically cross
                // the threshold because predictedEndTranslation ≈ translation
                // at low velocity.
                let predicted = CGSize(
                    width: committedOffset.width + value.predictedEndTranslation.width,
                    height: committedOffset.height + value.predictedEndTranslation.height
                )
                if let direction = directionForCommit(translation: predicted) {
                    commit(direction: direction)
                } else {
                    springBack()
                }
            }
    }

    /// Position during a live drag = committed rest position + current drag delta.
    /// When `isGone` we've fully flown off and the offset stays parked there
    /// so the view doesn't pop back into view during the unmount animation.
    private var currentOffset: CGSize {
        if isGone { return committedOffset }
        return CGSize(
            width: committedOffset.width + dragOffset.width,
            height: committedOffset.height + dragOffset.height
        )
    }

    /// Subtle Tinder-style tilt: rotate up to ~12deg based on horizontal travel.
    private var rotationDegrees: Double {
        let max: CGFloat = 12
        let normalized = (currentOffset.width / 300).clamped(to: -1...1)
        return Double(normalized * max)
    }

    // MARK: - Hint opacity

    private var leftHintOpacity: Double {
        opacityFor(distance: -currentOffset.width)
    }

    private var rightHintOpacity: Double {
        opacityFor(distance: currentOffset.width)
    }

    private var upHintOpacity: Double {
        // Only show the up hint if the drag is dominantly vertical; otherwise
        // a diagonal left-down drag would also light up the share icon.
        guard currentOffset.height < 0,
              abs(currentOffset.height) > abs(currentOffset.width) else {
            return 0
        }
        return opacityFor(distance: -currentOffset.height)
    }

    private func opacityFor(distance: CGFloat) -> Double {
        guard distance > 0 else { return 0 }
        let pct = min(distance / Self.commitThreshold, 1.0)
        return Double(pct) * 0.6
    }

    // MARK: - Commit / cancel

    /// Returns the direction to commit, or nil if the drag should spring back.
    /// Picks the axis with the larger absolute translation, then compares to threshold.
    private func directionForCommit(translation: CGSize) -> Direction? {
        let horizontal = abs(translation.width)
        let vertical = abs(translation.height)
        if horizontal > vertical {
            guard horizontal >= Self.commitThreshold else { return nil }
            return translation.width < 0 ? .left : .right
        } else {
            guard vertical >= Self.commitThreshold else { return nil }
            // Only "up" is a swipe — a downward fling is treated as cancel.
            return translation.height < 0 ? .up : nil
        }
    }

    private func commit(direction: Direction) {
        Self.log.debug("Committing swipe \(String(describing: direction), privacy: .public) for asset \(self.asset.localIdentifier, privacy: .public)")
        let target: CGSize
        switch direction {
        case .left:
            target = CGSize(width: -Self.flyAwayDistance, height: 0)
        case .right:
            target = CGSize(width: Self.flyAwayDistance, height: 0)
        case .up:
            target = CGSize(width: 0, height: -Self.flyAwayDistance)
        }

        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85)) {
            committedOffset = target
            dragOffset = .zero
            isGone = true
        }

        // Fire callback after the animation reads its final value. We don't
        // need to wait for it to literally finish on screen — CardStack will
        // immediately pop this card from the queue.
        onSwipe(direction)
    }

    private func springBack() {
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = .zero
            committedOffset = .zero
        }
    }

    // MARK: - Image loading

    /// Request the asset's image at roughly the card's display size using
    /// opportunistic delivery (low-res placeholder, then high-res replacement).
    ///
    /// PHImageManager calls its result handler multiple times under
    /// `.opportunistic` mode (degraded preview first, then final). We bridge
    /// that to an `AsyncStream` so each delivery is delivered to the view in
    /// order. The continuation's `onTermination` cancels the PhotoKit request
    /// when the stream is torn down (e.g. SwiftUI cancels the `.task`).
    ///
    /// The `imageRequestID` is assigned synchronously immediately after
    /// `requestImage` returns, so `onDisappear` can cancel even if PhotoKit
    /// hasn't called back yet.
    @MainActor
    private func loadImage(targetSize: CGSize) async {
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(
            width: targetSize.width * scale,
            height: targetSize.height * scale
        )

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        let manager = PHCachingImageManager.default()
        let assetID = asset.localIdentifier

        let (stream, continuation) = AsyncStream<UIImage>.makeStream()

        let id = manager.requestImage(
            for: asset,
            targetSize: pixelSize,
            contentMode: .aspectFit,
            options: options
        ) { result, info in
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            let hasError = info?[PHImageErrorKey] != nil

            if let result {
                continuation.yield(result)
            }
            if !degraded || cancelled || hasError {
                if hasError {
                    Self.log.error("Image load failed for asset \(assetID, privacy: .public)")
                }
                continuation.finish()
            }
        }

        // Synchronous assignment — visible to onDisappear immediately, even
        // if PhotoKit hasn't called the result handler yet. (If the asset is
        // cached, the handler may have already run synchronously by this
        // line, but that's fine: id is still the right handle.)
        self.imageRequestID = id

        continuation.onTermination = { _ in
            manager.cancelImageRequest(id)
        }

        for await img in stream {
            self.image = img
        }
    }

    @MainActor
    private func cancelImageRequest() {
        if let id = imageRequestID {
            PHCachingImageManager.default().cancelImageRequest(id)
            imageRequestID = nil
        }
    }
}

// MARK: - Small helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
