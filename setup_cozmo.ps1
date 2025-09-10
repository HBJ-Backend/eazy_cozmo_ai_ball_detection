<#
 Cozmoball Setup Script for Windows
 To run: 
    1. Open PowerShell as Administrator
    2. Navigate to the directory containing this script
    3. Allow execution: Set-Excutionpolicy Bypass -Scope Process -Force 
    4. Execute: .\setup_cozmo.ps1
#>


# Exit if any error occurs
$ErrorActionPreference = "Stop"


# ---- USER DETAILS  ----
$Username = $env:USERNAME
$UserDir  = "C:\Users\$Username"
$CozmoDir = "$UserDir\eazy_cozmo_ai_ball_detection"
$Desktop  = "$UserDir\Desktop"


Write-Host "=== Starting Cozmo Environment Setup for user: $Username ===`n"

$Step1DoneFlag = "$env:TEMP\cozmo_step1_done.flag"

# ----------------------------------------------------------
# 1. AUTO INSTALLING APPS (first run only)
# ----------------------------------------------------------
if (-not (Test-Path $Step1DoneFlag)) {
    Write-Host ">>> First-time setup detected: Installing required apps !!"

    Write-Host ">>> Installing Sublime Text !!"
    winget install --id SublimeHQ.SublimeText.4 -e --accept-package-agreements --accept-source-agreements
    Write-Host ">>> Installation successful."

    Write-Host ">>> Installing iTunes !!"
    winget install --id Apple.iTunes --source msstore --accept-package-agreements --accept-source-agreements
    Write-Host ">>> Installation successful."

    Write-Host ">>> Installing Python 3.9.4 !!"
    $PythonInstaller = "$env:TEMP\python-3.9.4-amd64.exe"
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.9.4/python-3.9.4-amd64.exe" -OutFile $PythonInstaller
    # Silent install, all users, add to PATH
    Start-Process -FilePath $PythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
    Remove-Item $PythonInstaller
    Write-Host ">>> Installation successful."

    Write-Host ">>> Installing Git !!"
    winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
    Write-Host ">>> Installation successful."

    # Mark Step 1 as done
    New-Item -Path $Step1DoneFlag -ItemType File -Force | Out-Null

    Write-Host ">>> Restarting system to apply app installations..."
    Restart-Computer -Force
    exit
} else {
    Write-Host ">>> Skipping Step 1 (apps already installed)."
}


# # ----------------------------------------------------------
# # 1. AUTO INSTALLING APPS
# # ----------------------------------------------------------
# Write-Host ">>> Installing Sublime Text !!"

# winget install --id SublimeHQ.SublimeText.4 -e --accept-package-agreements --accept-source-agreements

# Write-Host ">>> Installation successful."
# Write-Host ">>> Installing iTunes !!"

# winget install --id Apple.iTunes --source msstore --accept-package-agreements --accept-source-agreements

# Write-Host ">>> Installation successful."
# Write-Host ">>> Installing Python 3.9.4 !!"

# # can’t use winget as it will fetch the most recent python 3.9 

# $PythonInstaller = "$env:TEMP\python-3.9.4-amd64.exe"
# Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.9.4/python-3.9.4-amd64.exe" -OutFile $PythonInstaller

# # Silent install, all users, add to PATH
# Start-Process -FilePath $PythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
# Remove-Item $PythonInstaller

# Write-Host ">>> Installation successful."
# Write-Host ">>> Installing Git !!"

# winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements

# Write-Host ">>> Installation successful."


# ----------------------------------------------------------
# 2. CLONING REPO 
# ----------------------------------------------------------
if (!(Test-Path $CozmoDir)) {
    Write-Host ">>> Cloning easy_cozmo repository !!"
    Set-Location $UserDir
    git clone https://github.com/HBJ-Backend/eazy_cozmo_ai_ball_detection.git
}
Set-Location $CozmoDir
git fetch
git checkout main


# ----------------------------------------------------------
# 3. COZMO DEPENDENCIES 
# ----------------------------------------------------------
Write-Host ">>> Installing Python libraries !!"


python -m pip install --upgrade pip

pip install easy_cozmo

pip install scipy imutils pillow yolov5


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

# Ensure the User folder exists
if (-not (Test-Path $SublimeUserDir)) {
    New-Item -Path $SublimeUserDir -ItemType Directory -Force | Out-Null
}

# Ensure source file exists
$SourceBuild = "$CozmoDir\bin\pycozmo.sublime-build"
if (-not (Test-Path $SourceBuild)) {
    Write-Host ">>> ERROR: Source build file not found at $SourceBuild"
} else {
    Write-Host ">>> Copying pycozmo build system into Sublime Text User folder !!"
    Copy-Item $SourceBuild -Destination $SublimeUserDir -Force -ErrorAction Stop
    Write-Host ">>> Copy successful!"
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
# 7. FLAG CLEANUP + FINAL RESTART
# ----------------------------------------------------------
# Write-Host "`n=========================================================="
# Write-Host "Setup Complete!! :D"
# Write-Host "Final Steps:"
# Write-Host " 1. Restart the computer to apply PATH/PYTHONPATH changes."
# Write-Host " 2. Open Sublime > Tools > Build System > Select 'pycozmo'"
# Write-Host " 3. Connect Cozmo and test the example code."
# Write-Host " 4. If running code opens 'pycozmo' in Sublime instead of executing,"
# Write-Host "    change the default program for 'pycozmo' file in $CozmoDir\bin"
# Write-Host "    to Python IDLE instead of Sublime."
# Write-Host "GLHF"
# Write-Host "=========================================================="

if (Test-Path $Step1DoneFlag) {
    Remove-Item $Step1DoneFlag -Force
    Write-Host ">>> Cleaned up Step 1 marker file."
}

Write-Host ">>> Restarting system to apply final PATH/PYTHONPATH changes !!"
Restart-Computer -Force
exit
