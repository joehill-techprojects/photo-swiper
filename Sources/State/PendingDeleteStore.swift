//
//  PendingDeleteStore.swift
//  PhotoSwiper
//
//  Persistent bucket of `PHAsset`s queued for batch deletion.
//
//  Per D-024, a left swipe no longer deletes immediately — it parks the
//  asset here until the user taps the "delete N photos" button, at which
//  point we hand the whole bucket to `PHPhotoLibrary` in a single
//  `performChanges` block (one Photos.app confirmation dialog for N assets).
//
//  Persistence: the list of `localIdentifier`s is written to UserDefaults
//  after every mutation so we survive an app kill mid-curation-session.
//  On init we re-fetch the matching `PHAsset`s from PhotoKit; identifiers
//  that no longer resolve (e.g. the user deleted them in Photos.app while
//  PhotoSwiper was backgrounded) are silently dropped — that's the right
//  call, the asset is already gone.
//
//  Per `DECISIONS.md`:
//    - D-017  os.Logger for structured logging
//    - D-024  batch-delete bucket lives here
//

import Foundation
import Photos
import os

/// In-memory + UserDefaults-backed bucket of `PHAsset`s waiting for the
/// user to confirm a batch delete.
///
/// Observation: `@Observable` instruments the stored `assets` property so
/// SwiftUI views reading `count` / `isEmpty` re-render automatically when
/// the bucket changes.
@MainActor
@Observable
public final class PendingDeleteStore {

    /// UserDefaults key under which we persist the bucket's localIdentifiers.
    /// Exposed so tests can inspect the spec'd key without crossing modules.
    public static let userDefaultsKey = "PhotoSwiper.PendingDelete.identifiers"

    @ObservationIgnored
    private static let log = Logger(
        subsystem: "com.joehill.photoswiper",
        category: "PendingDeleteStore"
    )

    @ObservationIgnored
    private let defaults: UserDefaults

    /// All assets currently queued for batch deletion. UI reads `count` /
    /// `isEmpty` off this via observation.
    public private(set) var assets: [PHAsset]

    /// Init.
    /// - Parameter defaults: UserDefaults to persist the bucket to. Inject
    ///   a suite-scoped instance in tests; default is `.standard`.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedIDs = defaults.stringArray(forKey: Self.userDefaultsKey) ?? []
        if storedIDs.isEmpty {
            self.assets = []
        } else {
            let result = PHAsset.fetchAssets(
                withLocalIdentifiers: storedIDs,
                options: nil
            )
            var restored: [PHAsset] = []
            restored.reserveCapacity(result.count)
            result.enumerateObjects { asset, _, _ in
                restored.append(asset)
            }
            self.assets = restored
        }

        Self.log.info(
            "init -> restored count=\(self.assets.count, privacy: .public) from \(storedIDs.count, privacy: .public) stored id(s)"
        )
    }

    public var count: Int { assets.count }
    public var isEmpty: Bool { assets.isEmpty }

    /// Append an asset to the bucket. Idempotent on `localIdentifier`
    /// (a second add of the same asset is a no-op — defensive against
    /// double-swipe edge cases).
    public func add(_ asset: PHAsset) {
        if assets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
            Self.log.debug(
                "add -> duplicate localIdentifier, no-op; count=\(self.assets.count, privacy: .public)"
            )
            return
        }
        assets.append(asset)
        persist()
        Self.log.debug("add -> count=\(self.assets.count, privacy: .public)")
    }

    /// Remove the most-recently-added asset (for undo). Returns it, or nil
    /// if the bucket was empty.
    @discardableResult
    public func removeLast() -> PHAsset? {
        guard let last = assets.popLast() else {
            Self.log.debug("removeLast -> empty, no-op")
            return nil
        }
        persist()
        Self.log.debug("removeLast -> count=\(self.assets.count, privacy: .public)")
        return last
    }

    /// Remove an asset by `localIdentifier` match. Returns `true` iff an
    /// entry was removed.
    @discardableResult
    public func remove(matching identifier: String) -> Bool {
        guard let idx = assets.firstIndex(where: { $0.localIdentifier == identifier }) else {
            Self.log.debug("remove(matching:) -> no match, no-op")
            return false
        }
        assets.remove(at: idx)
        persist()
        Self.log.debug(
            "remove(matching:) -> count=\(self.assets.count, privacy: .public)"
        )
        return true
    }

    /// Empty the bucket entirely. Called after a successful batch delete or
    /// a "discard pending" action.
    public func clear() {
        assets.removeAll()
        persist()
        Self.log.debug("clear -> count=0")
    }

    // MARK: - Persistence

    private func persist() {
        let ids = assets.map(\.localIdentifier)
        defaults.set(ids, forKey: Self.userDefaultsKey)
    }
}
