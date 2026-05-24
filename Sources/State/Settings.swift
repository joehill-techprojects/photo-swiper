//
//  Settings.swift
//  PhotoSwiper
//
//  User-facing, non-sensitive app settings backed by `UserDefaults`.
//
//  This is the single source of truth for the photo deck order, the Immich
//  server URL, and the "old enough to also delete" age threshold. The Immich
//  API key is deliberately NOT stored here — it lives in the iOS Keychain via
//  `KeychainStore` (see DECISIONS D-012 / D-013).
//
//  Persistence is automatic: every property has a `didSet` that writes the new
//  value into the injected `UserDefaults` instance. Tests inject an isolated
//  suite (`UserDefaults(suiteName:)`) to avoid touching `.standard`.
//

import Foundation
import Observation
import os

/// Observable, `UserDefaults`-backed app settings.
///
/// Use the default initializer in app code (writes to `UserDefaults.standard`);
/// pass a custom `UserDefaults` in tests for isolation. Mutations are
/// persisted synchronously on the main actor and logged at `.debug` level
/// under the `Settings` category.
@MainActor
@Observable
public final class Settings {

    // MARK: - Nested types

    /// Order in which photos are surfaced to the user.
    public enum Order: String, CaseIterable, Codable, Sendable {
        /// Shuffle the photo library; default mode.
        case random
        /// Walk the photo library from the oldest asset forward.
        case oldestFirst
    }

    // MARK: - UserDefaults keys

    private enum Keys {
        static let order = "settings.order"
        static let immichURL = "settings.immichURL"
        static let oldPhotoThresholdDays = "settings.oldPhotoThresholdDays"
    }

    // MARK: - Logging

    private static let logger = Logger(
        subsystem: "com.joehill.photoswiper",
        category: "Settings"
    )

    // MARK: - Storage

    /// The `UserDefaults` instance backing this settings object. Injected for
    /// test isolation; production code uses `.standard`.
    @ObservationIgnored
    private let defaults: UserDefaults

    // MARK: - Public properties

    /// The order in which photos are drawn from the library. Defaults to
    /// `.random`. Unknown stored values fall back to `.random`.
    public var order: Order {
        didSet {
            defaults.set(order.rawValue, forKey: Keys.order)
            Self.logger.debug("order changed to \(self.order.rawValue, privacy: .public)")
        }
    }

    /// The base URL of the user's Immich server, e.g.
    /// `http://192.168.1.20:2283`. `nil` until the user configures it.
    /// A corrupt value stored in `UserDefaults` is treated as `nil` rather
    /// than crashing.
    public var immichURL: URL? {
        didSet {
            if let url = immichURL {
                defaults.set(url.absoluteString, forKey: Keys.immichURL)
            } else {
                defaults.removeObject(forKey: Keys.immichURL)
            }
            Self.logger.debug(
                "immichURL changed to \(self.immichURL?.absoluteString ?? "nil", privacy: .public)"
            )
        }
    }

    /// Minimum age (in days) at which a right-swiped photo is also deleted
    /// from the device after upload. Defaults to 365 (DECISIONS D-020).
    public var oldPhotoThresholdDays: Int {
        didSet {
            defaults.set(oldPhotoThresholdDays, forKey: Keys.oldPhotoThresholdDays)
            Self.logger.debug(
                "oldPhotoThresholdDays changed to \(self.oldPhotoThresholdDays, privacy: .public)"
            )
        }
    }

    // MARK: - Init

    /// Create a `Settings` instance backed by the given `UserDefaults`.
    ///
    /// - Parameter defaults: The store to read from and persist into. Defaults
    ///   to `UserDefaults.standard`. Tests should pass an isolated suite.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load `order`, falling back to `.random` if the stored value is
        // missing or unknown (e.g. a future build wrote a case we don't yet
        // recognize and the user rolled back).
        if let raw = defaults.string(forKey: Keys.order),
           let stored = Order(rawValue: raw) {
            self.order = stored
        } else {
            self.order = .random
        }

        // Load `immichURL`, treating a corrupt or under-specified stored
        // string as nil. `URL(string:)` accepts relative strings like "foo"
        // as valid, so we additionally require an http/https scheme and a
        // non-empty host before trusting it.
        if let raw = defaults.string(forKey: Keys.immichURL),
           let url = URL(string: raw),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https",
           let host = url.host, !host.isEmpty {
            self.immichURL = url
        } else {
            self.immichURL = nil
        }

        // Load `oldPhotoThresholdDays`. `UserDefaults.integer(forKey:)`
        // returns 0 when missing, which we treat as "not set" and replace
        // with the 365-day default.
        let storedThreshold = defaults.integer(forKey: Keys.oldPhotoThresholdDays)
        self.oldPhotoThresholdDays = storedThreshold > 0 ? storedThreshold : 365
    }
}
