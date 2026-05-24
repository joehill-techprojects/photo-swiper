# Setup Guide

> Manual setup steps for Joe (and eventually Jill). The agent walks you through these but having them written down means you can re-trace if anything breaks later.

## 1. One-time JARVIS setup

### Install iTunes

AltServer talks to iPhones through Apple's mobile device drivers, which ship inside iTunes.

1. Go to `https://www.apple.com/itunes/download/win64`
2. **Skip the Microsoft Store recommendation** — scroll down, click the small "Looking for other versions?" link, pick **Windows**, then **64-bit Windows users**. You get `iTunes64Setup.exe`.
3. Run it. Default install location is fine.
4. Launch iTunes once so it registers itself with Windows. You can close it immediately.

**Why classic and not Microsoft Store?** The Microsoft Store "Apple Devices" app installs into a layout AltServer doesn't recognize, causing the iTunes-path nag described below.

### Install AltServer

1. Go to `https://altstore.io/`, click "Download for Windows"
2. Run the installer
3. AltServer lives in the system tray (the diamond icon). Right-click the icon to see the menu.
4. Confirm **"Automatically Launch at Startup"** is checked.

### Known nag: iTunes path prompt (BUG-001)

If iTunes installed to `C:\Program Files\iTunes\` (newer 64-bit installer flavor), AltServer will pop up a "locate iTunes" dialog on every launch even after you point it at the right folder. Harmless — phone-pairing and app-refresh still work fine. Live with it.

**Optional clean fix** if it ever becomes painful, run this in an **admin** PowerShell:

```powershell
New-Item -ItemType SymbolicLink -Path "C:\Program Files (x86)\iTunes" -Target "C:\Program Files\iTunes"
```

That tricks AltServer into finding iTunes at its expected path and the nag stops forever.

## 2. One-time per-iPhone setup

Repeat all of these on each phone (Joe's, Jill's, …).

### Pair the phone with JARVIS

1. Plug iPhone into JARVIS via USB cable.
2. On the phone: "Trust This Computer?" → tap **Trust**, enter passcode.

### Install AltStore from AltServer

1. Right-click AltServer tray icon → hover **"Install AltStore"** → the iPhone's name appears in the submenu → click it.
2. A dialog asks for an Apple ID + password. Use the same Apple ID tied to iCloud on the phone (simplest). **No purchase required**, the free tier is what we want.
3. Wait ~30 seconds. AltStore icon appears on the phone's home screen.

### Trust the developer profile

1. On the phone: **Settings → General → VPN & Device Management**
2. Tap the profile listed under your Apple ID name.
3. Tap **Trust**.

### Enable iOS Developer Mode (critical — iOS 16+)

Without this, AltStore will install but refuse to launch with the misleading error:
> "Developer mode required. AltStore requires developer mode to run."

1. On the phone: **Settings → Privacy & Security**
2. Scroll all the way to the bottom → tap **Developer Mode**
3. Toggle **Developer Mode** on
4. iOS prompts you to restart the phone → tap Restart
5. After boot: **"Turn On Developer Mode?"** prompt → tap Turn On → enter passcode

Now open AltStore. First launch asks you to sign in with your Apple ID again (this is the on-device session, separate from the AltServer one). After that you're at AltStore's home screen.

## 3. Adding the PhotoSwiper source to AltStore

This is the step that lets AltStore find and install PhotoSwiper.

1. Open AltStore on the phone.
2. Tap the **Browse** tab at the bottom.
3. Tap the **"+"** icon in the top-right corner.
4. Paste this URL:

   ```
   https://raw.githubusercontent.com/joehill-techprojects/photo-swiper/main/altstore-source.json
   ```

5. Tap Done. "Joe's Personal Apps" source appears.
6. Tap into the source → tap PhotoSwiper → tap **Install**. ~30 seconds.
7. PhotoSwiper icon appears on the home screen.

> **Prerequisite:** the GitHub repo `joehill-techprojects/photo-swiper` must be **public** for AltStore to read the source JSON and IPA without authentication. If it's private, AltStore will fail with a 404 error. See `DECISIONS.md` D-014.

## 4. First run on the phone

The first time you open PhotoSwiper after a fresh install:

1. **Photo permission prompt** → tap "Allow Access to All Photos." (We need delete capability, which "Selected Photos" doesn't grant.)
2. **Settings → enter Immich URL + API key** (filled in below). Without these, right-swipe will fail silently.

## 5. Generating an Immich API key

1. Open Immich web UI: `http://192.168.1.20:2283`
2. Top-right → click your avatar → **Account Settings**
3. Left sidebar → **API Keys** → click **New API Key**
4. Name it "PhotoSwiper - Joe's iPhone" (or "...Jill's iPhone")
5. Copy the key immediately (Immich only shows it once)
6. On the phone, in PhotoSwiper Settings, paste the URL `http://192.168.1.20:2283` and the API key. Tap "Test connection" — should show ✓.

## 6. Maintenance

### App icon goes gray

Happens when the app's 7-day signing expires (e.g., you've been away from home WiFi for 8+ days).

1. Open AltStore on the phone.
2. Tap the **My Apps** tab.
3. Find PhotoSwiper, tap **Refresh** next to it.
4. Done in ~10 seconds. Icon goes color again.

Normally AltServer handles this silently in the background whenever the phone is on home WiFi — you should rarely have to do it manually.

### A CI build fails

1. Go to `https://github.com/joehill-techprojects/photo-swiper/actions`
2. Click the failed run → click the failed job → scroll to find the red ❌ step
3. Tell the agent what the error message says — they'll fix it. Don't try to debug Xcode YAML yourself unless you actively want to learn it.

### "No new version" in AltStore

Means the latest GitHub Release version matches what's installed. Push a commit to `main`, wait ~10 minutes for CI to build + release, then refresh AltStore.
