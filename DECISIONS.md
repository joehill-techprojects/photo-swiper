# DECISIONS

> Locked-in product & architecture decisions. Read before designing.
> New decisions get appended with date + one-line rationale.
> If a decision needs to change, mark the old entry `~~SUPERSEDED~~` and add a new one — don't edit history.

---

## 2026-05-24 — Initial decisions

### D-001 — App working name: `PhotoSwiper`

Code identifier, marketing name is TBD. Joe can rename the visible app name later without touching the bundle ID.

### D-002 — Bundle ID: `com.joehill.photoswiper`

Reverse-DNS with Joe's domain placeholder. Free Apple ID supports up to 10 unique bundle IDs at a time.

### D-003 — iOS minimum target: 17.0

Both phones in the household run iOS 17+. Lets us use modern SwiftUI (`Observable`, `NavigationStack`).

### D-004 — UI framework: SwiftUI only

No UIKit unless forced by a specific API. Smaller code, faster iteration, modern-only target.

### D-005 — Build system: XcodeGen

`project.yml` in repo → `xcodegen generate` produces `.xcodeproj` on CI. `.xcodeproj` is `.gitignore`'d. Avoids merge hell and means no Mac is needed locally to edit project settings.

### D-006 — CI: GitHub Actions `macos-14` runners (free tier)

Free for public repos and 2000 min/month on private. We won't come close to the limit.

### D-007 — Signing: unsigned in CI, AltStore re-signs locally

No Apple Developer account ($99/yr) needed. `xcodebuild` produces an unsigned `.ipa`. AltStore on each iPhone re-signs with the user's free Apple ID at install time. Trade-off: app expires every 7 days and AltServer must refresh it (silent, on home WiFi).

### D-008 — Distribution: GitHub Releases consumed by AltStore source

Every push to `main` creates a tagged release with the IPA attached. AltStore is pointed at a JSON source file in the repo (`altstore-source.json`) that lists releases. One-tap install/update from inside AltStore.

### D-009 — Photos: PhotoKit (no third-party)

`PHPhotoLibrary` for fetch + delete. Standard Apple framework. No alternatives worth considering.

### D-010 — Networking: URLSession (no third-party)

For Immich API calls and IPA-related HTTP. Zero dependencies makes builds fast and audits trivial.

### D-011 — Immich server URL: `http://192.168.1.20:2283`

NAS static IP per home LAN topology. **NEEDS VERIFICATION** — confirm during Phase 4 by hitting `/api/server-info/ping`. User-configurable in app settings, this is just the default.

### D-012 — Immich auth: API key in iOS Keychain

User pastes API key once in Settings. Keychain so it survives reinstall and isn't readable by other apps. Generated from Immich web UI under Account Settings → API Keys.

### D-013 — Non-sensitive settings: UserDefaults

Order mode (random/oldest), share-target contact, last-shown asset id for resume-on-launch. Survives reinstall via iCloud backup.

### ~~D-014 — Repo: GitHub, private, name TBD~~ **SUPERSEDED 2026-05-24 by D-021.**

Joe picks the name when he creates it. Private so the IPA / source isn't world-readable (AltStore-source-as-JSON is the only public surface, served via raw.githubusercontent.com which works for private repos via PAT-signed URLs — alternative is to make it public).

### D-021 — Repo: GitHub, **public**, `joehill-techprojects/photo-swiper`

**Supersedes D-014.** AltStore cannot authenticate to GitHub when pulling the source JSON or IPA — it makes anonymous requests. A private repo returns 404. We considered a public-proxy-repo workaround but rejected it as extra maintenance for a hobby project. Joe flipped the repo to public 2026-05-24.

Security implications considered: no secrets in the repo (PAT lives in Windows Credential Manager only, Immich API key only on devices), the Immich server URL `192.168.1.20:2283` is a private LAN IP useless from outside Joe's house, code is hobby-level and Joe is fine with it being world-readable.

### D-015 — Testing strategy: unit-test pure logic, manual-test UI

Unit tests on CI for: Immich client (mocked URLSession), UndoStack, photo-age filter, settings model. SwiftUI views and PhotoKit interaction are tested manually on device — automation would cost more than the project is worth.

