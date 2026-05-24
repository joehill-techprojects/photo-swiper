# HUMAN-TODO

> Things only Joe can physically do. Agents add to this when they hit a Joe-only blocker.
> Joe checks off items as he does them.
> Each item links to the BACKLOG task it unblocks.

## Status legend
- `- [ ]` = waiting on Joe
- `- [x]` = done

---

## Pre-coding setup (unblocks Phase 0 → Phase 1)

### Accounts

- [x] **H-001** — Apple ID confirmed (Joe's personal). Used to sign into AltServer for sideloading. *Done 2026-05-24.*
- [ ] **H-002** — Have Jill's Apple ID credentials ready (her own personal one). Same thing — no purchase, just need to sign in to AltStore on her phone when we get to Phase 5. *Unblocks: TASK-070 (Phase 5)*
- [x] **H-003** — Private GitHub repo created at `https://github.com/joehill-techprojects/photo-swiper`. *Done 2026-05-24.*
- [x] **H-004** — Fine-grained PAT generated, scoped to `photo-swiper` repo with Contents + Workflows read/write, cycled after initial leak, now stored in Windows Credential Manager via `git config --global credential.helper manager`. *Done 2026-05-24.*

### JARVIS tooling (one-time)

- [x] **H-005** — iTunes for Windows installed (lives at `C:\Program Files\iTunes\`, not the AltServer-default `C:\Program Files (x86)\iTunes\` — causes harmless path-nag, see `BUGS.md` BUG-001). *Done 2026-05-24.*
- [x] **H-006** — AltServer installed, tray icon visible. *Done 2026-05-24.*
- [x] **H-007** — "Automatically Launch at Startup" verified checked in AltServer tray menu. *Done 2026-05-24.*

### Joe's iPhone

- [x] **H-008** — iPhone trusted JARVIS via USB. *Done 2026-05-24.*
- [x] **H-009** — AltStore installed from AltServer → iPhone, signed in with Apple ID. *Done 2026-05-24.*
- [x] **H-010** — Developer profile trusted in Settings → General → VPN & Device Management. *Done 2026-05-24.*
- [x] **H-012** — iOS Developer Mode enabled (Settings → Privacy & Security → Developer Mode → toggle on → restart phone → confirm on boot). **Required for iOS 16+ to launch any sideloaded app**, including AltStore itself. *Done 2026-05-24.* **Flag for Jill in TASK-070.**

### Jill's iPhone (deferred to Phase 5)

- [ ] **H-011** — Repeat H-008 / H-009 / H-010 / **H-012** on Jill's phone (Phase 5 — agent will tell you when). Make sure Developer Mode is on or AltStore will install but refuse to launch with the misleading "Developer mode required" message.

---

## During development (Joe-blocking moments to expect)

- [x] **H-013** — Repo flipped to PUBLIC. *Done 2026-05-24.*
- [ ] **H-020** — Test the first Hello World IPA. Agent will tell Joe: "open AltStore, tap the source, install PhotoSwiper, then launch it. Tell me what you see." *Triggered by: TASK-015.*
- [ ] **H-021** — Confirm Immich URL + generate an API key on the Immich web UI. Paste both into the agent's chat. *Triggered by: TASK-040*
- [ ] **H-022** — Manual testing of the full swipe loop on Joe's phone before Jill onboards. *Triggered by: TASK-065*

---

## Ongoing maintenance (after rollout)

- [ ] **H-100** — If you leave home for >7 days, the app icon will gray out. Come home, open AltStore on your phone, tap Refresh. Done.

---

## Adding new items

Format: `H-NNN` (next free number), one-line description, what it unblocks. Keep it skimmable — Joe shouldn't have to read paragraphs.
