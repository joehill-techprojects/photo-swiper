//
//  DeleteAction.swift
//  PhotoSwiper
//
//  Stateless namespace that deletes a single `PHAsset` from the user's
//  iOS photo library.
//
//  Behaviour notes:
//  - Wraps `PHPhotoLibrary.shared().performChanges` around a
//    `PHAssetChangeRequest.deleteAssets` call. iOS itself surfaces the
//    "Are you sure you want to delete this photo?" system confirmation
//    sheet — that IS the in-app safety net for left-swipes. Per
//    `DECISIONS.md` D-018 (non-blocking failure UX) and the error policy
//    in `docs/architecture.md`, we do NOT add another confirmation layer
//    on top of it.
//  - The PhotoKit API is completion-handler based; we bridge it to
//    `async/await` with `withCheckedThrowingContinuation`.
//  - If the user taps "Cancel" on the system confirmation, PhotoKit
//    invokes the completion with `success=false` and an error whose
//    domain/code corresponds to `PHPhotosError.userCancelled`. We map
//    that to `DeleteError.userCancelled` so the caller (the swipe
//    handler in `AppState`) can distinguish "user backed out" from
//    "actual failure" and skip the `UndoStack` push in that case.
//  - All other failures surface as `DeleteError.failed(underlying:)`.
//
//  Per `DECISIONS.md`:
//    - D-009  PhotoKit only (no third-party photo libs)
//    - D-017  os.Logger for structured logging
//    - D-018  non-blocking failure UX (rely on the system prompt)
//
//  Phase 3 scope (TASK-030).
//

import Foundation
import Photos
import os

/// Errors thrown by `DeleteAction.delete(_:)`.
public enum DeleteError: Error {
    /// The user tapped "Cancel" on the iOS system delete confirmation.
    /// Callers should treat this as a benign no-op (do not push to
    /// `UndoStack`, do not show an error toast).
    case userCancelled

    /// PhotoKit reported a failure other than user-cancellation. The
    /// underlying `Error` is preserved for logging / diagnostics.
    case failed(underlying: Error)
}

/// Namespace for the left-swipe "delete from device" action.
///
/// Not an instantiable type — `DeleteAction` has no state and exists
/// purely to scope the `delete(_:)` entry point.
public enum DeleteAction {

    private static let log = Logger(
        subsystem: "com.joehill.photoswiper",
        category: "DeleteAction"
    )

    /// Delete a single asset from the user's photo library.
    ///
    /// iOS shows its own confirmation sheet before the deletion commits;
    /// this function returns only once the user has either confirmed or
    /// cancelled that sheet.
    ///
    /// - Parameter asset: The `PHAsset` to delete.
    /// - Throws:
    ///   - `DeleteError.userCancelled` if the user tapped Cancel.
    ///   - `DeleteError.failed(underlying:)` for any other PhotoKit error.
    public static func delete(_ asset: PHAsset) async throws {
        Self.log.info(
            "delete entry asset=\(asset.localIdentifier, privacy: .public)"
        )

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                } completionHandler: { success, error in
                    if success {
                        continuation.resume(returning: ())
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        // success=false with no error shouldn't happen per
                        // PhotoKit docs, but be defensive: surface as a
                        // generic failure so the caller doesn't silently
                        // assume completion.
                        continuation.resume(
                            throwing: DeleteError.failed(
                                underlying: NSError(
                                    domain: "DeleteAction",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey:
                                        "PhotoKit reported failure with no error"]
                                )
                            )
                        )
                    }
                }
            }

            Self.log.info(
                "delete success asset=\(asset.localIdentifier, privacy: .public)"
            )
        } catch let deleteError as DeleteError {
            // Defensive re-throw — covers the synthetic "no error" case above.
            Self.log.error(
                "delete failed asset=\(asset.localIdentifier, privacy: .public) error=\(String(describing: deleteError), privacy: .public)"
            )
            throw deleteError
        } catch {
            // PhotoKit signals user-cancellation via PHPhotosError.userCancelled
            // (domain `PHPhotosErrorDomain`, code 3072). Map it explicitly so
            // the caller can branch on it.
            let nsError = error as NSError
            if nsError.domain == PHPhotosErrorDomain,
               nsError.code == PHPhotosError.userCancelled.rawValue {
                Self.log.info(
                    "delete user-cancelled asset=\(asset.localIdentifier, privacy: .public)"
                )
                throw DeleteError.userCancelled
            }

            Self.log.error(
                "delete failed asset=\(asset.localIdentifier, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            throw DeleteError.failed(underlying: error)
        }
    }
}
