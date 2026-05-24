# BACKLOG

> Ordered task list. Agents pick the next unblocked `- [ ]` task.
> Update status in same commit as the work.
> Discovered work → new `TASK-NNN` at the right point in order (or appended).

## Status legend
- `- [ ]` = todo
- `- [~]` = in progress (one agent only — claim it before starting)
- `- [!]` = blocked (must reference what's blocking, usually an H-NNN or BUG-NNN)
- `- [x]` = done (link the commit SHA)

## Task ID convention
- `TASK-NNN` — numbered sequentially, never reused, gaps are fine.
- Reference detailed task spec in `docs/plan.md#task-NNN`.

---

## Phase 0 — Foundations

- [x] **TASK-001** — Initialize local git repo and `.gitignore` (Xcode + macOS + Swift). *Done 2026-05-24, commit `e664014`.*
- [x] **TASK-002** — Push initial scaffold to GitHub. *Done 2026-05-24, pushed `e664014` → `origin/main`. (Credential manager had GitHub creds cached, no dialog needed.)*
- [x] **TASK-003** — Flesh out `docs/setup-guide.md` with AltServer + AltStore install steps. *Done 2026-05-24. Includes iTunes nag (BUG-001), Developer Mode (H-012), Immich API key flow, maintenance procedures.*
- [x] **TASK-004** — Confirm Joe has installed AltServer + iTunes on JARVIS. *Done 2026-05-24.*
- [x] **TASK-005** — Confirm Joe has AltStore on his phone. *Done 2026-05-24 (after Developer Mode toggle; see H-012).*

## Phase 1 — Build pipeline (Hello World end-to-end)

- [x] **TASK-006** — Write `project.yml` (XcodeGen spec) for a Hello-World SwiftUI app targeting iOS 17. *Done 2026-05-24. Test target deferred to TASK-023 (YAGNI).*
- [x] **TASK-007** — Write `Sources/App/Info.plist` with bundle ID `com.joehill.photoswiper`. *Done 2026-05-24.*
- [x] **TASK-008** — Write `Sources/App/PhotoSwiperApp.swift` — `@main` entry. *Done 2026-05-24.*
- [x] **TASK-009** — Write `Sources/App/ContentView.swift` — placeholder "PhotoSwiper" text. *Done 2026-05-24.*
- [x] **TASK-010** — Write `.github/workflows/build.yml` — installs XcodeGen, generates project, runs `xcodebuild archive`, produces unsigned `.ipa`, uploads as workflow artifact, AND creates GitHub Release on push to main (folded TASK-011 into here per plan note). *Done 2026-05-24.*
- [x] **TASK-011** — ~~Separate release.yml~~ folded into `build.yml` per plan, no separate file. *Done 2026-05-24.*
- [x] **TASK-012** — Write `altstore-source.json` — AltStore source manifest pointing at GitHub Releases. *Done 2026-05-24. URLs use joehill-techprojects/photo-swiper. iconURL points at future asset path (will 404 until TASK-060 lands the real icon — AltStore tolerates this).*
- [x] **TASK-013** — First push, watch CI go green. *Done 2026-05-24, commit `890237b`. Two CI failures before success: BUG-002 (macos-14 Xcode 15.4 too old for XcodeGen objectVersion 77 → bumped to macos-15), BUG-003 (cd persistence in heredoc broke ls path → subshell fix).*
- [x] **TASK-014** — Verify IPA downloads correctly from the latest GitHub Release URL. *Done 2026-05-24. Release `v0.1.20260524153920` has `PhotoSwiper.ipa` attached, 8599 bytes (expected for Hello World).*
- [x] **TASK-015** — Tell Joe (via HUMAN-TODO H-020): add `altstore-source.json` URL to AltStore on phone, install PhotoSwiper, launch it. *Done 2026-05-24, four attempts before success: H-013 (repo private), Wi-Fi-sync-not-enabled, BUG-004/BUG-005 (signing red herrings, fixed but not the blocker), BUG-006 (actual blocker — v1 source schema). Joe enabled Wi-Fi sync in iTunes during this so future refreshes are fully wireless.*
- [x] **TASK-016** — Confirm Hello-World launches on Joe's phone. *Done 2026-05-24. Joe's screenshot confirmed: app installed, generic placeholder icon, launches to expected ContentView ("PhotoSwiper" + "Build pipeline alive ✓").*

## Phase 2 — Photo browsing core

- [x] **TASK-021** — Add `NSPhotoLibraryUsageDescription` and `NSPhotoLibraryAddUsageDescription` to Info.plist. *Done 2026-05-24.*
- [x] **TASK-022** — Author `Sources/Photos/PhotoFetcher.swift` — wraps `PHAsset` fetch with random + chronological ordering modes. *Done 2026-05-24. Codex pass-1 fixes applied (Order unification with Settings.Order, OptionSet contains() for cloud-shared filter).*
- [x] **TASK-023** — Author `Tests/PhotosTests/PhotoFetcherTests.swift` — unit tests for ordering against an injected asset list. *Done 2026-05-24. Covers authorization gating, PHFetchOptions contract, empty-input orchestration, deterministic seeded RNG. Two cloud-shared / shuffle-of-real-PHAssets tests deliberately XCTSkip'd (require real PHAsset construction, deferred to Phase 5). BUG-007 fix landed (try? → try XCTUnwrap).*
- [x] **TASK-024** — Author `Sources/UI/SwipeCard.swift` — single-photo card with `DragGesture`, exposes `onSwipe(direction)`. *Done 2026-05-24. Codex pass-1 fixes applied (predictedEndTranslation for velocity, AsyncStream-based image loading to eliminate continuation double-resume race, synchronous imageRequestID assignment).*
- [x] **TASK-025** — Author `Sources/UI/CardStack.swift` — deck of 2-3 stacked `SwipeCard`s, pulls next from a stream. *Done 2026-05-24. Renders top 3 with depth offset; ForEach keyed on localIdentifier.*
- [x] **TASK-026** — Author `Sources/State/Settings.swift` — `@Observable` model backed by `UserDefaults`. *Done 2026-05-24. Codex pass-1 fix applied (immichURL load now requires http/https scheme + non-empty host).*
- [x] **TASK-027** — Author `Sources/UI/SettingsView.swift` — toggle between random / oldest-first. *Done 2026-05-24. Form + segmented Picker + About section.*
- [x] **TASK-028** — Author `Sources/State/AppState.swift` — wires `Settings` + `PhotoFetcher` + `CardStack`. *Done 2026-05-24. Also rewrote ContentView.swift to host the new integrated UI. BUG-008 fix landed (nil-sentinel for Settings default param).*
- [x] **TASK-029** — Manual test: launch on Joe's phone, photos appear, can swipe through. *Done 2026-05-24. Joe confirmed deck loads, all four directions register, hints visible (red/green/blue/none), settings reload works. Phase 2 acceptance met. New feature feedback captured as TASK-038 (down = skip). Phantom AltStore update error logged as BUG-011 (non-blocking, update succeeded despite alert).*

## Phase 3 — Actions wired

- [x] **TASK-030** — Author `Sources/Actions/DeleteAction.swift` — wraps `PHAssetChangeRequest.deleteAssets`. *Done 2026-05-24. Wave A subagent. Maps `PHPhotosError.userCancelled` to `DeleteError.userCancelled` so caller skips UndoStack push.*
- [x] **TASK-031** — Author `Sources/Actions/ShareAction.swift` — presents `UIActivityViewController` with the asset image and pre-selected Messages target. *Done 2026-05-24. Wave A subagent. Uses `PHImageManagerMaximumSize` for full-res share; walks `connectedScenes` → `keyWindow` → `presentedViewController` for the topmost presenter.*
- [x] **TASK-032** — Author `Sources/State/UndoStack.swift` — bounded LIFO of swipe events, each with a reverse action closure. *Done 2026-05-24. Wave A subagent. `@MainActor @Observable`; `isEmpty`/`count` are computed off the observed entries array.*
- [x] **TASK-033** — Author `Tests/StateTests/UndoStackTests.swift` — unit tests for push/pop/clear, max-size eviction. *Done 2026-05-24. Wave B subagent. 7 test cases including bounded eviction with maxSize:2 verifying A,B evicted and only D,C run in LIFO order.*
- [x] **TASK-034** — Wire left-swipe in `CardStack` → `DeleteAction` + push to `UndoStack`. *Done 2026-05-24. Integration subagent. `userCancelled` restores card without undo entry; other errors restore + log.*
- [x] **TASK-035** — Wire up-swipe → `ShareAction` + push to `UndoStack`. *Done 2026-05-24. Integration subagent. Undo pushed once share sheet appears regardless of whether user actually sends (per ShareAction's contract).*
- [x] **TASK-036** — Add undo button to the UI, wire to `UndoStack.pop`. *Done 2026-05-24. Integration subagent. Leading toolbar item (`arrow.uturn.backward.circle`), disabled when undoStack.isEmpty.*
- [~] **TASK-037** — Manual test: each gesture works on Joe's phone, undo works. *Joe's first test 2026-05-24 surfaced D-024 (delete model rework). Re-test required after TASK-100..104 ship. Tracked as H-030.*

### Phase 3.1 — Trash-bucket delete model (D-024)

- [x] **TASK-100** — Author `Sources/State/PendingDeleteStore.swift` — `@MainActor @Observable` bucket. *Done 2026-05-24. UserDefaults key `PhotoSwiper.PendingDelete.identifiers`; persist on every mutation; init re-fetches via `PHAsset.fetchAssets(withLocalIdentifiers:options:)` and silently drops unresolvable IDs.*
- [x] **TASK-101** — `PendingDeleteStoreTests.swift`. *Done 2026-05-24. 5 tests covering empty-init, stale-ID init, clear-writes-empty, idempotent clear, key constant stability. PHAsset stubbing skipped — only the persistence layer is tested since real PHAsset can't be constructed in unit tests.*
- [x] **TASK-102** — Refactor `DeleteAction.delete(_:)` to take `[PHAsset]`. *Done 2026-05-24. Empty array short-circuits; non-empty hands `NSArray` to `deleteAssets` for ONE iOS prompt covering the batch.*
- [x] **TASK-103** — Refactor `AppState.handleSwipe` left branch. *Done 2026-05-24. `.left` parks in `pendingDelete` + pushes undo closure that removes from bucket. Added `commitPendingDelete()` (clears bucket + undoStack on success; preserves on cancel/error) and `discardPendingDelete()` (clears both).*
- [x] **TASK-104** — `ContentView` trash toolbar item with badge + confirmationDialog. *Done 2026-05-24. Red capsule count badge overlay on `trash` SF Symbol; `.confirmationDialog` with Delete (destructive) / Discard (destructive) / Cancel.*
- [~] **TASK-105** — Bump to `0.1.3` / build `4`, ship IPA, update altstore-source.json. *In progress 2026-05-24.*
- [ ] **TASK-106** — Re-test on Joe's phone (TASK-037 re-do). Verify: left swipe queues silently, badge increments, undo actually keeps photo in library, batch commit shows ONE iOS prompt, app-quit-then-relaunch preserves bucket. *Tracked as H-031.*
- [x] **TASK-038** — Add `.down` to `SwipeCard.Direction` enum, update `directionForCommit` to detect downward swipes past threshold, add a gray "snooze" hint overlay. Wire AppState to handle `.down` as a no-op skip (just remove from deck, log skipped). Per D-022. *Done 2026-05-24. Part 1 (SwipeCard) inline; part 2 (AppState) via integration subagent.*
- [x] **TASK-039** — Wire `.right` swipe in `AppState.handleSwipe` to a placeholder log (no real action yet — Phase 4 swaps in `ImmichClient.upload`). Card removes from deck as usual. Avoids "right does nothing visible" feeling weird in Phase 3 testing. *Done 2026-05-24. Integration subagent. Per D-023.*

## Phase 4 — Immich integration

- [ ] **TASK-040** — Ask Joe (H-021) for Immich URL + API key, save to DECISIONS.md. *Blocked on H-021.*
- [ ] **TASK-041** — Author `Sources/Immich/KeychainStore.swift` — read/write API key in iOS Keychain. *Depends TASK-037.*
- [ ] **TASK-042** — Author `Sources/Immich/ImmichClient.swift` with `.ping()` — validates server URL is reachable and API key works. *Depends TASK-040, TASK-041.*
- [ ] **TASK-043** — Extend `ImmichClient` with `.upload(asset:)` — uploads a `PHAsset` via the Immich asset-upload endpoint. *Depends TASK-042.*
- [ ] **TASK-044** — Author `Tests/ImmichTests/ImmichClientTests.swift` — unit tests with `URLProtocol` stub. *Depends TASK-043.*
- [ ] **TASK-045** — Extend `SettingsView` with Immich URL + API key fields + a "Test connection" button calling `.ping()`. *Depends TASK-042.*
- [ ] **TASK-046** — Wire right-swipe in `CardStack` → `ImmichClient.upload`. *Depends TASK-043.*
- [ ] **TASK-047** — Add age-check: if `asset.creationDate < now - 365d`, also call `DeleteAction` after upload succeeds. *Depends TASK-046.*
- [ ] **TASK-048** — Manual test: right-swipe uploads, old photos delete after upload, recent photos stay. *Depends TASK-047.*
- [ ] **TASK-049** — Add upload-progress toast + failure toast that re-queues the asset. *Depends TASK-048.*

## Phase 5 — Polish & rollout

- [ ] **TASK-060** — Generate / source app icon (1024×1024 PNG). *No dependencies.*
- [ ] **TASK-061** — Add launch screen. *Depends TASK-060.*
- [ ] **TASK-062** — Add first-launch permission-onboarding flow (Photos + optional contact picker for share target). *Depends TASK-049.*
- [ ] **TASK-063** — Add empty-state view when all photos triaged. *Depends TASK-049.*
- [ ] **TASK-064** — Add lightweight "all done" celebration on session end. *Depends TASK-063.*
- [ ] **TASK-065** — Full manual QA pass on Joe's phone. Log bugs in `BUGS.md`. *Blocked on H-022.*
- [ ] **TASK-066** — Fix all P0/P1 bugs from TASK-065. *Depends TASK-065.*
- [ ] **TASK-067** — Write `docs/jill-guide.md` — short, non-technical instructions for Jill. *Depends TASK-066.*
- [ ] **TASK-070** — Onboard Jill's phone (sideload via H-011). *Blocked on H-011.*
- [ ] **TASK-080** — After ~10 days, verify AltServer auto-refresh worked on both phones. *Depends TASK-070.*
- [ ] **TASK-090** — Retrospective: what's worth keeping, archive the rest. *Depends everything above.*

---

## Discovered / unscheduled

_Agent-discovered work goes here until placed in phase order. Bugs from BUGS.md mirror here as `TASK-1XX`._
