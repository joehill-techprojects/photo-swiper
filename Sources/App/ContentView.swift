//
//  ContentView.swift
//  PhotoSwiper
//
//  Root view. Wires `AppState` (the `@Observable` deck owner) to `CardStack`
//  (the visible deck) and exposes `SettingsView` via a toolbar-triggered
//  sheet. Has no business logic of its own — every swipe is forwarded to
//  `AppState.handleSwipe(asset:direction:)`, which is also where deck
//  mutations are wrapped in `withAnimation` (see `AppState.swift` header).
//
//  Lifecycle:
//    - `AppState` is created once as `@State` so SwiftUI keeps it alive
//      across view rebuilds.
//    - Initial fetch fires from `.task { await appState.loadInitial() }`,
//      which only runs once per view identity (SwiftUI cancels on disappear
//      and restarts if the view re-appears with a new identity).
//    - Closing the settings sheet calls `appState.reloadOrder()` so a
//      changed order takes effect immediately. We could diff the old vs.
//      new value first; not worth the complexity for two users.
//
//  Permission handling: if the user hasn't granted photo access,
//  `PhotoFetcher` returns an empty stream, `cards` stays empty, and
//  `CardStack`'s built-in "No more photos" empty state shows. TASK-062 will
//  add a proper `PermissionView` onboarding screen in front of this view.
//

import SwiftUI

/// Root view of PhotoSwiper.
struct ContentView: View {

    /// Single source of truth for everything below this view. Created once
    /// per view identity; `@State` keeps the instance alive across redraws.
    @State private var appState = AppState()

    /// Drives the settings `.sheet` presentation.
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            content
                .padding()
                .navigationTitle("PhotoSwiper")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .sheet(isPresented: $showingSettings, onDismiss: {
                    // Re-fetch with the (possibly) new order. Cheap enough
                    // that we don't bother diffing the old value first.
                    Task { await appState.reloadOrder() }
                }) {
                    NavigationStack {
                        SettingsView(settings: appState.settings)
                            .navigationTitle("Settings")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") { showingSettings = false }
                                }
                            }
                    }
                }
                .task {
                    await appState.loadInitial()
                }
        }
    }

    /// The main centre region: a loading spinner during the initial fetch,
    /// otherwise the `CardStack` (which renders its own empty state when
    /// `cards` is empty).
    @ViewBuilder
    private var content: some View {
        if appState.isLoading && appState.cards.isEmpty {
            ProgressView()
                .controlSize(.large)
        } else {
            CardStack(cards: appState.cards) { asset, direction in
                // `AppState.handleSwipe` wraps the deck mutation in
                // `withAnimation` itself, so we don't need to do it here.
                // (Doing `withAnimation { await ... }` doesn't work anyway —
                // `withAnimation` is sync and would only animate the Task
                // creation, not the eventual deck mutation.)
                Task { await appState.handleSwipe(asset: asset, direction: direction) }
            }
        }
    }
}

#Preview {
    ContentView()
}
