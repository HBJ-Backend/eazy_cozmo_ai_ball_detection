# setup_cozmo.ps1

One-shot setup for a Windows workshop laptop. Installs everything a student
needs to program Cozmo in Python. 

## Running it

1. Open Windows PowerShell. If the account is an administrator, use "Run as
   administrator" so the app installers do not each raise a UAC prompt.
2. `Set-ExecutionPolicy Bypass -Scope Process -Force`
3. `cd` to the folder holding the script.
4. `.\setup_cozmo.ps1`

Run it from the account the student will use. Everything below is per-user, so
elevating the same account is fine, but elevating into a *different* admin
account would set the laptop up for the wrong profile. The script checks for
that and stops.

Safe to re-run. Each step skips itself if the work is already done.

Adding `-NoRestart` skip the restart at the end. You still have to reboot 
before anything works.

Everything printed is also written to `%TEMP%\cozmo_setup_<timestamp>.log`.

## What it does

**Apps**

- Warms winget up first, accepting its source agreements. Without this the very
  first winget call on a new laptop sits waiting on an invisible prompt.
- Installs Sublime Text, Apple Mobile Device Support and Git through winget.
- Installs Google Chrome from Google's own MSI rather than winget, because the
  winget manifest pins a hash against a URL Google reuses for every release, so
  it breaks every time Chrome updates.
- Falls back to the vendor's MSI, read from the winget manifest, for any package
  winget refuses to install.
- Apple Mobile Device Support is what lets the SDK reach the Cozmo app on an
  iPad. Full iTunes is not needed and is not installed.

**Python**

- Installs Python 3.9.4 per-user if the laptop has no 3.9. The legacy Cozmo SDK
  needs 3.9; 3.10 removed the asyncio argument it depends on.
- Repairs a Python 3.9 that exists but has no working pip, trying `ensurepip`,
  then an installer repair, then clearing the stale registration and installing
  fresh.
- Installs the pinned packages from `requirements-workshop.txt`: cozmo 1.4.10,
  setuptools<81, pillow<10, numpy<2, scipy, imutils, opencv-python, yolov5.
- Upgrades cozmoclad to the 3.6.6 build the Cozmo app expects.

**The library**

- Clones `mindcraft_cozmo_library` to `C:\Users\<user>\mindcraft_cozmo_library`,
  or updates it if already there.
- Removes the folder left behind by laptops set up before the repo was renamed.
- Adds `<repo>\bin` to the user PATH, rebuilding the entry rather than appending
  so the pre-rename one cannot win the lookup.
- Sets `PYTHONPATH` to the repo so `import easy_cozmo` finds it.
- Copies the pycozmo build system into Sublime, so students write code and press
  Ctrl+B.

**Desktop**

- Creates three web shortcuts: Challenge Submissions, Future Coders Student
  Handouts, and MindCraft Cozmo Functions. Each opens in Chrome directly and
  carries `hl=en` so Google shows it in English whatever the laptop's region is.
- Gives those shortcuts the yellow Chrome icon, extracted to its own file so
  Chrome's own icon is unaffected.
- Creates a "Cozmo Ball Server" shortcut that starts the YOLO detection server
  for the soccer tasks, in a window that stays open.
- Sets the desktop wallpaper if a `wallpaper.jpg` or `.png` sits next to the
  script or on the Desktop, copying it into the profile first so it survives the
  USB stick being removed.

**Windows settings**

- Turns on automatic date, time and time zone, allowing location access first
  since automatic time zone needs it. Needs admin, skipped otherwise.
- Left-aligns the taskbar icons and removes Widgets, Chat and Task View.
- Clears the taskbar pins and pins only File Explorer, Chrome and Sublime.
  Windows applies this at the next sign-in, not on an Explorer restart.

**At the end**

- Verifies that `cozmo`, `cozmoclad` and `easy_cozmo` all import.
- Checks that the Apple Mobile Device Service is listening on 127.0.0.1:27015,
  which is what the SDK connects through to reach the iPad.
- Restarts, waiting for you to press Enter first. If the script was piped or has
  no keyboard attached it counts down 60 seconds instead, cancellable with
  `shutdown /a`.

## After it finishes

- In Sublime: Tools > Build System > pycozmo, then Ctrl+B to run a file.
- Connect Cozmo: iPad over USB, app in SDK mode.
- For the soccer and ball tasks, start the Cozmo Ball Server shortcut first and
  leave its window open.
- Chrome cannot be made the system default by a script, since Windows signs that
  setting per user. The script prints a one-click command for it. The shortcuts
  open in Chrome either way.

## Things that need admin

These are skipped with a message on a non-elevated run, and everything else
still completes:

- clock and time zone settings
- taskbar pins

## Known constraints

- The taskbar pins rely on a Windows layout policy that applies at sign-in. If
  they do not appear, pin the three by hand, or create the student account after
  running the script: the same layout is written to the Default profile.
- `winget list` does not reliably report Chrome or Sublime as installed even
  when they are, so the script checks for `chrome.exe` on disk instead of asking
  winget.
