# STATE

> **Read me first.** Snapshot of where the project is right now.
> Update this in every commit that changes status.

## Current phase

**Phase 0 complete → Phase 1 ready to start.** All Joe-blocked setup landed 2026-05-24. Scaffold committed (`e664014`) and pushed to `origin/main`.

## Last completed task

`TASK-002` — pushed scaffold commit `e664014` to `https://github.com/joehill-techprojects/photo-swiper` on `main`. TASK-001 and TASK-002 both done.

## Next task

**Phase 1 file-authoring batch** (all small, all documented in `docs/plan.md`):

1. `TASK-003` — flesh out `docs/setup-guide.md` with AltServer/AltStore walkthrough + iTunes nag + Developer Mode gotchas (now that we have first-hand evidence of all of them)
2. `TASK-006` — write `project.yml` (XcodeGen spec)
3. `TASK-007` — write `Sources/App/Info.plist`
4. `TASK-008` — write `Sources/App/PhotoSwiperApp.swift`
5. `TASK-009` — write `Sources/App/ContentView.swift`
6. `TASK-010` — write `.github/workflows/build.yml` (CI build + release-on-main)
7. `TASK-012` — write `altstore-source.json` (substituted with `joehill-techprojects/photo-swiper`)
8. `TASK-013` — commit, push, watch CI go green (iterate on failures)

Then `TASK-014` (verify IPA in Release) and `TASK-015` (Joe adds source URL to AltStore on phone, installs Hello World, reports back).

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
