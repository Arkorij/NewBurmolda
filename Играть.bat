@echo off
rem Launch Burmolda (Godot 4.7) - runs the project's main scene.
rem %CD% (no trailing backslash) avoids the "\" eating the closing quote in --path.
cd /d "%~dp0"
start "" "%CD%\tools\godot\Godot_v4.7-stable_win64.exe" --path "%CD%"
