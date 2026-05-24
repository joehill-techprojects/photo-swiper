//
//  PhotoFetcher.swift
//  PhotoSwiper
//
//  A thin, testable wrapper around PhotoKit that produces an `AsyncStream`
//  of `PHAsset`s in either chronological (oldest-first) or random order.
//
//  Design notes:
//  - PhotoKit's `PHAsset.fetchAssets(with:options:)` is a synchronous call
//    that hits a system database. We isolate it behind an injectable
//    closure (`AssetFetcher`) so unit tests in TASK-023 can supply a fake
//    asset list without touching the photo library.
//  - The public `iterator(order:)` boundary is `@MainActor`-safe to call
//    from SwiftUI views, but the actual fetch hops off the main actor via
//    `Task.detached` so we never block UI on the PhotoKit call.
//  - Random mode uses an injectable `RandomNumberGenerator` so tests can
//    pass a `SeededRandomNumberGenerator` for deterministic ordering.
//  - Cloud-shared assets are filtered out: we cannot reliably delete those
//    on the user's behalf, so they have no place in a curation deck.
//  - Permission handling is intentionally minimal here: if the user has
//    not authorised photo access, we log at .info and return an empty
//    stream. The first-launch permission UX lives in `PermissionView`.
//
//  Per `DECISIONS.md`:
//    - D-009  PhotoKit only (no third-party photo libs)
//    - D-017  os.Logger for structured logging
//

import Foundation
import Photos
import os

/// Stateless service that produces an ordered stream of `PHAsset`s from
/// the user's photo library, filtered to images we are allowed to mutate.
///
/// `PhotoFetcher` is intentionally a value type with no stored mutable
/// state — every call to `iterator(order:)` performs a fresh fetch.
public struct PhotoFetcher {

    // MARK: - Nested types

    /// Function that turns a configured `PHFetchOptions` into a concrete
    /// array of `PHAsset`s. Injection point for tests.
    public typealias AssetFetcher = @Sendable (PHFetchOptions) -> [PHAsset]

    // MARK: - Stored properties

    private let fetchAssets: AssetFetcher
    private let authorizationStatus: @Sendable () -> PHAuthorizationStatus

    private static let log = Logger(
        subsystem: "com.joehill.photoswiper",
        category: "PhotoFetcher"
    )

    // MARK: - Init

    /// Creates a `PhotoFetcher`.
    ///
    /// - Parameters:
    ///   - fetchAssets: Closure that runs the actual PhotoKit fetch.
    ///     Defaults to `PhotoFetcher.defaultFetch`, which calls
    ///     `PHAsset.fetchAssets(with:options:)`. Tests override this.
    ///   - authorizationStatus: Closure returning the current PhotoKit
    ///     authorization status. Defaults to
    ///     `PHPhotoLibrary.authorizationStatus(for: .readWrite)`. Tests
    ///     override this to simulate denied/limited access.
    public init(
        fetchAssets: @escaping AssetFetcher = PhotoFetcher.defaultFetch,
        authorizationStatus: @escaping @Sendable () -> PHAuthorizationStatus =
            { PHPhotoLibrary.authorizationStatus(for: .readWrite) }
    ) {
        self.fetchAssets = fetchAssets
        self.authorizationStatus = authorizationStatus
    }

    // MARK: - Public API

    /// Produces an `AsyncStream` of `PHAsset`s in the requested order,
    /// using the system random number generator for `.random` mode.
    ///
    /// Safe to call from `@MainActor` contexts (e.g. SwiftUI views);
    /// the underlying fetch runs off the main actor.
    @MainActor
    public func iterator(order: Settings.Order) async -> AsyncStream<PHAsset> {
        var rng = SystemRandomNumberGenerator()
        return await iterator(order: order, rng: &rng)
    }

    /// Produces an `AsyncStream` of `PHAsset`s in the requested order,
    /// using a caller-supplied `RandomNumberGenerator`.
    ///
    /// The `rng` parameter is consumed up-front (during the shuffle) so
    /// the resulting stream does not capture the `inout` binding.
    ///
    /// Safe to call from `@MainActor` contexts; the underlying fetch
    /// runs off the main actor.
    @MainActor
    public func iterator<G: RandomNumberGenerator>(
        order: Settings.Order,
        rng: inout G
    ) async -> AsyncStream<PHAsset> {
        // Bail out early if we don't have read access. Don't prompt,
        // don't crash — that's `PermissionView`'s job.
        let status = authorizationStatus()
        guard status == .authorized || status == .limited else {
            Self.log.info(
                "Photo authorization not granted (status=\(status.rawValue, privacy: .public)); returning empty stream"
            )
            return AsyncStream { $0.finish() }
        }

        // Hop off the main actor for the (potentially slow) PhotoKit
        // fetch. We sort-by-creationDate at the PhotoKit level for
        // chronological mode so the database does the work.
        let fetchAssets = self.fetchAssets
        let assets: [PHAsset] = await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: true)
            ]
            let raw = fetchAssets(options)
            // Drop cloud-shared assets — those live in someone else's
            // shared album and we shouldn't be deleting them. `sourceType`
            // is a `PHAssetSourceType` OptionSet, so use `contains`.
            return raw.filter { !$0.sourceType.contains(.typeCloudShared) }
        }.value

        // Apply order. Chronological is already sorted by the fetch;
        // random shuffles in-memory using the caller's RNG.
        let ordered: [PHAsset]
        switch order {
        case .oldestFirst:
            ordered = assets
        case .random:
            ordered = assets.shuffled(using: &rng)
        }

        Self.log.info(
            "Fetched \(ordered.count, privacy: .public) assets (order=\(String(describing: order), privacy: .public))"
        )

        return AsyncStream { continuation in
            for asset in ordered {
                continuation.yield(asset)
            }
            continuation.finish()
        }
    }

    // MARK: - Default fetch

    /// Default `AssetFetcher` implementation — calls PhotoKit directly.
    ///
    /// Exposed as a static so callers (and tests) can refer to it by
    /// name when composing custom fetchers.
    public static let defaultFetch: AssetFetcher = { options in
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }
}
