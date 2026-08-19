<#
  Cozmoball setup for Windows workshop laptops.

  HOW TO RUN:
    1. Open Windows PowerShell. If that account is an administrator, use
       "Run as administrator" so the app installers do not each raise a UAC
       prompt. Elevating the same account keeps the same profile, so the
       per-user Python and environment variables still land in the right place.
    2. Set-ExecutionPolicy Bypass -Scope Process -Force
    3. cd to the folder containing this script.
    4. .\setup_cozmo.ps1

  Safe to re-run: each step skips itself if already done, and it only reboots
  at the end if something changed that needs it.

  -NoRestart skips that restart. Output is also written to a log under %TEMP%.
#>

param(
    [switch]$NoRestart
)

$ErrorActionPreference = "Stop"

$LogFile = "$env:TEMP\cozmo_setup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
try { Start-Transcript -Path $LogFile | Out-Null } catch { }

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------
$Username    = $env:USERNAME
$UserDir     = "C:\Users\$Username"
$CozmoDir    = "$UserDir\eazy_cozmo_ai_ball_detection"
$Desktop     = [Environment]::GetFolderPath("Desktop")
$RepoUrl     = "https://github.com/HBJ-Backend/eazy_cozmo_ai_ball_detection.git"
# TODO: set back to "main" once this branch is merged.
$Branch      = "clean-up"
$PyVersion   = "3.9.4"
$PyUrl       = "https://www.python.org/ftp/python/$PyVersion/python-$PyVersion-amd64.exe"
$CladUrl     = "https://raw.githubusercontent.com/DDLbots/cozmo-python-sdk/refs/heads/master/cozmoclad/cozmoclad-3.6.6-py3-none-any.whl"

$RebootNeeded = $false

