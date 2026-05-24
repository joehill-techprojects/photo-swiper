//
//  SettingsView.swift
//  PhotoSwiper
//
//  User-facing settings screen. Currently exposes only the deck order mode
//  (random vs. oldest-first) and an About section showing the bundle's short
//  version string and build number. Immich server URL + API key fields are
//  intentionally NOT here — they ship in TASK-045 (Phase 4).
//
//  Design notes:
//  - Root container is a bare `Form` (no `NavigationStack`). Callers decide
//    whether to embed it in navigation chrome, so it works equally well as a
//    standalone screen or as a child of an existing navigation context.
//  - Binds against `Settings` (which is `@MainActor @Observable`) using
//    `@Bindable`, not `@ObservedObject`. Persistence is handled by the
//    `Settings` model itself via `didSet`; this view only mutates and reads.
//  - Per DECISIONS D-017, log via `os.Logger`. Property-change logging already
//    lives in `Settings`, so this view only logs view-lifecycle events at
//    `.debug` to avoid double-logging.
//

import SwiftUI
import os

/// Settings screen for PhotoSwiper.
///
/// Renders a `Form` bound to a `Settings` instance. Use it either standalone
/// (wrap in your own `NavigationStack`) or as a child view inside an existing
/// navigation context.
public struct SettingsView: View {

    /// The settings model this view reads from and writes to. Marked
    /// `@Bindable` because `Settings` is `@Observable` (Observation framework),
    /// not an `ObservableObject`.
    @Bindable private var settings: Settings

    private static let logger = Logger(
        subsystem: "com.joehill.photoswiper",
        category: "SettingsView"
    )

    /// Create a settings view bound to the given `Settings` model.
    ///
    /// - Parameter settings: The observable settings instance to bind to.
    public init(settings: Settings) {
        self.settings = settings
    }

    public var body: some View {
        Form {
            Section("Photo order") {
                Picker("Order", selection: $settings.order) {
                    Text("Random").tag(Settings.Order.random)
                    Text("Oldest first").tag(Settings.Order.oldestFirst)
                }
                .pickerStyle(.segmented)
            }

            Section("About") {
                LabeledContent("Version", value: Self.appVersion)
                LabeledContent("Build", value: Self.buildNumber)
            }
        }
        .onAppear {
            Self.logger.debug("SettingsView appeared")
        }
    }

    // MARK: - Bundle info

    /// Short marketing version (`CFBundleShortVersionString`), e.g. "1.0".
    /// Falls back to "0" when the key is missing (e.g. SwiftUI previews
    /// without a fully populated bundle).
    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Build number (`CFBundleVersion`), e.g. "42". Falls back to "0" when
    /// unavailable.
    private static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}

// MARK: - Preview

#Preview("Settings") {
    // Use an isolated UserDefaults suite so the preview doesn't pollute the
    // app's real settings and doesn't read stale state between preview runs.
    let suiteName = "preview.SettingsView.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let settings = Settings(defaults: defaults)
    return SettingsView(settings: settings)
}
