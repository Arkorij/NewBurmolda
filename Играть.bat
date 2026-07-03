@echo off
rem Launch Burmolda (Godot 4.7).
rem The Godot editor binary is NOT committed to the repo (it is ~170 MB and
rem is excluded via .gitignore), so on a fresh clone this script downloads
rem the portable Godot 4.7 engine once, then launches the project.
rem Kept ASCII-only on purpose: mixed Cyrillic + chcp in .bat files has
rem broken parsing on some Windows locales in the past.
setlocal

cd /d "%~dp0"
set "GODOT_DIR=%CD%\tools\godot"
set "GODOT_EXE=%GODOT_DIR%\Godot_v4.7-stable_win64.exe"
set "GODOT_ZIP=%GODOT_DIR%\godot.zip"
set "GODOT_URL=https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_win64.exe.zip"

if exist "%GODOT_EXE%" goto :launch

echo Godot 4.7 engine not found locally.
echo Downloading it once (about 80 MB, needs internet access)...
if not exist "%GODOT_DIR%" mkdir "%GODOT_DIR%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri '%GODOT_URL%' -OutFile '%GODOT_ZIP%' -TimeoutSec 180; Expand-Archive -Path '%GODOT_ZIP%' -DestinationPath '%GODOT_DIR%' -Force; Remove-Item '%GODOT_ZIP%'; exit 0 } catch { Write-Host $_.Exception.Message; exit 1 }"

if not exist "%GODOT_EXE%" goto :fail

:launch
start "" "%GODOT_EXE%" --path "%CD%"
goto :eof

:fail
echo.
echo Could not download Godot automatically (no internet, or firewall/antivirus blocked it).
echo Please download it yourself:
echo   https://godotengine.org/download/windows/  (Standard build, Windows x64)
echo and put Godot_v4.7-stable_win64.exe into this folder:
echo   %GODOT_DIR%
echo Then run this script again.
pause
