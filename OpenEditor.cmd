@echo off
setlocal
set "GODOT_EXE=D:\Tool\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if defined GODOT_PATH if exist "%GODOT_PATH%" set "GODOT_EXE=%GODOT_PATH%"
if not exist "%GODOT_EXE%" (
  echo Godot was not found. Import project.godot into Godot 4.
  pause
  exit /b 1
)
start "" "%GODOT_EXE%" --editor --path "%~dp0."
