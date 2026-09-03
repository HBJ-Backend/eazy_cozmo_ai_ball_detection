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
$RepoName    = "mindcraft_cozmo_library"
$CozmoDir    = "$UserDir\$RepoName"
$Desktop     = [Environment]::GetFolderPath("Desktop")
$RepoUrl     = "https://github.com/HBJ-Backend/$RepoName.git"
# The workshop runs from this branch, not main.
$Branch      = "clean-up"
# Folder left behind by laptops set up before the repo was renamed. Removed
# below, along with the PATH entry pointing into it.
$OldCozmoDir = "$UserDir\eazy_cozmo_ai_ball_detection"
$PyVersion   = "3.9.4"
$PyUrl       = "https://www.python.org/ftp/python/$PyVersion/python-$PyVersion-amd64.exe"
$CladUrl     = "https://raw.githubusercontent.com/DDLbots/cozmo-python-sdk/refs/heads/master/cozmoclad/cozmoclad-3.6.6-py3-none-any.whl"
# Used when winget cannot match an installer to the machine. Same file the
# winget manifest for Google.Chrome points at.
$ChromeMsiUrl = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"

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
    # Without these, winget's first run waits on a source-agreement prompt that
    # Out-String swallows, and the script just hangs.
    $out = winget list --id $id -e --accept-source-agreements --disable-interactivity 2>$null | Out-String
    return ($out -match [regex]::Escape($id))
}

function Invoke-WingetInstall([string]$name, [string]$id) {
    # --disable-interactivity also suppresses the UAC prompt, so it is only
    # safe once elevated. These all install machine-wide.
    $wargs = @("install", "--id", $id, "-e", "--silent",
               "--accept-package-agreements", "--accept-source-agreements")
    if ($IsAdmin) { $wargs += "--disable-interactivity" }

    & winget @wargs
    $code = $LASTEXITCODE
    Update-SessionPath

    # Codes that will give the same answer however many times we ask, so there
    # is nothing to gain by retrying them.
    $deterministic = @{
        -1978335215 = "NO_APPLICABLE_INSTALLER (nothing in the package matches this machine's architecture, scope or locale)"
        -1978335216 = "NO_APPLICATIONS_FOUND (the id did not match anything in the source)"
        -1978335212 = "INSTALLER_HASH_MISMATCH (the download did not match the manifest)"
    }

    # Everything else may be transient. Windows Installer runs one MSI at a
    # time, so back-to-back packages can fail with 1618 and pass on a retry.
    if ($code -ne 0 -and -not $deterministic.ContainsKey($code)) {
        Write-Host ">>> $name failed with code $code. Waiting 20s and retrying once ..."
        Start-Sleep -Seconds 20
        & winget @wargs
        $code = $LASTEXITCODE
        Update-SessionPath
    }

    if ($code -ne 0) {
        Write-Host ">>> WARNING: winget exited with code $code while installing $name."
        if ($deterministic.ContainsKey($code)) {
            Write-Host "    $($deterministic[$code])"
        }
        if (-not $IsAdmin) {
            Write-Host "    These install machine-wide. Re-run from an elevated PowerShell."
        }
        Write-Host "    Full winget log: $env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"
    }
    return $code
}

