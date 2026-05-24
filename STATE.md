# STATE

> **Read me first.** Snapshot of where the project is right now.
> Update this in every commit that changes status.

## Current phase

**Phase 2 complete (TASK-029 done) → Phase 3 ready to start.** Joe's manual test passed: deck loads, swipes register, hints render, settings reload, photo permission prompt fires per BUG-010 fix.

## Last completed task

`TASK-029` — Joe ran through the full Phase 2 flow on his iPhone and confirmed acceptance. New feedback: down swipe should be "skip" (D-022, TASK-038).

## Next task

**Phase 3 — Actions wired.** Subagent fan-out plan:

1. **Inline prep:** TASK-038 (extend Direction enum with `.down`, update SwipeCard hint overlay + gesture detection)
2. **Wave A (parallel, independent files):**
   - TASK-030 — `Sources/Actions/DeleteAction.swift` (PHAssetChangeRequest deletion with iOS confirmation)
   - TASK-031 — `Sources/Actions/ShareAction.swift` (UIActivityViewController, Messages preselected)
   - TASK-032 — `Sources/State/UndoStack.swift` (bounded LIFO with reverse-action closures)
3. **Wave B (parallel):**
   - TASK-033 — `Tests/StateTests/UndoStackTests.swift`
4. **Inline integration:** TASK-034 + TASK-035 + TASK-036 + TASK-038 part 2 + TASK-039 — all touch AppState/ContentView, single subagent
5. **Push, CI, fix**
6. **TASK-037** — Joe tests on phone

After Phase 3: left swipe deletes (iOS confirms), up swipe shares (Messages), down swipe skips, right swipe placeholder (real upload in Phase 4), undo button works.

## Active blockers

None.

## High-level progress

- [x] Phase 0 — Foundations
- [x] Phase 1 — Build pipeline
- [x] Phase 2 — Photo browsing core
- [ ] Phase 3 — Actions wired (next)
- [ ] Phase 4 — Immich integration
- [ ] Phase 5 — Polish & rollout

## Notes for next agent

- Phase 2 surfaced two non-blocking issues: BUG-010 (fixed; first-launch permission prompt added to AppState.loadInitial) and BUG-011 (open; AltStore update flow shows a phantom error popup but update succeeds anyway).
- D-022 (down = skip) and D-023 (right = placeholder in Phase 3) added.
- App at 0.1.1 on Joe's phone. Bump to 0.1.2 in project.yml + altstore-source.json when shipping Phase 3.

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
