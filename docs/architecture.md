# Architecture

> App structure, file responsibilities, data flow, framework choices.
> Read this before writing any new file — make sure it fits.

## Directory layout (in the repo)

```
photo-swiper/
├── CLAUDE.md               # agent navigation
├── STATE.md                # current state
├── BACKLOG.md              # ordered task list
├── BUGS.md                 # bug log
├── HUMAN-TODO.md           # Joe-only blockers
├── DECISIONS.md            # locked decisions
├── README.md               # (eventually) human-facing, for after rollout
├── project.yml             # XcodeGen project spec
├── altstore-source.json    # AltStore source manifest (points at GitHub Releases)
├── .gitignore              # ignores .xcodeproj, DerivedData, .DS_Store, build artifacts
├── .github/
│   └── workflows/
│       ├── build.yml       # CI build → unsigned IPA artifact
│       └── release.yml     # tag IPA into a GitHub Release on push to main
├── Sources/
│   ├── App/
│   │   ├── PhotoSwiperApp.swift   # @main, app lifecycle
│   │   ├── ContentView.swift      # root view
│   │   └── Info.plist             # bundle metadata + usage descriptions
│   ├── State/
│   │   ├── AppState.swift         # top-level @Observable
│   │   ├── Settings.swift         # UserDefaults-backed settings
│   │   └── UndoStack.swift        # LIFO of reversible swipe events
│   ├── UI/
│   │   ├── CardStack.swift        # deck of 2-3 SwipeCards
│   │   ├── SwipeCard.swift        # single card + DragGesture
│   │   ├── SettingsView.swift     # settings screen
│   │   ├── PermissionView.swift   # first-launch onboarding
│   │   └── Toast.swift            # non-blocking error/info banner
│   ├── Photos/
│   │   └── PhotoFetcher.swift     # PhotoKit wrapper, order modes
│   ├── Actions/
│   │   ├── DeleteAction.swift     # PHAssetChangeRequest deletion
│   │   └── ShareAction.swift      # UIActivityViewController → Messages
│   ├── Immich/
│   │   ├── ImmichClient.swift     # ping + upload, URLSession-based
│   │   └── KeychainStore.swift    # Keychain wrapper for API key
│   └── Resources/
│       ├── Assets.xcassets        # app icon, accent color
│       └── Launch.storyboard      # launch screen
├── Tests/
│   ├── PhotosTests/
│   │   └── PhotoFetcherTests.swift
│   ├── StateTests/
│   │   └── UndoStackTests.swift
│   └── ImmichTests/
│       └── ImmichClientTests.swift
└── docs/
    ├── plan.md             # master implementation plan
    ├── architecture.md     # this file
    ├── setup-guide.md      # Joe's manual setup notes
    └── jill-guide.md       # (Phase 5) non-technical usage guide
```

## Data flow

```
PHPhotoLibrary  ──┐
                  ▼
            PhotoFetcher ──▶ AppState ──▶ CardStack ──▶ SwipeCard
                                 │            │
                                 │            └─ swipe gesture
                                 ▼                    │
                              Settings                ▼
                            (order mode)         DeleteAction
                                              │ ShareAction
                                              │ ImmichClient.upload
                                              ▼
                                          UndoStack
```

- `AppState` is the single `@Observable` root. Owns `Settings`, `UndoStack`, the current asset queue.
- `PhotoFetcher` is a stateless service. Given a `Settings`, returns an iterator of `PHAsset`s.
- `CardStack` reads the queue, renders the top N as `SwipeCard`s, dispatches swipe events to action handlers.
- Action handlers (`DeleteAction`, `ShareAction`, `ImmichClient.upload`) take a `PHAsset`, do their thing, and return a "reverse" closure pushed onto `UndoStack`.
- `UndoStack` is bounded (e.g. last 20 events). Pop → run the reverse closure → put the asset back on top of the queue.

## Key Apple frameworks

| Framework | Why | Where used |
|---|---|---|
| `SwiftUI` | UI | everywhere in `Sources/UI/` |
| `Photos` (PhotoKit) | fetch + delete `PHAsset`s | `PhotoFetcher`, `DeleteAction` |
| `UIKit` (limited) | `UIActivityViewController` for share | `ShareAction` |
| `Foundation.URLSession` | Immich HTTP | `ImmichClient` |
| `Security` (Keychain) | API key storage | `KeychainStore` |
| `os.Logger` | structured logging visible in Console.app | every service file |
| `Observation` | `@Observable` state | `AppState`, `Settings` |

## Threading model

- All `PhotoKit` operations are async and run on PhotoKit's background queue. Wrap calls in `async`/`await` (use `withCheckedThrowingContinuation` for the older callback APIs).
- `ImmichClient.upload` is `async` and uses `URLSession.shared.upload(for:from:)`.
- View updates always on the main actor — annotate `AppState` with `@MainActor`.
- No locks, no `DispatchQueue.sync`. If you find yourself reaching for those, stop and rethink.

## Error policy

- All errors surface as `Toast` messages, never modal alerts (per `DECISIONS.md` D-018).
- Upload failures: log + toast + re-queue the asset at the front of the deck.
- Permission denials: show `PermissionView` with a "go to Settings" deep link.
- Immich-unreachable: toast "Couldn't reach server. Stored locally, will retry." — `TODO` for retry queue, fine to ship without.

## Testing approach

| Code path | How tested |
|---|---|
| `PhotoFetcher` ordering | unit test with an injected fake asset list |
| `UndoStack` | unit test push/pop/clear/eviction |
| `ImmichClient` | unit test with `URLProtocol` stub returning canned responses |
| `Settings` (UserDefaults) | unit test with an isolated `UserDefaults.suiteName` |
| `KeychainStore` | unit test using a test access group, deleted on tearDown |
| SwiftUI views | manual on device |
| PhotoKit fetch/delete | manual on device |
| Swipe gestures | manual on device |

CI runs all unit tests on every push.

## Build & distribution flow

```
Edit Swift in VS Code on JARVIS
        │
        ▼
git push to GitHub
        │
        ▼
GitHub Actions (macos-14):
  - brew install xcodegen
  - xcodegen generate
  - xcodebuild test  (unit tests)
  - xcodebuild archive -archivePath … -destination 'generic/platform=iOS'
  - convert archive → unsigned .ipa
  - upload as artifact
        │
        ▼
release.yml: on success, create GitHub Release tag, attach .ipa
        │
        ▼
altstore-source.json (committed in repo, served via raw.githubusercontent.com):
  lists the release URL
        │
        ▼
AltStore on iPhone (pointed at the source URL):
  one-tap install/update; re-signs with Joe's free Apple ID at install time
        │
        ▼
AltServer on JARVIS:
  silently re-signs the installed app every ≤7 days while phone is on home WiFi
```

## What we are deliberately NOT building

These are tempting and would all be wrong for this project:

- ❌ Push notifications (no backend, no point)
- ❌ Background photo sync (the app is intentionally a foreground game)
- ❌ Multi-user sync state (Joe's deck and Jill's deck are independent)
- ❌ A photo browser / album viewer (Immich already does this)
- ❌ Cloud-stored settings (UserDefaults + iCloud backup is enough)
- ❌ Telemetry / crash reporting (2 users, both can text Joe if it crashes)
- ❌ Localization (English only)
- ❌ iPad layout (we'll see what SwiftUI gives us for free; not designing for it)
