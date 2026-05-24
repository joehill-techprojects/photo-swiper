//
//  ShareAction.swift
//  PhotoSwiper
//
//  Up-swipe action: hand the photo to the iOS share sheet so the user can
//  send it to the other household member via Messages.
//
//  iOS does NOT allow programmatic sending of Messages — the system compose
//  sheet always requires a human tap to actually send. That's expected and
//  fine. We just present `UIActivityViewController` with a sensible list of
//  excluded activities so Messages, Mail, AirDrop, Save Image, and Copy
//  bubble to the top.
//
//  Contract with `UndoStack` (TASK-032): we consider the share "done" once
//  the sheet has *appeared*, not once the user has sent. We have no signal
//  for "did they actually send" and the card has already animated off the
//  deck — if they bail out of the sheet, undo restores the card the same as
//  it would for any other swipe.
//
//  Per `DECISIONS.md`:
//    - D-009  PhotoKit for image bytes
//    - D-017  os.Logger
//

import Photos
import SwiftUI
import UIKit
import os

/// Errors `ShareAction.share` can throw.
public enum ShareError: Error {
    /// PhotoKit returned no image data and no underlying error — usually means
    /// the asset is in iCloud and couldn't be materialised, or was deleted.
    case noImage
    /// We couldn't locate a foreground `UIWindowScene` / root view controller
    /// to present the share sheet from. Should be impossible in normal app
    /// foreground use.
    case noPresenter
    /// PhotoKit reported an explicit error while fetching image data.
    case failed(underlying: Error)
}

/// Namespace for the share-photo action.
///
/// Single static entry point — no instance state to own. Call:
/// ```
/// try await ShareAction.share(asset)
/// ```
/// from the `.up` branch of `AppState.handleSwipe`.
public enum ShareAction {

    private static let log = Logger(
        subsystem: "com.joehill.photoswiper",
        category: "ShareAction"
    )

    /// Fetch the asset's image and present the system share sheet.
    ///
    /// Returns once the sheet's `present(_:animated:completion:)` completion
    /// fires — i.e. the sheet is on screen. Does NOT wait for the user to
    /// pick an activity or send a message; iOS gives us no such signal.
    ///
    /// - Throws: `ShareError.noImage`, `ShareError.noPresenter`, or
    ///   `ShareError.failed(underlying:)`.
    @MainActor
    public static func share(_ asset: PHAsset) async throws {
        log.info("share starting for asset \(asset.localIdentifier, privacy: .public)")

        let image: UIImage
        do {
            image = try await loadImage(for: asset)
        } catch {
            log.error("share failed loading image for asset \(asset.localIdentifier, privacy: .public): \(String(describing: error), privacy: .public)")
            throw error
        }

        guard let presenter = topViewController() else {
            log.error("share failed: no presenter for asset \(asset.localIdentifier, privacy: .public)")
            throw ShareError.noPresenter
        }

        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .print,
            .addToReadingList,
            .openInIBooks,
            .markupAsPDF
        ]

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            presenter.present(activityVC, animated: true) {
                continuation.resume()
            }
        }

        log.info("share sheet presented for asset \(asset.localIdentifier, privacy: .public)")
    }

    // MARK: - Image loading

    /// Wrap `PHImageManager.requestImage` in an async throw. We use
    /// `requestImage` (not `requestImageDataAndOrientation`) because we
    /// need a `UIImage` for `UIActivityViewController` anyway, and
    /// `requestImage` handles orientation for us.
    ///
    /// `.highQualityFormat` + a sentinel target size of `PHImageManagerMaximumSize`
    /// gives the full-resolution image — the user is sharing the photo, not
    /// a thumbnail.
    @MainActor
    private static func loadImage(for asset: PHAsset) async throws -> UIImage {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            // Continuation can be resumed multiple times by PhotoKit under
            // some delivery modes; we guard against that with a flag.
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { result, info in
                guard !resumed else { return }

                if let error = info?[PHImageErrorKey] as? Error {
                    resumed = true
                    continuation.resume(throwing: ShareError.failed(underlying: error))
                    return
                }

                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if degraded {
                    // Wait for the final, non-degraded delivery.
                    return
                }

                if let result {
                    resumed = true
                    continuation.resume(returning: result)
                } else {
                    resumed = true
                    continuation.resume(throwing: ShareError.noImage)
                }
            }
        }
    }

    // MARK: - Presenter lookup

    /// Walk the active `UIWindowScene` to find the topmost view controller
    /// that can present a sheet. Returns nil if the app is backgrounded or
    /// has no foreground scene.
    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        guard let root = scene?.keyWindow?.rootViewController else {
            return nil
        }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
