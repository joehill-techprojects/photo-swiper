# BUGS

> Bug log. Agents add bugs here as they find them, then mirror as a `TASK-NNN` in `BACKLOG.md`.
> Format: `BUG-NNN` | severity | summary | found-in-task | fix-task | status.

## Status legend
- `OPEN` — not yet fixed
- `WIP` — fix in progress
- `FIXED` — fixed in a specific commit (link the SHA)
- `WONTFIX` — accepted as-is with rationale
- `DUPE` — duplicate of another BUG-NNN

## Severity legend
- `P0` — app unusable / data loss risk → drop everything
- `P1` — feature broken but app usable → next-up
- `P2` — annoying / cosmetic
- `P3` — nice to fix eventually

---

## Active bugs

### BUG-002 — [P1] CI build fails: "future Xcode project file format (77)"

- **Found in:** TASK-013 (first CI run, 2026-05-24)
- **Repro:** Push to main → `Build / Archive for device (unsigned)` step fails after ~19s.
- **Error:** `xcodebuild: error: Unable to read project 'PhotoSwiper.xcodeproj'. Reason: The project 'PhotoSwiper' cannot be opened because it is in a future Xcode project file format (77).`
- **Cause:** Homebrew's current XcodeGen emits projects in objectVersion 77 (Xcode 16 format), but the `macos-14` GitHub runner ships Xcode 15.4 which only reads up to objectVersion 56.
- **Fix:** Switched runner to `macos-15` (ships Xcode 16+) in commit (next push).
- **Status:** FIXED — `.github/workflows/build.yml` runner bumped to macos-15.

---

### BUG-001 — [P3] AltServer prompts for iTunes directory on every launch

- **Found in:** TASK-004 (setup, 2026-05-24)
- **Repro:** Launch AltServer → dialog appears asking to locate iTunes installation directory.
- **Expected:** AltServer auto-finds iTunes (it does when iTunes is installed at `C:\Program Files (x86)\iTunes\`).
- **Actual:** AltServer prompts every launch because Joe's iTunes is at `C:\Program Files\iTunes\` (newer 64-bit installer flavor). Joe picks the directory, AltServer accepts, but doesn't persist the setting.
- **Suspected cause:** AltServer's iTunes-path persistence is broken when the path differs from the historical x86 default. Known upstream quirk.
- **Workaround documented in HUMAN-TODO H-005:** live with the prompt. Functional behavior (phone pairing, AltStore install, app refresh) works fine despite the nag.
- **Optional clean fix:** create a symlink with `New-Item -ItemType SymbolicLink -Path "C:\Program Files (x86)\iTunes" -Target "C:\Program Files\iTunes"` (admin PowerShell). Defer unless the nag becomes painful.
- **Status:** WONTFIX (cosmetic, well-understood, workaround in place).

---

## Fixed / closed

_None yet._

---

## How to log a bug

1. Pick the next free `BUG-NNN`.
2. Write entry in this format under "Active bugs":

```
### BUG-NNN — [P0|P1|P2|P3] one-line summary
- **Found in:** TASK-XXX (or "manual testing by Joe", date)
- **Repro:** numbered steps
- **Expected:** what should happen
- **Actual:** what does happen
- **Suspected cause:** (if any)
- **Fix task:** TASK-YYY (add a corresponding entry to BACKLOG.md)
- **Status:** OPEN
```

3. Add `TASK-YYY` to `BACKLOG.md` with description "fix BUG-NNN: ..."
4. When fixing, link the commit SHA and move the entry under "Fixed / closed".