### D-016 — License: none (private personal use)

Repo private, no license needed.

### D-017 — Logging: `os.Logger` (Apple unified logging)

Visible in Console.app over USB. Cheap, structured, zero dependencies. Each subsystem gets its own logger.

### D-018 — Error UX: non-blocking toast on failure, no modal dialogs

The app should feel fun. A failed upload shows a brief toast and re-queues the asset. Never a confirm/cancel popup.

### D-019 — Conflict policy for Immich uploads: skip duplicates by checksum

Immich's `/api/asset/upload` endpoint already deduplicates by SHA1. We trust that and surface the response as a no-op on the client side.

### D-020 — Age threshold for "old enough to also delete": 365 days

Exactly one calendar year before today, in the device's local timezone. User-configurable later if anyone cares.

---

## 2026-05-24 — Phase 2 retrospective decisions

### D-022 — Down swipe = "skip / I'll get to it later" (no action)

Joe added this during Phase 2 manual testing. Pre-D-022 behavior was "down swipe is treated as cancel (card springs back)." New behavior: down swipe past threshold is a fourth swipe action that just discards the card from the deck without performing any side effect — leaves the photo on the device, doesn't upload, doesn't share.

Implementation in TASK-038: extend `SwipeCard.Direction` enum with `.down`, update `directionForCommit`, add gray clock/snooze hint overlay, wire AppState.handleSwipe to handle `.down` as a no-op log+remove-from-deck.

### D-023 — Right swipe in Phase 3 = placeholder log (no real upload)

`ImmichClient.upload` lands in Phase 4. Until then, right swipe in Phase 3 mirrors down — log "would upload" and remove from deck — rather than leaving right swipe as a silent no-op. Otherwise testing Phase 3 with three different-feeling directions (left destructive, up shares, right & down silent) is unnecessarily confusing.

---

## 2026-05-24 — Phase 3 retrospective decisions

### D-024 — Left swipe = "queue for batch delete" (not immediate delete)

Joe's Phase 3 test (TASK-037) surfaced two product problems:

1. **Undo didn't actually undelete the photo** — the original design (D-018 implied) treated the iOS confirmation sheet as the safety net and undo just restored the card to the deck. The photo was already in Recently Deleted; undo only un-removed the card. User-hostile.
2. **iOS demands a confirmation tap per `PHAssetChangeRequest.deleteAssets` call.** That's an Apple privacy guarantee — no third-party app can bypass it. At 50K photos × N% delete rate, tapping confirm 30,000 times destroys the value prop ("don't make me tap").

**Resolution: switch to a "pending delete" bucket model.** PhotoKit's `deleteAssets` accepts an `NSArray` of N assets and shows **one** confirmation for the whole batch. We exploit that.

- Left swipe → asset goes into in-memory `PendingDeleteStore`. Card leaves the deck. **No iOS prompt fires.**
- Undo → asset comes back out of the bucket and onto the top of the deck. Photo never left the library — undo is real.
- New toolbar trash badge `🗑 N` shows the pending count. Disabled when empty.
- Tap the badge → action sheet: "Delete N photos" (destructive) / "Discard pending" / Cancel.
- "Delete" calls `PHAssetChangeRequest.deleteAssets(pendingArray as NSArray)` → iOS shows ONE prompt → on confirm, all N go to Recently Deleted; on cancel, bucket stays intact for retry.
- "Discard pending" empties the bucket; photos stay in library.
- The bucket is **persisted to UserDefaults** as an array of `localIdentifier` strings, so an impromptu app quit doesn't lose pending deletes. On launch, identifiers that no longer resolve (manually deleted in Photos.app, etc.) are silently dropped.

Why not auto-commit on app background, or at a threshold count? Backgrounding is involuntary too often (calls, notifications, swipe-up), and an iOS prompt can't appear while the app isn't foregrounded. Threshold-based auto-prompt interrupts swipe flow. Manual control with persistence is the right floor.

Right / up / down swipes are unaffected — those undo paths (D-022, D-023, share) still just push reverse closures onto `UndoStack`.

**Supersedes** the relevant portion of D-018's "rely on the system prompt" implication for the left swipe. D-018 still governs error-toast UX for failed actions (upload retry, share failure, etc.).
