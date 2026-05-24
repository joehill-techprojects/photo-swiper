# STATE

> **Read me first.** Snapshot of where the project is right now.
> Update this in every commit that changes status.

## Current phase

**Phase 1 complete → Phase 2 ready to start.** Hello World launches on Joe's phone via the full pipeline. From here, every commit ships an IPA automatically; Joe just refreshes in AltStore when he wants the latest.

## Last completed task

`TASK-016` — Joe confirmed PhotoSwiper installs and launches on his iPhone 2026-05-24.

## Next task

**Phase 2 — Photo browsing core.** Real app work begins. Tasks fan out into mostly-independent components:

- `TASK-021` — small Info.plist edit to add photo permission descriptions (prerequisite for everything else)
- `TASK-022` — `PhotoFetcher` service (PhotoKit wrapper, random + chronological ordering)
- `TASK-024` — `SwipeCard` view (single card + DragGesture)
- `TASK-026` — `Settings` model (`@Observable`, UserDefaults-backed)
- `TASK-023` — `PhotoFetcher` unit tests
- `TASK-025` — `CardStack` view (deck of 2-3 SwipeCards)
- `TASK-027` — `SettingsView` (order toggle)
- `TASK-028` — `AppState` (wires Settings + PhotoFetcher + CardStack)
- `TASK-029` — Joe installs and manually tests on phone

Fan-out is genuinely valuable here: 022/024/026 are independent; 023/025/027 each depend on one of those. Recommend subagent-per-component dispatch.

## Active blockers

None.

## High-level progress

- [x] Phase 0 — Foundations
- [x] Phase 1 — Build pipeline
- [ ] Phase 2 — Photo browsing core
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
