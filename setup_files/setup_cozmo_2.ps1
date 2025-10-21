<#
 Cozmoball Setup Script for Windows
 To run: 
    1. Open PowerShell as Administrator
    2. Navigate to the directory containing this script
    3. Allow execution: Set-Executionpolicy Bypass -Scope Process -Force 
    4. Execute: .\setup_cozmo_2.ps1
#>


# Exit if any error occurs
$ErrorActionPreference = "Stop"


# ---- USER DETAILS  ----
$Username = $env:USERNAME
$UserDir  = "C:\Users\$Username"
$CozmoDir = "$UserDir\eazy_cozmo_ai_ball_detection"
$Desktop  = "$UserDir\Desktop"


$PathValue = "$CozmoDir\bin"
$PythonPathValue = "$CozmoDir"


Write-Host ">>> Setting PATH and PYTHONPATH !!"

# Add to PATH if not already present
$oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($oldPath -notlike "$PathValue") {
    [Environment]::SetEnvironmentVariable("Path", "$oldPath;$PathValue", "Machine") 
    Write-Host "Added $PathValue to PATH"
}

[Environment]::SetEnvironmentVariable("PYTHONPATH", $PythonPathValue, "User")
Write-Host "Set PYTHONPATH=$PythonPathValue"

Write-Host ">>> Moving Warning Suppression Files !!"

Write-Host ">>> Moving experimental.py !!"


# Move experimental.py
Move-Item -Path "$CozmoDir\warning_suppression_files\experimental.py" `
          -Destination "$UserDir\AppData\Local\Programs\Python\Python39\Lib\site-packages\yolov5\models" -Force

Write-Host ">>> Moving __init__.py !!"

# Move __init__.py
Move-Item -Path "$CozmoDir\warning_suppression_files\__init__.py" `
          -Destination "$UserDir\AppData\Local\Programs\Python\Python39\Lib\site-packages\pkg_resources\" -Force

Write-Host ">>> Moving autocast_mode.py !!"

# Move autocast_mode.py
Move-Item -Path "$CozmoDir\warning_suppression_files\autocast_mode.py" `
          -Destination "$UserDir\AppData\Local\Programs\Python\Python39\Lib\site-packages\torch\cuda\amp" -Force



Write-Host ">>> Restarting system to apply final PATH/PYTHONPATH changes !!"
Restart-Computer -Force
exit