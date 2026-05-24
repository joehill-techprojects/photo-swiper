# STATE

> **Read me first.** Snapshot of where the project is right now.
> Update this in every commit that changes status.

## Current phase

**Phase 2 complete → awaiting Joe's manual test on phone.** All code shipped through CI (final build `ac9160c`, IPA in latest GitHub Release).

## Last completed task

`TASK-028` — AppState integration + ContentView rewrite. CI green after fixes for BUG-007 (test syntax) and BUG-008 (main-actor isolation default param).

## Next task

`TASK-029` — Joe opens AltStore, refreshes "Joe's Personal Apps" source, installs/updates PhotoSwiper, launches, runs through:
- iOS shows photo permission prompt → Allow Access to All Photos
- Photos appear in a swipeable deck (no actions wired yet — Phase 3)
- Drag left/right/up and see the colored hint overlays; release past threshold flies the card off, deck shifts up
- Tap the gear icon (top right) → Settings sheet, toggle between Random and Oldest first, dismiss → deck reloads in new order

After Joe reports back with anything broken, fix → Phase 3 (wire delete/share/undo to those swipes).

## Active blockers

`TASK-029` — Joe-only manual test.

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
