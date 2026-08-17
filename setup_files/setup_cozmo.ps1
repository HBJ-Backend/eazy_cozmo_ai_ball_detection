<#
  Cozmoball setup for Windows workshop laptops.

  HOW TO RUN (once per laptop):
    1. Open Windows PowerShell as ADMINISTRATOR.
    2. Set-ExecutionPolicy Bypass -Scope Process -Force
    3. cd to the folder containing this script.
    4. .\setup_cozmo.ps1

  Safe to re-run. Each step skips itself if the work is already done, and the
  script only reboots at the end if something changed that needs it.
#>

$ErrorActionPreference = "Stop"

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

Write-Host "=== Cozmo setup for user: $Username ===`n"

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
function Update-SessionPath {
    # Reload PATH from the machine and user values so tools installed above are
    # usable in this session without a reboot.
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

function Test-WingetApp([string]$id) {
    $out = winget list --id $id -e 2>$null | Out-String
    return ($out -match [regex]::Escape($id))
}

function Install-WingetApp([string]$name, [string]$id, [string]$source) {
    if (Test-WingetApp $id) {
        Write-Host ">>> $name already installed - skipping."
        return $false
    }
    Write-Host ">>> Installing $name ..."
    if ($source) {
        winget install --id $id -e --source $source --accept-package-agreements --accept-source-agreements
    } else {
        winget install --id $id -e --accept-package-agreements --accept-source-agreements
    }
    Update-SessionPath
    return $true
}

function Assert-LastExit([string]$what) {
    if ($LASTEXITCODE -ne 0) { throw "$what failed (exit code $LASTEXITCODE)." }
}

# ----------------------------------------------------------------------------
# 1. Apps: Sublime Text, iTunes, Git
# ----------------------------------------------------------------------------
if (Install-WingetApp "Sublime Text" "SublimeHQ.SublimeText.4") { $RebootNeeded = $true }
if (Install-WingetApp "iTunes" "Apple.iTunes" "msstore")        { $RebootNeeded = $true }
if (Install-WingetApp "Git" "Git.Git")                          { $RebootNeeded = $true }

# ----------------------------------------------------------------------------
# 2. Python 3.9 (the legacy Cozmo SDK requires 3.9; 3.10+ removed the asyncio
#    'loop' argument the SDK relies on)
# ----------------------------------------------------------------------------
$HavePy39 = $false
try {
    $v = & py -3.9 -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>$null
    if ($LASTEXITCODE -eq 0 -and $v.Trim() -eq "3.9") { $HavePy39 = $true }
} catch { }

if ($HavePy39) {
    Write-Host ">>> Python 3.9 already installed - skipping."
} else {
    Write-Host ">>> Installing Python $PyVersion ..."
    $dst = "$env:TEMP\python-$PyVersion-amd64.exe"
    Invoke-WebRequest -Uri $PyUrl -OutFile $dst
    # Silent, all users, prepend to PATH, install the 'py' launcher for all users.
    Start-Process -FilePath $dst -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 InstallLauncherAllUsers=1" -Wait
    Remove-Item $dst -Force
    Update-SessionPath
    $RebootNeeded = $true
    Write-Host ">>> Python $PyVersion installed."
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
# Best-effort fast-forward; never overwrite the workshop's local library files.
git pull --ff-only origin $Branch

# ----------------------------------------------------------------------------
# 4. Python packages
#    requirements-workshop.txt covers the pinned packages and the cozmo SDK.
#    cozmoclad is then upgraded to the 3.6.6 build the app expects.
#    Installed system-wide so every account on the laptop sees them.
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

# The PyPI 'easy_cozmo' package is deliberately not installed. It is an outdated
# stub without the soccer features, and it would shadow the repo's own copy,
# which is picked up via the PYTHONPATH set below.

# ----------------------------------------------------------------------------
# 5. Environment variables
#    PATH  += repo\bin   (so the pycozmo build launcher is found)
#    PYTHONPATH = repo   (so `import easy_cozmo` loads the repo package)
# ----------------------------------------------------------------------------
$BinDir = "$CozmoDir\bin"
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($machinePath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$machinePath;$BinDir", "Machine")
    Write-Host ">>> Added $BinDir to system PATH."
    $RebootNeeded = $true
} else {
    Write-Host ">>> System PATH already contains $BinDir."
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

# 7b. Ball-detection server, needed for the soccer tasks. cmd /k keeps the
#     window open showing the log until the student closes it.
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

# ----------------------------------------------------------------------------
# 9. Finish
# ----------------------------------------------------------------------------
Write-Host "`n=== Setup complete ==="
Write-Host "Next steps:"
Write-Host "  - In Sublime: Tools > Build System > pycozmo, then Build (Ctrl+B)."
Write-Host "  - Connect Cozmo (iPad over USB, iTunes open, app in SDK mode)."
Write-Host "  - For the soccer / ball tasks, double-click the 'Cozmo Ball Server'"
Write-Host "    desktop shortcut first (leave its window open while you play)."

if ($RebootNeeded) {
    Write-Host "`nA restart is required to apply PATH / PYTHONPATH and new installs."
    Write-Host "Restarting in 15 seconds (close this window to cancel)..."
    Start-Sleep -Seconds 15
    Restart-Computer -Force
} else {
    Write-Host "`nNothing changed that requires a restart."
}
