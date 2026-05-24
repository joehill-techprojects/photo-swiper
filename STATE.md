# STATE

> **Read me first.** Snapshot of where the project is right now.
> Update this in every commit that changes status.

## 👋 Session resume checklist (for a fresh agent picking up cold)

You're inheriting this project mid-flight. Do these in order:

1. **Read `CLAUDE.md`** — agent workflow rules, file conventions
2. **Read this file** (you're here) — current status
3. **Read `DECISIONS.md`** — especially the new D-022 (down=skip) and D-023 (right=placeholder)
4. **Read `BACKLOG.md`** — find tasks marked `- [ ]` in Phase 3 and below
5. **Skim `BUGS.md` "Active bugs"** section — there's one open bug (BUG-011, non-blocking)
6. **Skim recent `git log --oneline -20`** to see what shipped today

Then ask Joe what chunk to start. **Default next chunk is Phase 3** (plan in "Next task" below). Don't auto-fan-out without his "go" — he likes the propose→confirm→execute cycle.

## Current phase

**Phase 3 code complete → awaiting CI green, then Joe's manual test (TASK-037 / H-030).** All five Phase 3 implementation tasks landed in one session via Wave A (DeleteAction / ShareAction / UndoStack — 3 parallel subagents), Wave B (UndoStackTests), and an integration subagent (AppState wiring + ContentView undo button). SwipeCard `.down` direction landed inline.

## Last completed task

`TASK-030..036`, `TASK-038`, `TASK-039` — all Phase 3 code merged in one commit. Only TASK-037 (Joe's manual test on phone) remains.

## Next task

**Once CI passes:**

1. Update `altstore-source.json` (see "When shipping Phase 3 IPA" below).
2. Tell Joe (H-030) to refresh source + tap Update.
3. Joe runs through delete / share / undo / skip / right-placeholder on phone.

If Joe finds bugs, log them in BUGS.md as BUG-NNN and mirror as TASK-1NN in BACKLOG.md.

**After Phase 3 acceptance → Phase 4 (Immich integration).** First step is H-021 (Joe pastes Immich URL + API key).

## Active blockers

- CI must complete before manifest update (need new release tag + IPA size). Watching `gh run watch` after push.

## High-level progress

- [x] Phase 0 — Foundations
- [x] Phase 1 — Build pipeline
- [x] Phase 2 — Photo browsing core
- [~] Phase 3 — Actions wired (code done, awaiting Joe's test)
- [ ] Phase 4 — Immich integration
- [ ] Phase 5 — Polish & rollout

## Notes for next agent

### State of the world

- **Joe's iPhone has v0.1.1 installed.** v0.1.2 ships Phase 3: left=delete (iOS confirms), right=placeholder log (Phase 4 swaps to Immich), up=share sheet, down=skip, undo button in top-left.
- **Build pipeline is rock solid.** ~3-5 min per CI run on macos-15. Manifest/markdown changes are in `paths-ignore` so they DON'T trigger builds.
- **AltStore source URL** (give Joe if he ever needs it again): `https://raw.githubusercontent.com/joehill-techprojects/photo-swiper/main/altstore-source.json`
- **AltStore source uses pinned direct URLs** (not `/releases/latest/`) so the URL stays stable across our manifest updates. The pinned tag is `v0.1.20260524180218`. Bump this when releasing Phase 3.

### When shipping Phase 3 IPA

1. Bump `MARKETING_VERSION` in `project.yml` from `0.1.1` → `0.1.2`. Bump `CURRENT_PROJECT_VERSION` from `2` → `3`.
2. Commit Phase 3 code. CI runs, produces new IPA with new tag.
3. Update `altstore-source.json`:
   - Bump `version` from `0.1.1` to `0.1.2` (TWO places: app-level and inside `versions[]`)
   - Update both `downloadURL` fields to the new pinned tag (look at `gh release list --limit 1` after CI completes)
   - Update `size` to new IPA byte count (`gh release view --json assets --jq '.assets[].size'`)
   - Bump `versionDate`, `versionDescription`, `localizedDescription`
4. Commit the manifest update — won't trigger CI (paths-ignore) so the IPA-vs-manifest pairing stays consistent.
5. Tell Joe to refresh source in AltStore + tap Update.

### Known gotchas

- **BUG-010 (FIXED):** First launch needs the in-app `PHPhotoLibrary.requestAuthorization` call (lives in `AppState.loadInitial`). Don't remove it. Phase 5 TASK-062 will replace with a proper `PermissionView`.
- **BUG-011 (OPEN, non-blocking):** AltStore Classic shows a phantom "Update PhotoSwiper Failed: unknown tag html on line 1" error popup during the update flow — but the update actually succeeds. User dismisses the alert and the new version is installed. Workaround documented in BUGS.md. Worth diagnosing eventually (something AltStore Classic fetches during update specifically, not during install).
- **Codex review tooling was deadlocked this session** (pass 2+ stuck in "starting" phase forever). A fresh session should have a clean codex runtime. If it deadlocks again, fall back to own-review + CI.

### Phase 3 fan-out plan (already in "Next task" above)

Subagent prompts will need to:
- Reference D-022 / D-023 explicitly so behavior matches Joe's expectations
- TASK-038 specifically extends `SwipeCard.Direction` enum (currently `.left | .right | .up`) to add `.down` — this is a wider change than the spec implied. Also updates `directionForCommit` to commit on down past threshold (currently down returns nil/cancel).
- TASK-030 (DeleteAction) wraps `PHAssetChangeRequest.deleteAssets` — iOS shows its own system confirmation, that's the desired safety net per architecture.md error policy. Don't add another confirm layer.
- The integration subagent for TASK-034/035/036/038-part2/039 will modify AppState.handleSwipe's body — currently has TODO comments for Phase 3 hookpoints. Just replace the TODOs.

### Things that didn't make it into BUGS / BACKLOG but the next agent might want to know

- Subagent observations during wave A flagged two minor issues we didn't fix: (a) `UIScreen.main.scale` in SwipeCard.swift is deprecated in iOS 16+ for multi-scene apps — fine for our 2-user app but worth a P3 cleanup pass eventually; (b) `Settings.swift` immichURL setter doesn't validate (asymmetric with init); URL validation only happens on read. UI layer (SettingsView) should validate before write. Phase 4 TASK-045 (Immich URL field) is the right place to fix.

## High-level progress

- [x] Phase 0 — Foundations
- [x] Phase 1 — Build pipeline
- [~] Phase 2 — Photo browsing core (code done, awaiting Joe's manual test)
- [ ] Phase 3 — Actions wired
- [ ] Phase 4 — Immich integration
- [ ] Phase 5 — Polish & rollout

## Notes for next agent

- Build pipeline is rock solid. `git push` → ~3 min CI → IPA in `/releases/latest/download/PhotoSwiper.ipa`.
- Joe's phone has Wi-Fi sync enabled, so AltServer can refresh wirelessly. No more USB needed.
- AltStore source URL: `https://raw.githubusercontent.com/joehill-techprojects/photo-swiper/main/altstore-source.json` — agents can refresh the AltStore source remotely by Joe pulling-to-refresh in the app.
- All Phase 1 bugs (BUG-002 through BUG-006) are FIXED and kept for institutional memory.
- For TDD: tests run on CI via `xcodebuild test`. Need to re-add the PhotoSwiperTests target to `project.yml` (was deferred in TASK-006).

## Active blockers

None. Phase 1 chain is fully unblocked.

## High-level progress

- [~] Phase 0 — Foundations (TASK-001 in progress, TASK-002/003 next)
- [ ] Phase 1 — Build pipeline (XcodeGen + GitHub Actions + first sideloaded Hello World)
- [ ] Phase 2 — Photo browsing core (PhotoKit fetch, swipe deck UI, settings)
- [ ] Phase 3 — Actions wired (delete, share, undo)
- [ ] Phase 4 — Immich integration (upload, age-based deletion, keychain)
- [ ] Phase 5 — Polish & rollout (icon, onboarding, both phones, Jill docs)

## Notes for next agent

- Repo URL: `https://github.com/joehill-techprojects/photo-swiper`
- GitHub username: `joehill-techprojects`
- PAT lives in Windows Credential Manager (configured via `git config --global credential.helper manager`). First `git push` will fire a GUI dialog asking Joe to paste; subsequent pushes are silent.
- Phase 1 tasks form a chain (each depends on the previous). No fan-out value — execute serially in-session.
- See `BUGS.md` BUG-001 for the harmless iTunes-path nag Joe lives with.
- See `HUMAN-TODO.md` H-012 for iOS Developer Mode requirement (Joe done; flag for Jill's onboarding in TASK-070).