# Python and the environment variables are per-user
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
            [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$ConsoleUser = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName

if ($IsAdmin -and $ConsoleUser -and $CurrentUser -ne $ConsoleUser) {
    throw "This window runs as '$CurrentUser' but '$ConsoleUser' is signed in. Everything would be set up for the wrong account. Sign in as the account the student will use, then run this script from there."
}

Write-Host "=== Cozmo setup for user: $Username ==="
if ($IsAdmin) { Write-Host "    (elevated, same account)" }
Write-Host ""

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
function Update-SessionPath {
    # Reload PATH from the machine and user values so tools installed above are
    # usable in this session without a reboot
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

function Test-WingetApp([string]$id) {
    $out = winget list --id $id -e 2>$null | Out-String
    return ($out -match [regex]::Escape($id))
}

function Install-WingetApp([string]$name, [string]$id) {
    if (Test-WingetApp $id) {
        Write-Host ">>> $name already installed - skipping."
        return $false
    }
    Write-Host ">>> Installing $name ..."
    # --silent and --disable-interactivity keep installer windows and prompts off the screen
    winget install --id $id -e --silent --disable-interactivity `
                   --accept-package-agreements --accept-source-agreements
    Update-SessionPath
    return $true
}

function Assert-LastExit([string]$what) {
    if ($LASTEXITCODE -ne 0) { throw "$what failed (exit code $LASTEXITCODE)." }
}

# ----------------------------------------------------------------------------
# 1. Apps: Sublime Text, Apple Mobile Device Support, Git
#
#    Apple Mobile Device Support lets the SDK reach the Cozmo app on an iPad.
# ----------------------------------------------------------------------------
if (Install-WingetApp "Sublime Text" "SublimeHQ.SublimeText.4")                       { $RebootNeeded = $true }
if (Install-WingetApp "Apple Mobile Device Support" "Apple.AppleMobileDeviceSupport") { $RebootNeeded = $true }
if (Install-WingetApp "Git" "Git.Git")                                                { $RebootNeeded = $true }

# ----------------------------------------------------------------------------
# 2. Python 3.9 with a working pip
#
#    The legacy SDK needs 3.9 
#    A laptop can arrive with no 3.9, a working 3.9, or a 3.9 whose pip is
#    gone, script can handle all three
#
# ----------------------------------------------------------------------------
function Get-Py39Path {
    try {
        $p = & py -3.9 -c "import sys; print(sys.executable)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $p) { return $p.Trim() }
    } catch { }
    return $null
}

function Test-Py39Pip {
    try {
        & py -3.9 -m pip --version 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch { }
    return $false
}

$Py39 = Get-Py39Path
if ($Py39) {
    Write-Host ">>> Found Python 3.9: $Py39"
} else {
    Write-Host ">>> Installing Python $PyVersion (per-user) ..."
    $dst   = "$env:TEMP\python-$PyVersion-amd64.exe"
    $PyLog = "$env:TEMP\python_install_$PyVersion.log"
    Invoke-WebRequest -Uri $PyUrl -OutFile $dst

    # The installer is silent, so /log is the only record of a failure.
    $PyArgs = "/quiet InstallAllUsers=0 PrependPath=1 Include_pip=1 Include_test=0 InstallLauncherAllUsers=0 /log `"$PyLog`""
    $proc = Start-Process -FilePath $dst -ArgumentList $PyArgs -Wait -PassThru

    Remove-Item $dst -Force

    # 3010 is ERROR_SUCCESS_REBOOT_REQUIRED: it installed, but Windows has
    # files pending replacement. The one place a restart is really needed.
    if ($proc.ExitCode -eq 3010) {
        Write-Host "`n>>> Windows needs a restart to finish the Python install."
        Write-Host "    Run this script again afterwards. It skips what is already"
        Write-Host "    done and carries on from here."
        try { Stop-Transcript | Out-Null } catch { }
        if (-not $NoRestart) {
            Read-Host "`nPress Enter to restart now (or close this window to restart later)"
            Restart-Computer -Force
        }
        exit
    }
    if ($proc.ExitCode -ne 0) {
        throw "The Python $PyVersion installer exited with code $($proc.ExitCode). Installer log: $PyLog"
    }

    # Picks up the directories the installer added to PATH.
    Update-SessionPath
    $RebootNeeded = $true

    $Py39 = Get-Py39Path
    if (-not $Py39) {
        throw "Python $PyVersion installed but 'py -3.9' still does not resolve. Restart and run this script again."
    }
    Write-Host ">>> Installed Python $PyVersion at $Py39"
}

# A 3.9 that runs but has no pip is what a half-finished uninstall leaves
# behind. pip rebuilds from the stdlib, so no reinstall and no restart.
if (-not (Test-Py39Pip)) {
    Write-Host ">>> That Python has no pip. Restoring it with ensurepip ..."
    try { & py -3.9 -m ensurepip --upgrade 2>$null | Out-Null } catch { }
    if (-not (Test-Py39Pip)) {
        throw "Python 3.9 at $Py39 has no pip and ensurepip could not restore it. Uninstall that Python from Settings > Apps, restart, then run this script again."
    }
    Write-Host ">>> pip restored."
}

# ----------------------------------------------------------------------------
# 3. Repo (clone if missing, otherwise update)
# ----------------------------------------------------------------------------
if (-not (Test-Path $CozmoDir)) {
    Write-Host ">>> Cloning repository ..."
    git clone $RepoUrl $CozmoDir
    Assert-LastExit "git clone"
} else {
    Write-Host ">>> Repository already present - updating ..."
}
Set-Location $CozmoDir
git fetch --all
git checkout $Branch
# Best-effort fast-forward 
git pull --ff-only origin $Branch

# ----------------------------------------------------------------------------
# 4. Python packages
#    requirements-workshop.txt covers the pinned packages and the cozmo SDK.
#    cozmoclad is then upgraded to the 3.6.6 build the app expects.
#    These land in the per-user Python from step 2.
# ----------------------------------------------------------------------------
$Req = "$CozmoDir\requirements-workshop.txt"
if (-not (Test-Path $Req)) {
    throw "$Req not found. Ensure the '$Branch' branch contains requirements-workshop.txt."
}
Write-Host ">>> Upgrading pip ..."
py -3.9 -m pip install --upgrade pip
Write-Host ">>> Installing pinned Python packages (incl. the cozmo SDK) ..."
py -3.9 -m pip install -r $Req
Assert-LastExit "pip install -r requirements-workshop.txt"

Write-Host ">>> Installing DDL cozmoclad 3.6.6 (matches the Cozmo app protocol) ..."
$wheel = "$env:TEMP\cozmoclad-3.6.6-py3-none-any.whl"
Invoke-WebRequest -Uri $CladUrl -OutFile $wheel
# Replaces the cozmoclad 3.4.0 that the cozmo package pulls in. pip warns about
# the dependency conflict; that is expected.
py -3.9 -m pip install --upgrade $wheel
Assert-LastExit "pip install cozmoclad 3.6.6"
Remove-Item $wheel -Force

# The PyPI 'easy_cozmo' package is deliberately not installed: it is an
# outdated stub that would shadow the repo's own copy.

# ----------------------------------------------------------------------------
# 5. Environment variables
#    PATH  += repo\bin   (so the pycozmo build launcher is found)
#    PYTHONPATH = repo   (so `import easy_cozmo` loads the repo package)
#    User scope, matching the per-user Python above.
# ----------------------------------------------------------------------------
$BinDir = "$CozmoDir\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$BinDir*") {
    $newPath = if ($userPath) { "$userPath;$BinDir" } else { $BinDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host ">>> Added $BinDir to user PATH."
    $RebootNeeded = $true
} else {
    Write-Host ">>> User PATH already contains $BinDir."
}

$curPyPath = [Environment]::GetEnvironmentVariable("PYTHONPATH", "User")
if ($curPyPath -ne $CozmoDir) {
    [Environment]::SetEnvironmentVariable("PYTHONPATH", $CozmoDir, "User")
    Write-Host ">>> Set PYTHONPATH=$CozmoDir (user)."
    $RebootNeeded = $true
} else {
    Write-Host ">>> PYTHONPATH already set."
}
Update-SessionPath

# ----------------------------------------------------------------------------
# 6. Sublime build system (so students just write code + Build)
# ----------------------------------------------------------------------------
$SublimeUserDir = "$UserDir\AppData\Roaming\Sublime Text\Packages\User"
$SourceBuild    = "$BinDir\pycozmo.sublime-build"
if (Test-Path $SourceBuild) {
    if (-not (Test-Path $SublimeUserDir)) {
        New-Item -ItemType Directory -Path $SublimeUserDir -Force | Out-Null
    }
    Copy-Item $SourceBuild -Destination $SublimeUserDir -Force
    Write-Host ">>> Installed pycozmo build system into Sublime."
} else {
    Write-Host ">>> WARNING: $SourceBuild not found - skipping Sublime build install."
}

# ----------------------------------------------------------------------------
# 7. Desktop shortcuts
# ----------------------------------------------------------------------------
# 7a. Challenge submission link.
$ChallengeUrl = "https://forms.gle/RGU69596cgwWEdKC7"
@"
[InternetShortcut]
URL=$ChallengeUrl
"@ | Out-File "$Desktop\Challenge_Submission.url" -Encoding ASCII
Write-Host ">>> Created Challenge_Submission desktop shortcut."

# 7b. Ball-detection server for the soccer tasks. cmd /k keeps the log window
#     open until the student closes it.
$ServerScript = "$CozmoDir\easy_cozmo\themes\soccer\server.py"
$ServerLnk    = "$Desktop\Cozmo Ball Server.lnk"
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($ServerLnk)
$sc.TargetPath       = "$env:WINDIR\System32\cmd.exe"
$sc.Arguments        = "/k py -3.9 `"$ServerScript`""
$sc.WorkingDirectory = $CozmoDir
$sc.IconLocation     = "$env:WINDIR\System32\cmd.exe,0"
$sc.Description       = "Starts the Cozmo ball-detection server (run before soccer/ball tasks)."
$sc.Save()
Write-Host ">>> Created 'Cozmo Ball Server' desktop shortcut."

# ----------------------------------------------------------------------------
# 8. Verify the install
# ----------------------------------------------------------------------------
Write-Host ">>> Verifying the install ..."
$env:PYTHONPATH = $CozmoDir
& py -3.9 -c "import cozmo, cozmoclad, easy_cozmo; print('cozmo', cozmo.__version__, '| cozmoclad', cozmoclad.__version__, '| scan_for_ball:', hasattr(easy_cozmo, 'scan_for_ball'))"
if ($LASTEXITCODE -eq 0) {
    Write-Host ">>> Verification PASSED."
} else {
    Write-Host ">>> Verification FAILED - review the errors above."
}

# Without this service the iPad is refused when plugged in.
$amds = Get-Service "Apple Mobile Device Service" -ErrorAction SilentlyContinue
if ($amds) {
    Write-Host ">>> Apple Mobile Device Service present (status: $($amds.Status))."
} else {
    Write-Host ">>> WARNING: Apple Mobile Device Service is missing. Fix it with:"
    Write-Host "      winget install --id Apple.AppleMobileDeviceSupport -e"
}

# ----------------------------------------------------------------------------
# 9. Finish
# ----------------------------------------------------------------------------
Write-Host "`n=== Setup complete ==="
Write-Host "Next steps:"
Write-Host "  - In Sublime: Tools > Build System > pycozmo, then Build (Ctrl+B)."
Write-Host "  - Connect Cozmo (iPad over USB, app in SDK mode)."
Write-Host "  - For the soccer / ball tasks, double-click the 'Cozmo Ball Server'"
Write-Host "    desktop shortcut first (leave its window open while you play)."
Write-Host "`nFull log of this run: $LogFile"

if (-not $RebootNeeded) {
    Write-Host "`nNothing changed that requires a restart."
    try { Stop-Transcript | Out-Null } catch { }
    return
}

Write-Host "`nA restart is required to apply PATH / PYTHONPATH and new installs."
if ($NoRestart) {
    Write-Host "Skipping the restart because -NoRestart was passed."
    Write-Host "Reboot before running any workshop code."
    try { Stop-Transcript | Out-Null } catch { }
    return
}

# wait for the person running this to actually read the output
Read-Host "`nRead the output above, then press Enter to restart now (or close this window to restart later)"
try { Stop-Transcript | Out-Null } catch { }
Restart-Computer -Force
