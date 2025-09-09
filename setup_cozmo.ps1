<#
 Cozmo Setup Script for Windows
 Run as Administrator in PowerShell
#>


# Exit if any error occurs
$ErrorActionPreference = "Stop"


# ---- USER DETAILS  ----
$Username = $env:USERNAME
$UserDir  = "C:\Users\$Username"
$CozmoDir = "$UserDir\easy_cozmo"
$Desktop  = "$UserDir\Desktop"


Write-Host "=== Starting Cozmo Environment Setup for user: $Username ===`n"


# ----------------------------------------------------------
# 1.0 MANUAL INSTALLS WARNING
# ----------------------------------------------------------
Write-Host ">>> Please make sure these are installed manually first:"
Write-Host "    - Sublime Text"
Write-Host "    - iTunes"
Write-Host "    - Python 3.9.4 (check 'Add to PATH')"
Write-Host ">>> Also make sure you are running PowerShell as Administrator"
Write-Host "`nPress ENTER to continue..."
Read-Host

# ----------------------------------------------------------
# 1.1 AUTO INSTALLS ATTEMPT
# ----------------------------------------------------------
Write-Host ">>> Installing Sublime Text !!"

winget install --id SublimeHQ.SublimeText.4 -e --accept-package-agreements --accept-source-agreements

Write-Host ">>> Installation successful."
Write-Host ">>> Installing iTunes !!"

winget install --id Apple.iTunes -e --accept-package-agreements --accept-source-agreements

Write-Host ">>> Installation successful."
Write-Host ">>> Installing Python 3.9.4 !!"

# can’t use winget as it will fetch the most recent python 3.9 

$PythonInstaller = "$env:TEMP\python-3.9.4-amd64.exe"
Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.9.4/python-3.9.4-amd64.exe" -OutFile $PythonInstaller

# Silent install, all users, add to PATH
Start-Process -FilePath $PythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
Remove-Item $PythonInstaller

Write-Host ">>> Installation successful."
Write-Host ">>> Installing Git !!"

winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements

Write-Host ">>> Installation successful."


# ----------------------------------------------------------
# 2. CLONING REPO 
# ----------------------------------------------------------
if (!(Test-Path $CozmoDir)) {
    Write-Host ">>> Cloning easy_cozmo repository !!"
    Set-Location $UserDir
    git clone https://github.com/EduardoFF/easy_cozmo.git
}
Set-Location $CozmoDir
git fetch
git checkout cozmoball


# ----------------------------------------------------------
# 3. COZMO DEPENDENCIES 
# ----------------------------------------------------------
Write-Host ">>> Installing Python libraries !!"
python -m pip install --upgrade pip


pip install easy_cozmo


pip install scipy imutils pillow


Write-Host ">>> Installing cozmoclad 3.6.6 !!"
$CozmoWhl = "$CozmoDir\cozmoclad-3.6.6-py3-none-any.whl"
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/DDLbots/cozmo-python-sdk/refs/heads/master/cozmoclad/cozmoclad-3.6.6-py3-none-any.whl" `
  -OutFile $CozmoWhl
pip install --user $CozmoWhl


# ----------------------------------------------------------
# 4. ENVIRONMENT VARS 
# ----------------------------------------------------------
$PathValue = "$CozmoDir\bin"
$PythonPathValue = "$CozmoDir"


Write-Host ">>> Setting PATH and PYTHONPATH !!"


# Backup current PATH (just in case - REMEMBER TO REMOVE)
$oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$backupFile = "$env:USERPROFILE\Desktop\PATH_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"


Write-Host "Backing up current PATH to: $backupFile"
$oldPath | Out-File $backupFile -Encoding UTF8


# Add to PATH if not already present
$oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($oldPath -notlike "$PathValue") {
    [Environment]::SetEnvironmentVariable("Path", "$oldPath;$PathValue", "Machine") 
    Write-Host "Added $PathValue to PATH"
}


# Add PYTHONPATH as User variable
[Environment]::SetEnvironmentVariable("PYTHONPATH", $PythonPathValue, "User")
Write-Host "Set PYTHONPATH=$PythonPathValue"


# ----------------------------------------------------------
# 5. SUBLIME BUILD SYSTEM 
# ----------------------------------------------------------
$SublimeUserDir = "$UserDir\AppData\Roaming\Sublime Text\Packages\User"
if (Test-Path $SublimeUserDir) {
    Write-Host ">>> Copying pycozmo build system into Sublime Text User folder !!"
    Copy-Item "$CozmoDir\bin\pycozmo.sublime-build" -Destination $SublimeUserDir -Force
} else {
    Write-Host ">>> WARNING: Could not find Sublime Text user directory at $SublimeUserDir :("
}


# ----------------------------------------------------------
# 6. CREATING DESKTOP SHORTCUTS 
# ----------------------------------------------------------
Write-Host ">>> Creating desktop shortcuts !!"
$ChallengeUrl = "https://forms.gle/RGU69596cgwWEdKC7"
$HandoutsUrl  = "https://drive.google.com/drive/folders/1O5LxdeMhGpE7YzoBhRrkMW-zPQTcfZpO?usp=sharing"


@"
[InternetShortcut]
URL=$ChallengeUrl
"@ | Out-File "$Desktop\Challenge_Submission.url" -Encoding ASCII



# ----------------------------------------------------------
# 7. FINAL INSTRUCTIONS 
# ----------------------------------------------------------
Write-Host "`n=========================================================="
Write-Host "Setup Complete!! :D"
Write-Host "Final Steps:"
Write-Host " 1. Restart the computer to apply PATH/PYTHONPATH changes."
Write-Host " 2. Open Sublime > Tools > Build System > Select 'pycozmo'"
Write-Host " 3. Connect Cozmo and test the example code."
Write-Host " 4. If running code opens 'pycozmo' in Sublime instead of executing,"
Write-Host "    change the default program for 'pycozmo' file in $CozmoDir\bin"
Write-Host "    to Python IDLE instead of Sublime."
Write-Host "GLHF"
Write-Host "=========================================================="