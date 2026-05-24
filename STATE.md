# STATE

> **Read me first.** Snapshot of where the project is right now.
> Update this in every commit that changes status.

## Current phase

**Phase 0 wrapping up → Phase 1 starting.** All human-blocked setup complete on 2026-05-24. Code work begins.

## Last completed task

`TASK-005` — Joe confirmed AltStore launches cleanly on his iPhone. All of Phase 0's Joe-blocked items are done (H-001, H-003, H-004, H-005, H-006, H-007, H-008, H-009, H-010, plus newly-discovered H-012).

## Next task

`TASK-001` in progress this commit — git repo initialized, `.gitignore` written, orchestration state updated.

**After this commit lands:** TASK-002 (push to GitHub — first push will fire Windows Credential Manager dialog; Joe pastes fresh PAT). Then the Phase 1 build pipeline batch can run in series (TASK-006 → TASK-007 → TASK-008 → TASK-009 → TASK-010 → TASK-012 → TASK-013 → TASK-014).

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
