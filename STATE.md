# STATE

> **Read me first.** Snapshot of where the project is right now.
> Update this in every commit that changes status.

## Current phase

**Phase 1 nearly done.** All file authoring committed (`536dd24`), CI green after two fixes (`448b341`, `890237b`), first IPA published as GitHub Release `v0.1.20260524153920`. **Blocked at TASK-015 on a repo-visibility decision (H-013).**

## Last completed task

`TASK-014` — verified `PhotoSwiper.ipa` (8.6 KB) is attached to the latest GitHub Release.

## Next task

`TASK-015` is **blocked** on `H-013` (repo visibility decision). AltStore can't authenticate to GitHub, so the source JSON + IPA need a public URL. Joe must either:

- Flip the repo to public (one click, recommended — nothing sensitive in it), **OR**
- Accept a separate public proxy-repo workaround (more work, agent will implement if Joe says no to public)

Once unblocked, TASK-015 → TASK-016 (Joe installs + reports back). That closes Phase 1.

## Active blockers

`H-013` — repo visibility decision (Joe-only).

## High-level progress

- [x] Phase 0 — Foundations
- [~] Phase 1 — Build pipeline (TASK-001..014 done; TASK-015/016 awaiting Joe + H-013)
- [ ] Phase 2 — Photo browsing core
- [ ] Phase 3 — Actions wired
- [ ] Phase 4 — Immich integration
- [ ] Phase 5 — Polish & rollout

## Notes for next agent

- CI is now reliable on macos-15 with the subshell-cd fix.
- Build produces `PhotoSwiper.ipa` at `https://github.com/joehill-techprojects/photo-swiper/releases/latest/download/PhotoSwiper.ipa` — that URL works once the repo is public.
- Two new bug entries (BUG-002, BUG-003) both already fixed — kept for institutional memory.

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
