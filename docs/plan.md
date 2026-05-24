# PhotoSwiper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Tinder-style iOS photo curation app for Joe and Jill (2-user private install via AltStore), enabling left=delete / right=upload-to-Immich / up=share-via-Messages, with age-based phone cleanup, undo, and order settings.

**Architecture:** SwiftUI app, iOS 17+, built on GitHub Actions macOS runners (no local Mac), distributed unsigned via GitHub Releases + AltStore (AltStore re-signs with each user's free Apple ID on install; AltServer on JARVIS handles the weekly silent refresh). PhotoKit for photo access, URLSession for Immich REST API, Keychain for the API key.

**Tech Stack:** Swift 5.10+, SwiftUI, iOS 17+, PhotoKit, URLSession, XcodeGen, GitHub Actions (macos-14), AltStore + AltServer.

**Document conventions:**
- Tasks in Phase 0–1 have **concrete steps** (exact file contents, exact shell commands). The build pipeline is unfamiliar territory and gets full detail.
- Tasks in Phase 2+ have **task specs** — files to create, responsibilities, APIs to use, tests required, acceptance criteria. The implementing agent fills in the Swift body because (a) it'll be testing against real iOS as it writes, and (b) over-specifying Swift code that hasn't compiled against a real build is a recipe for fiction.

---

## Phase 0 — Foundations

### TASK-001 — Initialize local git repo + .gitignore

**Files:** Create `.gitignore`.

- [ ] **Step 1 — Init repo**

```bash
cd C:\workspace\photo-swiper
git init -b main
```

- [ ] **Step 2 — Write `.gitignore`**

Content:
```
# Xcode generated
*.xcodeproj/
*.xcworkspace/
DerivedData/
build/
*.ipa
*.dSYM.zip
*.dSYM/

# Swift Package Manager
.build/
Packages/
Package.resolved
xcuserdata/

# macOS
.DS_Store

# AltStore artifacts (we publish via GitHub Releases, not committed)
*.altsource

# Editor
.vscode/
.idea/

# Secrets — should never appear, but belt and suspenders
*.env
secrets.json
```

- [ ] **Step 3 — First commit**

```bash
git add CLAUDE.md STATE.md BACKLOG.md BUGS.md HUMAN-TODO.md DECISIONS.md docs/ .gitignore
git commit -m "chore: scaffold photo-swiper project structure"
```

- [ ] **Step 4 — Update orchestration files**

Mark TASK-001 `- [x]` in `BACKLOG.md` with commit SHA. Update `STATE.md` to reflect TASK-001 done, next is TASK-002 (blocked) or TASK-003/TASK-006.

### TASK-002 — Push initial scaffold to GitHub

**Blocked on:** H-003 (repo exists), H-004 (PAT).

- [ ] **Step 1 — Confirm Joe has provided repo URL + PAT**

If not, mark TASK-002 `- [!]` blocked-on-H-003 and skip.

- [ ] **Step 2 — Add remote and push**

```bash
git remote add origin <repo URL from Joe>
git push -u origin main
```

Use the PAT as the password if prompted.

- [ ] **Step 3 — Verify push**

Visit the repo URL, confirm `CLAUDE.md` is visible.

- [ ] **Step 4 — Update orchestration files**

Mark done in BACKLOG, update STATE.

### TASK-003 — Flesh out `docs/setup-guide.md` with AltServer/AltStore steps

**Files:** Modify `docs/setup-guide.md`.

- [ ] **Step 1 — Write the JARVIS-side setup section**

Cover: iTunes install, AltServer install, autostart check (system tray icon after reboot), `Mail Plug-in` enable (the AltServer installer prompts for this; needs Apple Mail running once to register).

- [ ] **Step 2 — Write the iPhone-side setup section**

Cover: USB cable + "Trust This Computer", AltServer tray icon → "Install AltStore" → pick device → enter Apple ID, on phone go to Settings → General → VPN & Device Management → trust the developer profile.

- [ ] **Step 3 — Write the "add PhotoSwiper source" section** (will be fleshed out after TASK-012 lands, leave a placeholder URL)

- [ ] **Step 4 — Commit + update orchestration files**

```bash
git add docs/setup-guide.md BACKLOG.md STATE.md
git commit -m "docs: AltServer + AltStore setup walkthrough"
```

### TASK-004 — Confirm Joe has installed AltServer + iTunes on JARVIS

**Blocked on:** H-005, H-006.

- [ ] **Step 1 — Ask Joe directly**

"AltServer tray icon present? iTunes installed? Reply yes/no."

- [ ] **Step 2 — If yes, mark done.** If no, leave blocked.

### TASK-005 — Confirm Joe has AltStore on his phone

**Blocked on:** H-008, H-009, H-010.

- [ ] **Step 1 — Ask Joe:** "AltStore icon on phone home screen, opens without crashing? Yes/no."
- [ ] **Step 2 — If yes, mark done.**

---

## Phase 1 — Build pipeline (Hello World end-to-end)

### TASK-006 — Write `project.yml` (XcodeGen spec)

**Files:** Create `project.yml`.

XcodeGen reads YAML and emits a `.xcodeproj`. This is the **single source of truth for project settings** — bundle ID, deployment target, capabilities, file groups.

- [ ] **Step 1 — Write `project.yml`**

```yaml
name: PhotoSwiper
options:
  bundleIdPrefix: com.joehill
  deploymentTarget:
    iOS: "17.0"
  developmentLanguage: en
settings:
  base:
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    SWIFT_VERSION: "5.10"
    GENERATE_INFOPLIST_FILE: NO
    INFOPLIST_FILE: Sources/App/Info.plist
    CODE_SIGN_STYLE: Manual
    CODE_SIGNING_REQUIRED: NO
    CODE_SIGNING_ALLOWED: NO
targets:
  PhotoSwiper:
    type: application
    platform: iOS
    sources:
      - Sources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.joehill.photoswiper
        TARGETED_DEVICE_FAMILY: "1"  # iPhone only
        ENABLE_PREVIEWS: YES
  PhotoSwiperTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - Tests
    dependencies:
      - target: PhotoSwiper
schemes:
  PhotoSwiper:
    build:
      targets:
        PhotoSwiper: all
        PhotoSwiperTests: [test]
    test:
      targets:
        - PhotoSwiperTests
```

The `CODE_SIGNING_*: NO` settings produce an unsigned binary — exactly what AltStore wants.

- [ ] **Step 2 — Commit**

```bash
git add project.yml
git commit -m "feat: XcodeGen project spec for Hello World iOS app"
```

### TASK-007 — Write `Sources/App/Info.plist`

**Files:** Create `Sources/App/Info.plist`.

- [ ] **Step 1 — Write minimal Info.plist** (Photo permission descriptions added in TASK-021)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key>
  <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
  <key>CFBundleName</key>
  <string>$(PRODUCT_NAME)</string>
  <key>CFBundleDisplayName</key>
  <string>PhotoSwiper</string>
  <key>CFBundleShortVersionString</key>
  <string>$(MARKETING_VERSION)</string>
  <key>CFBundleVersion</key>
  <string>$(CURRENT_PROJECT_VERSION)</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>UILaunchScreen</key>
  <dict/>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
  </array>
  <key>LSRequiresIPhoneOS</key>
  <true/>
</dict>
</plist>
```

- [ ] **Step 2 — Commit**

```bash
git add Sources/App/Info.plist
git commit -m "feat: Info.plist for PhotoSwiper bundle"
```

### TASK-008 — Write `Sources/App/PhotoSwiperApp.swift`

**Files:** Create `Sources/App/PhotoSwiperApp.swift`.

- [ ] **Step 1 — Write app entry**

```swift
import SwiftUI

@main
struct PhotoSwiperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 2 — Commit**

```bash
git add Sources/App/PhotoSwiperApp.swift
git commit -m "feat: app entry point"
```

### TASK-009 — Write `Sources/App/ContentView.swift`

**Files:** Create `Sources/App/ContentView.swift`.

- [ ] **Step 1 — Write placeholder view**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("PhotoSwiper")
                .font(.largeTitle.bold())
            Text("Build pipeline alive ✓")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 2 — Commit**

```bash
git add Sources/App/ContentView.swift
git commit -m "feat: Hello World ContentView"
```

### TASK-010 — Write `.github/workflows/build.yml`

**Files:** Create `.github/workflows/build.yml`.

- [ ] **Step 1 — Write the workflow**

```yaml
name: Build

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.4.app

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate xcodeproj
        run: xcodegen generate

      - name: Build for testing (unit tests run on simulator)
        run: |
          xcodebuild test \
            -project PhotoSwiper.xcodeproj \
            -scheme PhotoSwiper \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
            CODE_SIGNING_ALLOWED=NO

      - name: Archive for device (unsigned)
        run: |
          xcodebuild archive \
            -project PhotoSwiper.xcodeproj \
            -scheme PhotoSwiper \
            -archivePath build/PhotoSwiper.xcarchive \
            -destination 'generic/platform=iOS' \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY=""

      - name: Package unsigned IPA
        run: |
          mkdir -p build/Payload
          cp -R build/PhotoSwiper.xcarchive/Products/Applications/PhotoSwiper.app build/Payload/
          cd build && zip -qr PhotoSwiper.ipa Payload
          ls -lh build/PhotoSwiper.ipa

      - name: Upload IPA artifact
        uses: actions/upload-artifact@v4
        with:
          name: PhotoSwiper-ipa
          path: build/PhotoSwiper.ipa
          retention-days: 30
```

The trick is `CODE_SIGNING_ALLOWED=NO` + manually packaging the `.app` into an unsigned IPA. AltStore re-signs locally on the phone.

- [ ] **Step 2 — Commit**

```bash
git add .github/workflows/build.yml
git commit -m "ci: GitHub Actions build for unsigned IPA"
```

### TASK-011 — Write `.github/workflows/release.yml`

**Files:** Create `.github/workflows/release.yml`.

- [ ] **Step 1 — Write the release workflow**

```yaml
name: Release

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  release:
    runs-on: ubuntu-latest
    needs: []   # we'll trigger after build succeeds via workflow_run instead
    if: false   # placeholder, replaced below
```

Actually, the cleaner pattern is to **append release steps to build.yml** so we only run once. Replace `build.yml`'s end with:

```yaml
      - name: Compute tag
        id: tag
        if: github.ref == 'refs/heads/main'
        run: |
          TAG="v0.1.$(date +%Y%m%d%H%M%S)"
          echo "tag=$TAG" >> $GITHUB_OUTPUT

      - name: Create GitHub Release
        if: github.ref == 'refs/heads/main'
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.tag.outputs.tag }}
          files: build/PhotoSwiper.ipa
          generate_release_notes: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

So TASK-011 actually = edit `build.yml` to add the release steps, and **delete the empty `release.yml`** if you created it. Update DECISIONS.md to note this consolidation.

- [ ] **Step 2 — Commit**

```bash
git add .github/workflows/build.yml DECISIONS.md
git rm -f .github/workflows/release.yml 2>/dev/null || true
git commit -m "ci: tag IPA into GitHub Release on push to main"
```

### TASK-012 — Write `altstore-source.json`

**Files:** Create `altstore-source.json`.

AltStore reads a JSON manifest describing your app and where to download IPAs. Format reference: <https://faq.altstore.io/distribute-your-apps/make-a-source>.

- [ ] **Step 1 — Write the source manifest**

```json
{
  "name": "Joe's Personal Apps",
  "identifier": "com.joehill.altstore-source",
  "apps": [
    {
      "name": "PhotoSwiper",
      "bundleIdentifier": "com.joehill.photoswiper",
      "developerName": "Joe Hill",
      "subtitle": "Swipe your camera roll",
      "localizedDescription": "Tinder-style photo curation. Left = delete, right = save to Immich, up = share.",
      "iconURL": "https://raw.githubusercontent.com/<USER>/<REPO>/main/Sources/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
      "tintColor": "#7C3AED",
      "category": "photo-video",
      "screenshotURLs": [],
      "versions": [
        {
          "version": "0.1.0",
          "date": "2026-05-24T00:00:00-05:00",
          "downloadURL": "https://github.com/<USER>/<REPO>/releases/latest/download/PhotoSwiper.ipa",
          "size": 0
        }
      ],
      "permissions": [
        {
          "type": "photos",
          "usageDescription": "Show and curate your photo library."
        }
      ]
    }
  ]
}
```

Replace `<USER>/<REPO>` with the real values from Joe's GitHub repo.

- [ ] **Step 2 — Commit**

```bash
git add altstore-source.json
git commit -m "feat: AltStore source manifest pointing at GitHub Releases"
```

### TASK-013 — First push, watch CI go green, fix iteratively

- [ ] **Step 1 — Push**

```bash
git push
```

- [ ] **Step 2 — Watch the Actions tab** in GitHub. The build will likely fail the first 2-3 times (Xcode version mismatch, missing simulator, etc.). Each failure → diagnose, fix `build.yml`, push again.

- [ ] **Step 3 — Log every CI failure in BUGS.md** as a `BUG-NNN` even if you fix it immediately. This builds institutional memory.

- [ ] **Step 4 — Acceptance:** Actions tab shows green checkmark, `build/PhotoSwiper.ipa` is downloadable from the workflow run page.

### TASK-014 — Verify IPA downloads from the GitHub Release URL

- [ ] **Step 1 — Visit `https://github.com/<USER>/<REPO>/releases/latest`**, confirm there's a release tagged `v0.1.YYYYMMDDHHMMSS`, with `PhotoSwiper.ipa` as an asset.
- [ ] **Step 2 — Download `PhotoSwiper.ipa`** via browser, confirm the file is non-empty (probably 1-3 MB for a Hello World).
- [ ] **Step 3 — Acceptance:** Direct URL `https://github.com/<USER>/<REPO>/releases/latest/download/PhotoSwiper.ipa` redirects and downloads.

### TASK-015 — Tell Joe to add the AltStore source and install PhotoSwiper

- [ ] **Step 1 — Update `docs/setup-guide.md`** "add PhotoSwiper source" section with the actual raw GitHub URL of `altstore-source.json`:

```
https://raw.githubusercontent.com/<USER>/<REPO>/main/altstore-source.json
```

(If the repo is private, this needs a PAT — easier path is to make the repo public OR host the JSON via GitHub Pages with a PAT-signed proxy. Document the trade-off in DECISIONS.md and pick one before continuing.)

- [ ] **Step 2 — Add H-020** to HUMAN-TODO.md (already there).
- [ ] **Step 3 — Ping Joe:** "AltStore on phone → Browse tab → "+" icon → paste this URL: ... → install PhotoSwiper → launch it → tell me what you see."

### TASK-016 — Joe confirms Hello World launches

- [ ] **Step 1 — Wait for Joe's report.**
- [ ] **Step 2 — If success:** mark done, set STATE.md to "Phase 1 complete, starting Phase 2."
- [ ] **Step 3 — If failure:** log as `BUG-NNN`, create fix task, iterate.

---

## Phase 2 — Photo browsing core

### TASK-021 — Add photo permission descriptions to Info.plist

**Files:** Modify `Sources/App/Info.plist`.

**Spec:**
- Add `NSPhotoLibraryUsageDescription` = "PhotoSwiper needs access to show and curate your photos."
- Add `NSPhotoLibraryAddUsageDescription` = "Save photos back to your library after editing." (Not strictly needed yet, but cheap to include.)

**Acceptance:** Push, CI green, install on phone, launching the app shows the photo-permission prompt.

### TASK-022 — `PhotoFetcher`

**Files:** Create `Sources/Photos/PhotoFetcher.swift`.

**Spec:**
- Public API: `func iterator(order: Settings.Order) async -> AsyncStream<PHAsset>`
- Internally: `PHAsset.fetchAssets(with: .image, options:)` with `creationDate` sort for chronological, or shuffled in-memory for random.
- Only fetch `.image` for v0 (videos later if anyone asks).
- Filter: skip assets where `sourceType` is `.typeCloudShared` (those aren't ours to delete).
- Use `@MainActor` only at the boundary; the fetch itself runs off the main actor.

**Acceptance:** Unit test in TASK-023 passes against a fake PHFetchResult.

### TASK-023 — `PhotoFetcherTests`

**Files:** Create `Tests/PhotosTests/PhotoFetcherTests.swift`.

**Spec:** Cover both order modes against an injected fake list. Random mode test: shuffle is stable for a given seed (inject the RNG so the test is deterministic).

### TASK-024 — `SwipeCard`

**Files:** Create `Sources/UI/SwipeCard.swift`.

**Spec:**
- SwiftUI view that takes a `UIImage` (or `PHAsset` and resolves it via `PHCachingImageManager`) and a callback `(Direction) -> Void` where `Direction` ∈ `{.left, .right, .up}`.
- `DragGesture` reads horizontal + vertical velocity; threshold ~120 pts triggers a swipe.
- Animate the card off-screen on commit, fire callback.
- Spring back on cancel.
- Image fills the card with `.aspectRatio(contentMode: .fit)`, rounded corners, subtle shadow.

**Acceptance:** Manual on device. Card moves with finger, snaps off above threshold, springs back below.

### TASK-025 — `CardStack`

**Files:** Create `Sources/UI/CardStack.swift`.

**Spec:**
- Renders the top 2-3 cards from a queue, stacked with small offset + scale to suggest depth.
- On top card swipe: notify parent with `(PHAsset, Direction)`, pop the queue.
- Pull next from `AppState`'s iterator when queue drops below 2.

**Acceptance:** Manual on device: swiping reveals the next card smoothly.

### TASK-026 — `Settings`

**Files:** Create `Sources/State/Settings.swift`.

**Spec:**
- `@Observable` class.
- Properties: `order: Order` (`.random` | `.oldestFirst`), `immichURL: URL?`, `oldPhotoThresholdDays: Int` (default 365).
- Persists to `UserDefaults.standard` via `didSet`.
- API key is **not** here — that's in `KeychainStore`.

**Acceptance:** Reading and writing each property survives an app relaunch (verify with a unit test that uses a custom suite name).

### TASK-027 — `SettingsView`

**Files:** Create `Sources/UI/SettingsView.swift`.

**Spec:**
- Form with a `Picker` for order mode.
- Immich URL + API key fields added in TASK-045 (don't pre-build).

**Acceptance:** Changing order in SettingsView, dismissing, swiping a few cards reflects the new order.

### TASK-028 — `AppState`

**Files:** Create `Sources/State/AppState.swift`.

**Spec:**
- `@Observable @MainActor` root state.
- Owns: `Settings`, `UndoStack` (created in Phase 3), the current `AsyncStream<PHAsset>` iterator.
- Single source of truth for the current deck.
- Exposes `currentTopCards: [PHAsset]` for `CardStack`.

**Acceptance:** Wires Phase 2 together — running app shows real photos, swiping pulls the next.

### TASK-029 — Phase 2 manual test

**Spec:** Install latest build on Joe's phone. Confirm:
1. Photo permission prompt appears on first launch.
2. Photos appear in a swipeable deck.
3. Both order modes (set in Settings) actually change order.
4. No crashes.

Log every bug as a `BUG-NNN`.

---

## Phase 3 — Actions wired

### TASK-030 — `DeleteAction`

**Files:** Create `Sources/Actions/DeleteAction.swift`.

**Spec:**
- `static func delete(_ asset: PHAsset) async throws -> ReverseAction`
- Uses `PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.deleteAssets([asset] as NSArray) }`.
- iOS shows a system confirmation. That's fine — it's the safety net we want.
- The `ReverseAction` is "do nothing" because iOS keeps the asset in Recently Deleted for 30 days, and undo here means popping the visual card back, not un-deleting (which iOS doesn't let us do programmatically).
- Document this clearly in the file header so future-you doesn't try to "fix" it.

**Acceptance:** Left-swipe a photo, iOS confirms, photo is gone from Photos app (visible in Recently Deleted).

### TASK-031 — `ShareAction`

**Files:** Create `Sources/Actions/ShareAction.swift`.

**Spec:**
- Resolves `PHAsset` → `UIImage` via `PHImageManager.default().requestImage`.
- Presents `UIActivityViewController` with `.message` as the preferred activity type and the image as the activity item.
- User taps Send to actually send.
- Returns immediately after presenting (don't try to await the send result; we can't see it).

**Acceptance:** Up-swipe a photo, Messages sheet appears with the image, user can pick a contact and send.

### TASK-032 — `UndoStack`

**Files:** Create `Sources/State/UndoStack.swift`.

**Spec:**
- Bounded LIFO, max 20 entries.
- Each entry: `(asset: PHAsset, action: SwipeAction, reverse: () async -> Void)`.
- `push(_ entry)`, `pop() async -> Entry?`, `clear()`.
- Thread-safe via `@MainActor`.

**Acceptance:** Unit tests in TASK-033 cover push/pop/clear/eviction.

### TASK-033 — `UndoStackTests`

**Files:** Create `Tests/StateTests/UndoStackTests.swift`.

### TASK-034 — Wire left swipe → DeleteAction + push to UndoStack

**Spec:** In `AppState`, the swipe callback for `.left` invokes `DeleteAction.delete`, on success pushes a "put card back" reverse onto `UndoStack`.

### TASK-035 — Wire up swipe → ShareAction + push to UndoStack

**Spec:** As above for `.up`.

### TASK-036 — Undo button

**Files:** Modify `Sources/App/ContentView.swift` (or wherever the persistent UI chrome lives).

**Spec:** A small undo button at the bottom of the screen, disabled when `UndoStack` is empty. Tap calls `AppState.undo()` which pops and runs the reverse, then re-inserts the asset at the top of the card queue.

### TASK-037 — Phase 3 manual test

Same as TASK-029. Test all three swipe directions + undo. Log bugs.

---

## Phase 4 — Immich integration

### TASK-040 — Get Immich URL + API key from Joe

**Blocked on H-021.** Just ask Joe and record both in DECISIONS.md (URL is fine to record; API key never in DECISIONS — only in Joe's password manager and the phone Keychain).

### TASK-041 — `KeychainStore`

**Files:** Create `Sources/Immich/KeychainStore.swift`.

**Spec:**
- Thin wrapper over `SecItemAdd` / `SecItemCopyMatching` / `SecItemDelete`.
- Single API: `static var immichAPIKey: String? { get set }`.
- Service identifier: `com.joehill.photoswiper.immich`.

**Acceptance:** Set, read, delete in a unit test (using a test access group, cleaned up on tearDown).

### TASK-042 — `ImmichClient.ping()`

**Files:** Create `Sources/Immich/ImmichClient.swift`.

**Spec:**
- `init(baseURL: URL, apiKey: String)`.
- `func ping() async throws -> Bool` — hits `GET {baseURL}/api/server-info/ping`, expects `{"res": "pong"}`.
- Sets `x-api-key` header on every request.
- Uses `URLSession.shared`.

### TASK-043 — `ImmichClient.upload`

**Spec:**
- `func upload(_ asset: PHAsset) async throws -> UploadResult`
- Resolves `PHAsset` → file data + metadata (`creationDate`, original filename, sha1 checksum).
- POSTs `multipart/form-data` to `/api/asset/upload` with fields per Immich docs: `assetData`, `deviceAssetId`, `deviceId`, `fileCreatedAt`, `fileModifiedAt`, `isFavorite`, `fileExtension`.
- Returns: `.created(assetID)` or `.duplicate(assetID)`.

**Reference:** Immich API docs at `https://immich.app/docs/api/upload-asset` — verify field names against the current Immich version on Joe's NAS (Phase 4 reality check).

### TASK-044 — `ImmichClientTests`

**Files:** Create `Tests/ImmichTests/ImmichClientTests.swift`.

**Spec:** Stub `URLProtocol` to return canned responses. Cover: 201 Created, 200 Duplicate, 401 Unauthorized, 5xx server error.

### TASK-045 — Settings UI for Immich URL + API key + "Test connection"

**Files:** Modify `Sources/UI/SettingsView.swift`.

**Spec:**
- Text field for URL (validates as `URL`).
- Secure text field for API key (writes to KeychainStore).
- Button "Test connection" → calls `ImmichClient.ping()`, shows ✓ or ✗ inline.

### TASK-046 — Wire right-swipe → ImmichClient.upload

**Spec:** Similar pattern to Phase 3. Right-swipe queues an upload (don't block the UI). On success, push a "put card back" reverse onto UndoStack. On failure: toast + re-queue at front of deck.

### TASK-047 — Age check → also delete after successful upload

**Spec:**
- After `ImmichClient.upload(asset)` succeeds, check `asset.creationDate < Date().addingTimeInterval(-86400 * 365)`.
- If yes, call `DeleteAction.delete(asset)`.
- Document the behavior in an inline comment because it's non-obvious from reading the swipe handler.

### TASK-048 — Phase 4 manual test

Test right-swipe on a recent photo (uploads, stays on phone), and on an old photo (uploads, gets deleted). Verify in Immich web UI.

### TASK-049 — Upload progress + failure toasts

**Files:** Create `Sources/UI/Toast.swift`.

**Spec:** Simple `@Observable` toast queue. Pops a banner from top, auto-dismisses after 3s, swipe-to-dismiss. Used by `AppState` to surface upload events.

---

## Phase 5 — Polish & rollout

### TASK-060 — App icon

**Spec:** Generate a 1024×1024 PNG. Style: bright, fun, camera-roll-ish. Could be Joe-supplied or AI-generated. Place at `Sources/Resources/Assets.xcassets/AppIcon.appiconset/`. Update `project.yml` if needed.

### TASK-061 — Launch screen

**Spec:** SwiftUI launch screen showing app icon + name on a tint background. Configured via `UILaunchScreen` in Info.plist (already a stub there).

### TASK-062 — First-launch permission onboarding

**Files:** Create `Sources/UI/PermissionView.swift`.

**Spec:** If `PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized`, show an explanatory screen with a "Grant access" button. Same for Immich (if URL/key not set, route to SettingsView).

### TASK-063 — Empty state when all photos triaged

**Spec:** When the asset iterator returns nil and the queue is empty, show "All done for now — come back later" with a refresh button.

### TASK-064 — "All done" celebration

**Spec:** Lightweight — a confetti shower (SwiftUI has a Symbols Effect for this) when the session ends. Don't overbuild.

### TASK-065 — Full manual QA pass

**Blocked on H-022.** Joe runs through the full flow: 50 photos, mix of recent + old, exercise all three swipes + undo + settings changes. Log every bug.

### TASK-066 — Fix bugs from TASK-065

### TASK-067 — `docs/jill-guide.md`

**Spec:** ~1 page, screenshots-heavy. "Open PhotoSwiper → swipe left to delete, swipe right to save, swipe up to send to Joe, tap undo if you mess up." No tech jargon.

### TASK-070 — Onboard Jill's phone

**Blocked on H-011.** Same physical steps as Joe's onboarding, plus first-launch settings (Immich URL is the same; she gets her own API key from her own Immich account if Joe set one up for her — otherwise reuse Joe's).

### TASK-080 — Verify auto-refresh after 7+ days

**Spec:** Wait. Check both phones can still launch the app. If gray-icon scenario: AltStore on phone → tap Refresh → done.

### TASK-090 — Retrospective

**Spec:** Write a short retro in `docs/retro.md`. What worked, what didn't, what would Joe do differently. Then we either keep maintaining (TASK-100+) or archive.

---

## Self-review (done 2026-05-24)

**Spec coverage:**
- ✓ Left swipe deletes from phone
- ✓ Right swipe uploads to Immich; >1yr also deletes from phone (TASK-047)
- ✓ Up swipe shares via Messages (TASK-031/035)
- ✓ Undo button (TASK-036)
- ✓ Random + chronological order setting (TASK-026/027)
- ✓ Two-user install (Joe Phase 1-4, Jill TASK-070)
- ✓ No-cost path (all decisions in DECISIONS.md, no paid services)
- ✓ AI-orchestratable (orchestration files, BACKLOG-driven workflow)

**Placeholder scan:**
- Phase 2+ tasks intentionally use spec-format not full-code-format. This is documented in the plan intro as a deliberate choice — over-specifying iOS code I haven't built against would create fiction. The implementing subagent writes the Swift body while looking at real build output. **Not a placeholder failure; an honest scope.**

**Type consistency:**
- `PhotoFetcher`, `CardStack`, `SwipeCard`, `Settings`, `AppState`, `UndoStack`, `ImmichClient`, `KeychainStore`, `DeleteAction`, `ShareAction`, `Toast` — all defined in architecture.md, all referenced consistently across tasks.
- `Direction` enum (`.left | .right | .up`) referenced in TASK-024, used in TASK-025/034/035/046 — consistent.
- `Settings.Order` enum (`.random | .oldestFirst`) referenced in TASK-022/026 — consistent.

No issues found. Plan complete.

---

## Execution mode

**Default:** When Joe says "do next chunk," agents should use `superpowers:subagent-driven-development` to dispatch fresh subagents per task, with the orchestration files (`BACKLOG.md`, `STATE.md`) serving as the persistent state across subagent runs.

For multi-task "fan out" requests, dispatch in parallel where tasks are independent (most Phase 2 tasks are; most Phase 1 tasks are not — they form a chain).
