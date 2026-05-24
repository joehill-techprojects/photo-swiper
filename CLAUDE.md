# photo-swiper

Personal side-project: Tinder-style iOS photo curation app for Joe & Jill.

## Concept

- Swipe **left** → delete from phone (iOS "Recently Deleted" is the safety net)
- Swipe **right** → upload to Immich on home NAS; if photo is >1 year old, also delete from phone (storage cleanup)
- Swipe **up** → share to the other person via iMessage (system Messages compose sheet — Apple requires a tap to actually send)
- **Undo** button reverses the last swipe
- Settings: **random** order (default) or **oldest-first**

## Audience

Two users only: Joe and Jill. Same household, same WiFi. Will never be published to the App Store. Likely heavily used for two weeks then abandoned — code investment should match.

## Boundary

Personal project. Not ClickTime. Lives in `C:\workspace` per personal-workspace conventions. If anything starts to feel like ClickTime work, stop and tell Joe.

## How agents work this project

This project is structured for **autonomous AI orchestration**. Joe's expected workflow is:

1. Joe: "Do next chunk of work."
2. Agent: reads `STATE.md` + `BACKLOG.md`, says "next steps are L, M, N, O, P."
3. Joe: "Fan out, do them all, merge."
4. Agent: dispatches subagents, merges results, updates orchestration files, commits.
5. Agent self-logs bugs in `BUGS.md`, adds them to `BACKLOG.md`, continues.
6. Joe is asked for input ONLY when truly blocked (account creation, plugging a phone in, design decisions).

### Orchestration files (project root — read these first every session)

| File | Purpose |
|---|---|
| `STATE.md` | Current phase, last completed task, next task ID, active blockers. **Read first.** |
| `BACKLOG.md` | Ordered task list, checkboxes for status. **Pick next unblocked `- [ ]` task.** |
| `BUGS.md` | Bug log. New bugs go here as `BUG-NNN` and get added to `BACKLOG.md` as tasks. |
| `HUMAN-TODO.md` | Things only Joe can do (create accounts, plug in phone, install software). If blocked on Joe, add here and skip the task. |
| `DECISIONS.md` | Locked-in product & architecture decisions. **Read before designing anything.** |

### Reference docs

| File | Purpose |
|---|---|
| `docs/plan.md` | Master end-to-end implementation plan, phase-by-phase. |
| `docs/architecture.md` | App structure, file responsibilities, framework choices. |
| `docs/setup-guide.md` | Manual setup steps for Joe (AltStore install, etc.). |

### Workflow rules for agents

1. **Always update orchestration files** in the same commit as the work they describe. Stale state is worse than no state.
2. **Status values** in BACKLOG/HUMAN-TODO: `- [ ]` = todo, `- [~]` = in progress, `- [!]` = blocked, `- [x]` = done.
3. **Discovered work goes in BACKLOG**, not silently into the current task. If you find something out of scope, add it as a new `TASK-NNN` entry.
4. **Bugs go in BUGS.md first**, then mirror as a `TASK-NNN` in BACKLOG so they get scheduled.
5. **Commit frequently** — every completed task. Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`).
6. **Never invent product/architecture decisions silently** — write them in DECISIONS.md with a one-line rationale.
7. **TDD where testable.** Unit tests for non-UI logic (Immich client, undo stack, filters). PhotoKit / SwiftUI tested manually on device.

### What Joe will NOT do

- Read plans, code, or docs
- Triage bugs (agents triage; Joe approves direction shifts)
- Make implementation decisions ("which library" is your call)

### What Joe WILL do (only when explicitly asked)

- Create accounts (Apple ID, GitHub repo)
- Plug iPhone into JARVIS for one-time AltStore install
- Run the app and report what's broken
- Approve direction shifts when something is non-obviously wrong

## Build pipeline (no Mac on JARVIS, no Apple Developer account)

- Swift source lives in this repo
- **XcodeGen** generates the `.xcodeproj` from `project.yml` (so we never check in the Xcode project file)
- **GitHub Actions** (free `macos-14` runner) does `xcodebuild archive` → unsigned `.ipa`
- IPA uploaded to a GitHub Release on every push to `main`
- **AltStore** on each iPhone (refreshed by **AltServer** running in JARVIS's system tray) downloads the IPA and re-signs it locally with a free Apple ID — gives a 7-day install that AltServer silently re-signs whenever the phone is on home WiFi

See `DECISIONS.md` for the why behind each choice.

## Tech stack

- **Language:** Swift 5.10+, **SwiftUI**, iOS 17+
- **Build:** XcodeGen + xcodebuild on GitHub Actions
- **Distribution:** AltStore + AltServer; GitHub Releases hosts the IPA
- **Photos:** PhotoKit (Apple native, no third-party)
- **Networking:** URLSession (no third-party)
- **Immich:** REST API on home NAS (see `DECISIONS.md` for URL)
- **Secrets:** iOS Keychain (Immich API key), UserDefaults (non-sensitive settings)