function Get-WingetInstallerUrl([string]$id) {
    # Out-String -Width stops the console wrapping the URL across two lines.
    $out = (winget show --id $id -e --accept-source-agreements --disable-interactivity 2>$null | Out-String -Width 4096)
    $m = [regex]::Match($out, '(?m)^\s*Installer Url:\s*(\S+)\s*$')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Install-FromVendorUrl([string]$name, [string]$id) {
    # When winget refuses a package the file itself is usually still fine. The
    # URL comes from the manifest, so it tracks the current version.
    $url = Get-WingetInstallerUrl $id
    if (-not $url) {
        Write-Host ">>> Could not read an installer URL for $name from its manifest."
        return $false
    }
    if ($url -notmatch '\.msi(\?|$)') {
        Write-Host ">>> $name is not an MSI, so it cannot be installed directly:"
        Write-Host "    $url"
        return $false
    }

    Write-Host ">>> Falling back to the vendor's MSI for $name ..."
    $file = Join-Path $env:TEMP ([System.IO.Path]::GetFileName($url.Split('?')[0]))
    $log  = "$env:TEMP\$($id -replace '[^\w.-]','_')_msi.log"
    try {
        Invoke-WebRequest -Uri $url -OutFile $file
        $mp = Start-Process msiexec.exe -Wait -PassThru `
                -ArgumentList "/i `"$file`" /qn /norestart /l*v `"$log`""
        Remove-Item $file -Force -ErrorAction SilentlyContinue
        if ($mp.ExitCode -ne 0) {
            Write-Host ">>> msiexec exited with code $($mp.ExitCode). Log: $log"
            return $false
        }
        Update-SessionPath
        Write-Host ">>> $name installed from the vendor MSI."
        return $true
    } catch {
        Write-Host ">>> Vendor MSI install failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-WingetApp([string]$name, [string]$id) {
    if (Test-WingetApp $id) {
        Write-Host ">>> $name already installed - skipping."
        return $false
    }
    Write-Host ">>> Installing $name ..."
    if ((Invoke-WingetInstall $name $id) -ne 0) {
        [void](Install-FromVendorUrl $name $id)
    }
    return $true
}

function Assert-LastExit([string]$what) {
    if ($LASTEXITCODE -ne 0) { throw "$what failed (exit code $LASTEXITCODE)." }
}

function Request-Restart {
    # Read-Host returns instantly when stdin is redirected, which would reboot
    # before anyone read the output. Use a cancellable countdown instead.
    try { Stop-Transcript | Out-Null } catch { }
    if ([Console]::IsInputRedirected) {
        Write-Host "`nNo keyboard attached to this session, so this will not wait."
        Write-Host "Restarting in 60 seconds. To cancel, run in another window:"
        Write-Host "    shutdown /a"
        & shutdown.exe /r /t 60 /c "Cozmo setup finished. Restarting."
    } else {
        Read-Host "`nRead the output above, then press Enter to restart now (or close this window to restart later)"
        Restart-Computer -Force
    }
}

function Find-Chrome {
    # Registered locations first. HKCU matters as well as HKLM: a per-user
    # Chrome registers only under HKCU, so checking HKLM alone misses it.
    foreach ($root in @("HKCU:", "HKLM:")) {
        $key = "$root\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
        $fromReg = (Get-ItemProperty $key -ErrorAction SilentlyContinue).'(default)'
        if ($fromReg -and (Test-Path $fromReg)) { return $fromReg }
    }
    foreach ($p in @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
                     "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                     "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

# ----------------------------------------------------------------------------
# 0. Warm winget up.
#
#    First run accepts the source agreements and builds the package index,
#    which can take minutes. Doing it here makes that show as progress.
# ----------------------------------------------------------------------------
Write-Host ">>> Preparing winget (first run on a new laptop can take a few minutes) ..."
try {
    winget source update --accept-source-agreements --disable-interactivity | Out-Null
    Write-Host ">>> winget ready."
} catch {
    Write-Host ">>> winget source update failed: $($_.Exception.Message)"
}

# ----------------------------------------------------------------------------
# 1. Apps: Sublime Text, Google Chrome, Apple Mobile Device Support, Git
#
#    Apple Mobile Device Support lets the SDK reach the Cozmo app on an iPad.
#    Chrome is installed so every laptop has the same browser and the web
#    shortcuts below can target it directly.
# ----------------------------------------------------------------------------
if (Install-WingetApp "Sublime Text" "SublimeHQ.SublimeText.4")                       { $RebootNeeded = $true }
if (Install-WingetApp "Apple Mobile Device Support" "Apple.AppleMobileDeviceSupport") { $RebootNeeded = $true }
if (Install-WingetApp "Git" "Git.Git")                                                { $RebootNeeded = $true }

# Chrome is checked on disk rather than through winget list, because a copy
# installed outside winget still needs finding: the shortcuts need its path.
$Chrome = Find-Chrome
if ($Chrome) {
    Write-Host ">>> Chrome already installed: $Chrome"
} else {
    # Not via winget: Google reuses one URL for every release, so the manifest's
    # pinned hash goes stale and winget refuses. --ignore-security-hash cannot
    # override that in an elevated session, which a machine-scope MSI needs.
    Write-Host ">>> Installing Google Chrome from Google's enterprise MSI ..."
    $RebootNeeded = $true
    $msi = "$env:TEMP\googlechromestandaloneenterprise64.msi"
    $msiLog = "$env:TEMP\chrome_msi_install.log"
    try {
        Invoke-WebRequest -Uri $ChromeMsiUrl -OutFile $msi
        $mp = Start-Process msiexec.exe -Wait -PassThru `
                -ArgumentList "/i `"$msi`" /qn /norestart /l*v `"$msiLog`""
        Remove-Item $msi -Force -ErrorAction SilentlyContinue
        if ($mp.ExitCode -ne 0) {
            Write-Host ">>> msiexec exited with code $($mp.ExitCode). Log: $msiLog"
        }
        Update-SessionPath
    } catch {
        Write-Host ">>> Chrome download or install failed: $($_.Exception.Message)"
    }

    # chrome.exe on disk is the only thing worth believing.
    $Chrome = Find-Chrome
    if ($Chrome) {
        Write-Host ">>> Chrome installed: $Chrome"
    } else {
        Write-Host ""
        Write-Host ">>> WARNING: Chrome is NOT installed."
        Write-Host "    No chrome.exe in Program Files, Program Files (x86) or"
        Write-Host "    LocalAppData, and no App Paths entry for it."
        Write-Host "    Every web shortcut will open in the default browser (Edge)."
        Write-Host "    See $msiLog, or install Chrome by hand and run this again."
        Write-Host ""
    }
}

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
        if (-not $NoRestart) { Request-Restart }
        else { try { Stop-Transcript | Out-Null } catch { } }
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
# behind. Three attempts, cheapest first.
if (-not (Test-Py39Pip)) {

    # 1. ensurepip rebuilds pip from the standard library. Free when it works,
    #    but it cannot help if the stdlib itself is incomplete.
    Write-Host ">>> That Python has no pip. Restoring it with ensurepip ..."
    try { & py -3.9 -m ensurepip --upgrade 2>$null | Out-Null } catch { }

    # 2. Repair puts back removed files, pip included. It also works where an
    #    uninstall cannot: the pip MSI's uninstall runs python.exe from the
    #    target folder, so a deleted folder makes Settings > Apps a no-op.
    if (-not (Test-Py39Pip)) {
        Write-Host ">>> ensurepip could not fix it. Repairing the install ..."
        $rep = "$env:TEMP\python-$PyVersion-amd64.exe"
        $repLog = "$env:TEMP\python_repair_$PyVersion.log"
        try {
            Invoke-WebRequest -Uri $PyUrl -OutFile $rep
            $rp = Start-Process -FilePath $rep -Wait -PassThru `
                    -ArgumentList "/quiet /repair /log `"$repLog`""
            Write-Host ">>> Repair exited with code $($rp.ExitCode). Log: $repLog"
            Update-SessionPath
            if (-not (Test-Py39Pip)) {
                try { & py -3.9 -m ensurepip --upgrade 2>$null | Out-Null } catch { }
            }
        } catch {
            Write-Host ">>> Repair failed: $($_.Exception.Message)"
        } finally {
            Remove-Item $rep -Force -ErrorAction SilentlyContinue
        }
    }

    # 3. The registration is what keeps 'py -3.9' pointing at the broken
    #    install and it survives a failed uninstall, so clear it and reinstall.
    if (-not (Test-Py39Pip)) {
        Write-Host ">>> Still no pip. Clearing the stale 3.9 registration and"
        Write-Host "    installing fresh ..."
        foreach ($hive in @("HKCU:\SOFTWARE\Python\PythonCore\3.9",
                            "HKLM:\SOFTWARE\Python\PythonCore\3.9",
                            "HKLM:\SOFTWARE\WOW6432Node\Python\PythonCore\3.9")) {
            if (Test-Path $hive) {
                Remove-Item $hive -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "    removed $hive"
            }
        }
        $fresh = "$env:TEMP\python-$PyVersion-amd64.exe"
        $freshLog = "$env:TEMP\python_fresh_$PyVersion.log"
        try {
            Invoke-WebRequest -Uri $PyUrl -OutFile $fresh
            $fp = Start-Process -FilePath $fresh -Wait -PassThru `
                    -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_pip=1 Include_test=0 InstallLauncherAllUsers=0 /log `"$freshLog`""
            Write-Host ">>> Fresh install exited with code $($fp.ExitCode). Log: $freshLog"
            Update-SessionPath
            $RebootNeeded = $true
        } catch {
            Write-Host ">>> Fresh install failed: $($_.Exception.Message)"
        } finally {
            Remove-Item $fresh -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Py39Pip)) {
        throw "Python 3.9 still has no pip after ensurepip, a repair and a reinstall. Check the logs named above, then delete the Python 3.9 folder and its PythonCore\3.9 registry key by hand before running this again."
    }
    Write-Host ">>> pip restored."
    $Py39 = Get-Py39Path
}

# ----------------------------------------------------------------------------
# 3. Repo (clone if missing, otherwise update)
#
#    A laptop set up before the rename still has the old folder. Left behind it
#    means two copies of the library and a stale PATH entry, so remove it.
# ----------------------------------------------------------------------------
if (Test-Path $OldCozmoDir) {
    Write-Host ">>> Found the pre-rename folder $OldCozmoDir - removing it ..."
    Remove-Item $OldCozmoDir -Recurse -Force
    $RebootNeeded = $true
}

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
$BinDir    = "$CozmoDir\bin"
$OldBinDir = "$OldCozmoDir\bin"

# Rebuild rather than append: the pre-rename bin was added first, so it would
# win the lookup for pycozmo.bat.
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$kept = @($userPath -split ';' | Where-Object {
    $_ -and $_.TrimEnd('\') -ne $BinDir.TrimEnd('\') `
         -and $_.TrimEnd('\') -ne $OldBinDir.TrimEnd('\')
})
$newPath = ($kept + $BinDir) -join ';'

if ($newPath -ne $userPath) {
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host ">>> User PATH now ends with $BinDir."
    $RebootNeeded = $true
} else {
    Write-Host ">>> User PATH already correct."
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
# 7a. Web links. All carry hl=en so Google shows them in English whatever the
#     laptop's region is set to.
#
#     The form uses its expanded URL because the forms.gle short link drops
#     query parameters when it redirects. Drive and Docs links keep theirs.
$ws = New-Object -ComObject WScript.Shell

# chrome.exe carries several icons; index 4 is a yellow version of the logo,
# which sets the workshop links apart from Chrome itself.
#
# Copied to its own .ico rather than referenced as "chrome.exe,4": several
# shortcuts naming one exe with different indices makes Explorer's icon cache
# serve the same picture for all of them, Chrome's own shortcut included.
$LinkIcon = $null
if ($Chrome) {
    try {
        if (-not ("CozmoIconExtract" -as [type])) {
            Add-Type -AssemblyName System.Drawing
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class CozmoIconExtract {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int PrivateExtractIcons(string lpszFile, int nIconIndex, int cx, int cy,
                                                 IntPtr[] phicon, int[] piconid, int nIcons, int flags);
    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
'@
        }
        $IconDir = "$UserDir\AppData\Local\MindCraft"
        if (-not (Test-Path $IconDir)) { New-Item -ItemType Directory -Path $IconDir -Force | Out-Null }
        $IconPath = "$IconDir\link_icon.ico"

        # Assembled by hand: [Icon]::Save on a handle-created icon writes
        # planes=0 and bpp=0, which Windows renders as flat neon yellow.
        $imgs = @()
        foreach ($size in @(256, 48, 32)) {
            $h  = New-Object IntPtr[] 1
            $id = New-Object int[] 1
            if ([CozmoIconExtract]::PrivateExtractIcons($Chrome, 4, $size, $size, $h, $id, 1, 0) -gt 0 `
                -and $h[0] -ne [IntPtr]::Zero) {
                $icon = [System.Drawing.Icon]::FromHandle($h[0])
                $bmp  = $icon.ToBitmap()
                $ms   = New-Object System.IO.MemoryStream
                $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                $imgs += ,@{ size = $size; data = $ms.ToArray() }
                $ms.Close(); $bmp.Dispose(); $icon.Dispose()
                [void][CozmoIconExtract]::DestroyIcon($h[0])
            }
        }

        if ($imgs.Count -gt 0) {
            $fs = [System.IO.File]::Create($IconPath)
            $bw = New-Object System.IO.BinaryWriter($fs)
            $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$imgs.Count)
            $offset = 6 + (16 * $imgs.Count)
            foreach ($im in $imgs) {
                # 0 in the width/height byte means 256.
                $d = if ($im.size -ge 256) { 0 } else { $im.size }
                $bw.Write([byte]$d); $bw.Write([byte]$d)
                $bw.Write([byte]0);  $bw.Write([byte]0)
                $bw.Write([uint16]1); $bw.Write([uint16]32)
                $bw.Write([uint32]$im.data.Length); $bw.Write([uint32]$offset)
                $offset += $im.data.Length
            }
            foreach ($im in $imgs) { $bw.Write($im.data) }
            $bw.Close(); $fs.Close()
            $LinkIcon = $IconPath
            Write-Host ">>> Saved the yellow link icon ($($imgs.Count) sizes) to $IconPath"
        }
    } catch {
        Write-Host ">>> Could not extract the yellow icon: $($_.Exception.Message)"
    }
}
# Falling back to chrome.exe index 0 keeps the same index Chrome's own shortcut
# uses, so there is still nothing for the cache to confuse.
$LinkIconLocation = if ($LinkIcon) { "$LinkIcon,0" } elseif ($Chrome) { "$Chrome,0" } else { "" }

function New-BrowserShortcut([string]$name, [string]$url, [string]$description) {
    $lnk     = "$Desktop\$name.lnk"
    $urlFile = "$Desktop\$name.url"
    if ($Chrome) {
        # A .url always opens in the default browser, which a script cannot
        # set. Targeting chrome.exe is what guarantees Chrome.
        Remove-Item $urlFile -Force -ErrorAction SilentlyContinue
        $sc = $ws.CreateShortcut($lnk)
        $sc.TargetPath   = $Chrome
        $sc.Arguments    = "`"$url`""
        $sc.IconLocation = $LinkIconLocation
        $sc.Description  = $description
        $sc.Save()
        Write-Host ">>> Created '$name' shortcut (opens in Chrome)."
    } else {
        Remove-Item $lnk -Force -ErrorAction SilentlyContinue
        @"
[InternetShortcut]
URL=$url
"@ | Out-File $urlFile -Encoding ASCII
        Write-Host ">>> Created '$name' shortcut (default browser)."
    }
}

# Shortcut left behind by laptops set up before this was renamed, otherwise
# the desktop ends up with both the old and the new one.
foreach ($old in @("$Desktop\Challenge_Submission.lnk", "$Desktop\Challenge_Submission.url")) {
    if (Test-Path $old) {
        Remove-Item $old -Force -ErrorAction SilentlyContinue
        Write-Host ">>> Removed the old Challenge_Submission shortcut."
    }
}

New-BrowserShortcut "Challenge Submissions" `
    "https://docs.google.com/forms/d/e/1FAIpQLSc-GV3oKHZ9FXH7rmP04t2yzX2oRJkOX1KsZuoKQCOizJ59rg/viewform?usp=send_form&hl=en" `
    "Submit your challenge."

New-BrowserShortcut "Future Coders Student Handouts" `
    "https://drive.google.com/drive/folders/12DbUmUhiCtGdiJe0SUT28CqIXIAHF4GS?usp=drive_link&hl=en" `
    "Workshop handouts on Google Drive."

New-BrowserShortcut "MindCraft Cozmo Functions" `
    "https://docs.google.com/document/d/1jA8GL5HEnDHiaCdImc6pvoxggeEYD7BQUZaWw6oaIto/preview?usp=sharing&hl=en" `
    "Reference list of the Cozmo functions."

# 7b. Ball-detection server for the soccer tasks. cmd /k keeps the log window
#     open until the student closes it.
$ServerScript = "$CozmoDir\easy_cozmo\themes\soccer\server.py"
$ServerLnk    = "$Desktop\Cozmo Ball Server.lnk"
$sc = $ws.CreateShortcut($ServerLnk)
$sc.TargetPath       = "$env:WINDIR\System32\cmd.exe"
$sc.Arguments        = "/k py -3.9 `"$ServerScript`""
$sc.WorkingDirectory = $CozmoDir
$sc.IconLocation     = "$env:WINDIR\System32\cmd.exe,0"
$sc.Description       = "Starts the Cozmo ball-detection server (run before soccer/ball tasks)."
$sc.Save()
Write-Host ">>> Created 'Cozmo Ball Server' desktop shortcut."

# Clears the stale yellow drawing left by earlier versions of this script.
try { & "$env:WINDIR\System32\ie4uinit.exe" -show } catch { }

# ----------------------------------------------------------------------------
# 8. Laptop consistency: clock and wallpaper
# ----------------------------------------------------------------------------
# 8a. Automatic date, time and time zone. Needs admin, so it is skipped on a
#     non-elevated run rather than failing the whole script.
#     Automatic time zone (tzautoupdate) will not work unless location access
#     is allowed, which is why that comes first.
if ($IsAdmin) {
    try {
        $loc = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
        if (-not (Test-Path $loc)) { New-Item -Path $loc -Force | Out-Null }
        Set-ItemProperty -Path $loc -Name "Value" -Value "Allow"
        Write-Host ">>> Location access allowed (needed for automatic time zone)."

        Set-Service tzautoupdate -StartupType Automatic
        Start-Service tzautoupdate -ErrorAction SilentlyContinue
        Write-Host ">>> Automatic time zone enabled."

        Set-Service w32time -StartupType Automatic
        Start-Service w32time -ErrorAction SilentlyContinue
        & w32tm /resync 2>$null | Out-Null
        Write-Host ">>> Time sync enabled; clock resynced. Now: $(Get-Date -Format 'yyyy-MM-dd HH:mm') ($((Get-TimeZone).Id))"
    } catch {
        Write-Host ">>> WARNING: could not set the clock automatically: $($_.Exception.Message)"
    }
} else {
    Write-Host ">>> Skipping clock settings (needs an elevated run)."
}

# 8b. Desktop wallpaper. Looked for next to this script and on the Desktop, so
#     it can be carried in on the same USB stick. Copied into the profile first
#     so the wallpaper survives the stick being removed.
$WallpaperNames = @("wallpaper.jpg", "wallpaper.jpeg", "wallpaper.png")
$WallpaperSrc = $null
foreach ($dir in @($PSScriptRoot, $Desktop)) {
    if (-not $dir) { continue }
    foreach ($name in $WallpaperNames) {
        $candidate = Join-Path $dir $name
        if (Test-Path $candidate) { $WallpaperSrc = $candidate; break }
    }
    if ($WallpaperSrc) { break }
}

if ($WallpaperSrc) {
    $PicturesDir = "$UserDir\Pictures"
    if (-not (Test-Path $PicturesDir)) { New-Item -ItemType Directory -Path $PicturesDir -Force | Out-Null }
    $WallpaperDst = Join-Path $PicturesDir ("cozmo_wallpaper" + [System.IO.Path]::GetExtension($WallpaperSrc))
    Copy-Item $WallpaperSrc $WallpaperDst -Force

    if (-not ("CozmoWallpaper.Setter" -as [type])) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
namespace CozmoWallpaper {
    public class Setter {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        public static void Apply(string path) {
            // SPI_SETDESKWALLPAPER, SPIF_UPDATEINIFILE | SPIF_SENDWININICHANGE
            SystemParametersInfo(20, 0, path, 0x01 | 0x02);
        }
    }
}
'@
    }
    # 10 = fill, 0 = do not tile.
    Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "10"
    Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name TileWallpaper  -Value "0"
    [CozmoWallpaper.Setter]::Apply($WallpaperDst)
    Write-Host ">>> Wallpaper set from $WallpaperSrc"
} else {
    Write-Host ">>> No wallpaper found. Put wallpaper.jpg (or .png) next to this"
    Write-Host "    script or on the Desktop and re-run to set it."
}

# 8c. Taskbar appearance. Explorer reads all of these at startup, so it is
#     restarted once at the end of the section rather than after each change.
$Advanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$ExplorerNeedsRestart = $false
$PinsQueued = $false

# Icons on the left, the Windows 10 layout, rather than centred.
try {
    if ((Get-ItemProperty $Advanced -Name TaskbarAl -ErrorAction SilentlyContinue).TaskbarAl -ne 0) {
        Set-ItemProperty -Path $Advanced -Name TaskbarAl -Value 0 -Type DWord
        Write-Host ">>> Taskbar icons set to left-aligned."
        $ExplorerNeedsRestart = $true
    } else {
        Write-Host ">>> Taskbar icons already left-aligned."
    }
} catch {
    Write-Host ">>> Could not set taskbar alignment: $($_.Exception.Message)"
}

# Widgets ("Good afternoon" weather panel), Chat and Task View off, so the
# taskbar holds only what the workshop needs.
foreach ($t in @(@{ n = "TaskbarDa";          label = "Widgets" },
                 @{ n = "TaskbarMn";          label = "Chat" },
                 @{ n = "ShowTaskViewButton"; label = "Task View" })) {
    try {
        if ((Get-ItemProperty $Advanced -Name $t.n -ErrorAction SilentlyContinue).$($t.n) -ne 0) {
            Set-ItemProperty -Path $Advanced -Name $t.n -Value 0 -Type DWord
            Write-Host ">>> $($t.label) removed from the taskbar."
            $ExplorerNeedsRestart = $true
        }
    } catch {
        Write-Host ">>> Could not turn off $($t.label): $($_.Exception.Message)"
    }
}

# 8d. Taskbar pins: clear whatever is there and pin only File Explorer, Chrome
#     and Sublime.
#
#     Windows 10 1809 removed the pin-to-taskbar shell verb, so the supported
#     route is a layout XML named by a machine policy. PinListPlacement
#     "Replace" drops the existing pins. Needs admin for the HKLM value.
if ($IsAdmin) {
    function Find-StartMenuLink([string]$pattern) {
        foreach ($root in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs")) {
            $hit = Get-ChildItem $root -Recurse -Filter $pattern -ErrorAction SilentlyContinue |
                   Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
        return $null
    }

    $wanted = @(
        @{ label = "File Explorer"; pattern = "File Explorer.lnk" },
        @{ label = "Google Chrome"; pattern = "Google Chrome.lnk" },
        @{ label = "Sublime Text";  pattern = "Sublime Text*.lnk" }
    )
    $links = @()
    foreach ($w in $wanted) {
        $path = Find-StartMenuLink $w.pattern
        if ($path) { $links += $path }
        else { Write-Host ">>> No Start Menu shortcut for $($w.label); it will not be pinned." }
    }

    if ($links.Count -gt 0) {
        try {
            # LayoutXMLPath is a machine-wide value, so the XML must not name
            # one user's profile. Put the environment variables back.
            $entries = ($links | ForEach-Object {
                $p = $_
                $p = $p -replace [regex]::Escape($env:APPDATA), '%APPDATA%'
                $p = $p -replace [regex]::Escape($env:ProgramData), '%ProgramData%'
                '        <taskbar:DesktopApp DesktopApplicationLinkPath="{0}"/>' -f $p
            }) -join "`r`n"

            $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate
    xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification"
    xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
    xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout"
    xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout"
    Version="1">
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
$entries
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@
            $layoutDir = "$env:ProgramData\MindCraft"
            if (-not (Test-Path $layoutDir)) { New-Item -ItemType Directory -Path $layoutDir -Force | Out-Null }
            $layoutFile = "$layoutDir\TaskbarLayoutModification.xml"
            Set-Content -Path $layoutFile -Value $xml -Encoding UTF8

            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" `
                             -Name LayoutXMLPath -Value $layoutFile

            # Also into the Default profile, so accounts created later pick the
            # pins up at first sign-in. That case Windows honours reliably.
            $defaultShell = "C:\Users\Default\AppData\Local\Microsoft\Windows\Shell"
            if (-not (Test-Path $defaultShell)) {
                New-Item -ItemType Directory -Path $defaultShell -Force | Out-Null
            }
            Copy-Item $layoutFile "$defaultShell\LayoutModification.xml" -Force -ErrorAction SilentlyContinue

            # The policy is only consulted when the user has no pins of their
            # own, so clear the shortcuts and the Taskband values first.
            $pinDir = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
            if (Test-Path $pinDir) {
                Get-ChildItem $pinDir -Filter *.lnk | Remove-Item -Force -ErrorAction SilentlyContinue
            }
            $band = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
            foreach ($v in @("Favorites", "FavoritesResolve", "FavoritesChanges", "FavoritesVersion")) {
                Remove-ItemProperty -Path $band -Name $v -Force -ErrorAction SilentlyContinue
            }

            Write-Host ">>> Taskbar pins queued: $(($links | Split-Path -Leaf) -join ', ')"
            Write-Host "    These appear at the next sign-in, not on an Explorer restart."

            # Deliberately NOT restarting Explorer here. The layout policy is
            # read at logon, and a restart now would have Explorer rebuild
            # Taskband from the cleared state and mark the user as having their
            # own pins again, which is what stops the policy applying.
            $PinsQueued   = $true
            $RebootNeeded = $true
        } catch {
            Write-Host ">>> Could not set taskbar pins: $($_.Exception.Message)"
        }
    }
} else {
    Write-Host ">>> Skipping taskbar pins (needs an elevated run)."
}

if ($ExplorerNeedsRestart -and -not $PinsQueued) {
    Write-Host ">>> Restarting Explorer to apply the taskbar changes ..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer
    }
}

# ----------------------------------------------------------------------------
# 9. Verify the install
# ----------------------------------------------------------------------------
Write-Host ">>> Verifying the install ..."
$env:PYTHONPATH = $CozmoDir
& py -3.9 -c "import cozmo, cozmoclad, easy_cozmo; print('cozmo', cozmo.__version__, '| cozmoclad', cozmoclad.__version__, '| scan_for_ball:', hasattr(easy_cozmo, 'scan_for_ball'))"
if ($LASTEXITCODE -eq 0) {
    Write-Host ">>> Verification PASSED."
} else {
    Write-Host ">>> Verification FAILED - review the errors above."
}

# The SDK reaches the iPad through usbmuxd, which on Windows is the Apple
# Mobile Device Service listening on 127.0.0.1:27015. Checking the port rather
# than just the service, because a registered but stopped service still fails
# with "[WinError 1225] The remote computer refused the network connection".
$amds = Get-Service "Apple Mobile Device Service" -ErrorAction SilentlyContinue
if (-not $amds) {
    Write-Host ">>> WARNING: Apple Mobile Device Service is missing. Install it with:"
    Write-Host "      winget install --id Apple.AppleMobileDeviceSupport -e"
} else {
    Write-Host ">>> Apple Mobile Device Service: $($amds.Status), start type $($amds.StartType)."
    $mux = Get-NetTCPConnection -LocalPort 27015 -State Listen -ErrorAction SilentlyContinue
    if ($mux) {
        Write-Host ">>> usbmuxd is listening on 127.0.0.1:27015."
    } else {
        Write-Host ">>> WARNING: nothing is listening on 127.0.0.1:27015, so the SDK"
        Write-Host "    cannot reach the iPad. In an elevated PowerShell run:"
        Write-Host "      Start-Service 'Apple Mobile Device Service'"
        Write-Host "      Set-Service 'Apple Mobile Device Service' -StartupType Automatic"
        Write-Host "    A restart usually fixes it too. If the service runs and the port"
        Write-Host "    is still closed, install iTunes for a full usbmuxd:"
        Write-Host "      winget install --id Apple.iTunes -e"
    }
}

# ----------------------------------------------------------------------------
# 10. Finish
# ----------------------------------------------------------------------------
Write-Host "`n=== Setup complete ==="
Write-Host "Next steps:"
Write-Host "  - In Sublime: Tools > Build System > pycozmo, then Build (Ctrl+B)."
Write-Host "  - Connect Cozmo (iPad over USB, app in SDK mode)."
Write-Host "  - For the soccer / ball tasks, double-click the 'Cozmo Ball Server'"
Write-Host "    desktop shortcut first (leave its window open while you play)."
if ($Chrome) {
    Write-Host "  - To make Chrome the system default, run this and click 'Set default':"
    Write-Host "      start ms-settings:defaultapps?registeredAppUser=Google%20Chrome"
    Write-Host "    The desktop shortcuts already open in Chrome either way."
}
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

Request-Restart
