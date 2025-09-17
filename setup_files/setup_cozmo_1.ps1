<#
 Cozmoball Setup Script for Windows
 To run: 
    1. Open PowerShell as user (not admin!!)
    2. Navigate to the directory containing this script
    3. Allow execution: Set-Executionpolicy Bypass -Scope Process -Force 
    4. Execute: .\setup_cozmo_1.ps1
#>


# Exit if any error occurs
$ErrorActionPreference = "Stop"


# ---- USER DETAILS  ----
$Username = $env:USERNAME
$UserDir  = "C:\Users\$Username"
$CozmoDir = "$UserDir\eazy_cozmo_ai_ball_detection"
$Desktop  = "$UserDir\Desktop"


Write-Host ">>> Please make sure these are installed manually first: iTunes"
Write-Host ">>> Also make sure you are running PowerShell as User, and not Admin"
Write-Host "`nPress ENTER to continue..."
Read-Host

Write-Host "=== Starting Cozmo Environment Setup for user: $Username ===`n"


$Step1DoneFlag = "$env:TEMP\cozmo_step1_done.flag"

# ----------------------------------------------------------
# 1. AUTO INSTALLING APPS (first run only)
# ----------------------------------------------------------
if (-not (Test-Path $Step1DoneFlag)) {
    Write-Host ">>> First-time setup detected: Installing required apps !!"

    Write-Host ">>> Installing Sublime Text !!"
    winget install --id SublimeHQ.SublimeText.4 -e --silent --accept-package-agreements --accept-source-agreements
    Write-Host ">>> Installation successful."

    Write-Host ">>> Installing Python 3.9.4 !!"
    $PythonInstaller = "$env:TEMP\python-3.9.4-amd64.exe"
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.9.4/python-3.9.4-amd64.exe" -OutFile $PythonInstaller
    # Silent install, all users, add to PATH
    Start-Process -FilePath $PythonInstaller -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0" -Wait
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


# ----------------------------------------------------------
# 2. CLONING REPO 
# ----------------------------------------------------------
if (!(Test-Path $CozmoDir)) {
    Write-Host ">>> Cloning easy_cozmo repository !!"
    Set-Location $UserDir
    git clone -b no-server https://github.com/HBJ-Backend/eazy_cozmo_ai_ball_detection.git
}
Set-Location $CozmoDir
git fetch
git checkout no-server


# ----------------------------------------------------------
# 3. COZMO DEPENDENCIES 
# ----------------------------------------------------------
Write-Host ">>> Installing Python libraries !!"


python -m pip install --upgrade pip
pip install easy_cozmo
pip install scipy imutils pillow
pip install yolov5

Write-Host ">>> Installing cozmoclad 3.6.6 !!"
$CozmoWhl = "$CozmoDir\cozmoclad-3.6.6-py3-none-any.whl"
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/DDLbots/cozmo-python-sdk/refs/heads/master/cozmoclad/cozmoclad-3.6.6-py3-none-any.whl" `
  -OutFile $CozmoWhl
pip install --user $CozmoWhl

pip3 install --user Pillow numpy PyOpenGL https://cozmosdk.anki.bot/1.4.12/cozmoclad-3.6.6-py3-none-any.whl https://cozmosdk.anki.bot/1.4.12/cozmo-1.4.12-py3-none-any.whl

# ----------------------------------------------------------
# 4. SUBLIME BUILD SYSTEM 
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
# 5. CREATING DESKTOP SHORTCUTS 
# ----------------------------------------------------------
Write-Host ">>> Creating desktop shortcuts !!"
$ChallengeUrl = "https://forms.gle/RGU69596cgwWEdKC7"


@"
[InternetShortcut]
URL=$ChallengeUrl
"@ | Out-File "$Desktop\Challenge_Submission.url" -Encoding ASCII



# ----------------------------------------------------------
# 6. FLAG CLEANUP + FINAL RESTART
# ----------------------------------------------------------

if (Test-Path $Step1DoneFlag) {
    Remove-Item $Step1DoneFlag -Force
    Write-Host ">>> Cleaned up Step 1 marker file."
}

Write-Host ">>> Next please run the following script to complete the setup: "
Write-Host "    - setup_cozmo_2.ps1"
Write-Host ">>> Note that for the above script, you need an Administrator shell."
exit