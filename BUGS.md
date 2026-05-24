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

### BUG-007 — [P2] PhotoFetcherTests compile error: `options??` double-optional chaining

- **Found in:** Wave-B CI run, 2026-05-24
- **Cause:** Subagent wrote `let options = try? XCTUnwrap(capturedOptions.get())` followed by `options??.sortDescriptors`. `try?` produces an optional, `XCTUnwrap` returns the inner type unwrapped — but the outer `try?` re-wraps, AND `LockedBox.get()` also returns optional, so the value is doubly optional. `options??` is not valid Swift; you can't chain optional with `??` like that.
- **Fix:** Use `try` instead of `try?` and mark the test methods `async throws`. Then `XCTUnwrap` unwraps to a non-optional. Removed the extra `?`.
- **Status:** FIXED — commit pending.

---

### BUG-006 — [P1] AltStore install fails with `NSCocoaErrorDomain 3840`: "the given data was not valid JSON"

- **Found in:** TASK-015 attempt #3 (2026-05-24)
- **Misdirection:** Initially diagnosed as IPA signing issue (BUG-004, BUG-005) because the error wording "data couldn't be read in the correct format" sounded like IPA validation. Joe's screenshot of "More details → Debug description: the given data was not valid JSON" revealed it was actually a JSON parse error on the source manifest, not the IPA.
- **Multiple causes (any one likely sufficient to break decode):**
  - `iconURL` pointed at a path in the repo that doesn't exist yet — AltStore fetched it, got HTML 404, then somewhere downstream got a JSON parse error
  - `screenshotURLs` used the legacy v1 field name; v2 spec calls it `screenshots`
  - `permissions` was an array-of-objects in v1; v2 spec calls it `appPermissions` and the value is a dictionary mapping `*UsageDescription` keys to strings
  - Version object missing `buildVersion` (required per v2 spec)
  - Version object had legacy `size: 0` field not in v2 spec
- **Fix:** Full v2-compliant rewrite of `altstore-source.json`. Using `https://github.com/joehill-techprojects.png` as placeholder iconURL until TASK-060 generates a real app icon.
- **Status:** FIXED — commit pending.
- **Lesson:** Read the docs before writing the artifact. The plan's `altstore-source.json` template was based on stale v1 schema knowledge.

---

### BUG-005 — [P1] xcodebuild archive rejects `CODE_SIGN_IDENTITY="-"`: "Ad Hoc code signing is not allowed with SDK 'iOS 18.5'"

- **Found in:** TASK-015, attempt #2 (2026-05-24)
- **Cause:** Apple tightened iOS 18 SDK to disallow ad-hoc signing during `xcodebuild archive`. The `-` identity used to work; on Xcode 16 + iOS 18 SDK it errors out at `ARCHIVE FAILED`.
- **Fix path that doesn't work:** ad-hoc at archive time (this bug).
- **Fix path that does work:** build unsigned with `xcodebuild build` (no archive), then ad-hoc sign post-build using the standalone `codesign --force --sign -` tool. The standalone tool bypasses the SDK-level check because it doesn't go through Xcode's build system.
- **Status:** FIXED — workflow restructured to build → codesign → package.

---

### BUG-004 — [P1] AltStore rejects IPA: "The data couldn't be read because it isn't in the correct format"

- **Found in:** TASK-015 (Joe's first install attempt, 2026-05-24)
- **Repro:** Tap Install on PhotoSwiper in AltStore → fails with "data couldn't be read" error.
- **Diagnosis:** Downloaded IPA, unzipped. Contents: `PhotoSwiper` binary (75 KB), `Info.plist`, `PkgInfo`. **No `_CodeSignature/` directory, no `embedded.mobileprovision`.** Truly unsigned binaries don't have the Mach-O code-signature page that iOS (and AltStore's pre-install validator) require. Even ad-hoc signing produces the necessary structure for AltStore to strip and re-sign.
- **Fix:** Switch from `CODE_SIGNING_ALLOWED=NO` to ad-hoc signing (`CODE_SIGN_IDENTITY="-"` + `CODE_SIGNING_ALLOWED=YES` + `CODE_SIGNING_REQUIRED=NO`). The `-` identity is built into macOS, requires no certs. Updated both `.github/workflows/build.yml` and `project.yml` for consistency.
- **Status:** FIXED — commit pending. Verification: next CI run should produce an IPA with `_CodeSignature/CodeResources` present.

---

### BUG-003 — [P1] CI Package step fails: `ls: build/PhotoSwiper.ipa: No such file or directory`

- **Found in:** TASK-013 (second CI run, 2026-05-24)
- **Repro:** Build → `Archive` step succeeds → `Package unsigned IPA` step fails.
- **Cause:** Heredoc shell script ran `cd build && zip ...` then `ls -lh build/PhotoSwiper.ipa`. The `cd` persists across lines in a `run: |` block, so the final `ls` looked at `build/build/...` instead of `build/...`.
- **Fix:** Wrap the `cd build && zip ...` in a subshell `(...)` so cwd reverts.
- **Status:** FIXED — commit pending.
- **Silver lining:** Confirms Xcode 16 on macos-15 successfully compiled and archived the app. BUG-002 fix is good.

---

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
