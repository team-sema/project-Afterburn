@echo off
setlocal

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"

if defined GODOT_EDITOR_PATH (
	set "GODOT_PATH=%GODOT_EDITOR_PATH%"
) else (
	set "GODOT_PATH=%PROJECT_ROOT%\..\..\Godot_v4.6-stable_mono_win64_console.exe"
)

if not exist "%GODOT_PATH%" (
	echo Godot executable not found at "%GODOT_PATH%". Set GODOT_EDITOR_PATH to the console executable. 1>&2
	exit /b 1
)

set "LOG_DIRECTORY=%PROJECT_ROOT%\.godot\codex-logs"
if not exist "%LOG_DIRECTORY%" mkdir "%LOG_DIRECTORY%"
set "LOG_FILE=%LOG_DIRECTORY%\godot-%RANDOM%-%RANDOM%-%RANDOM%.log"

"%GODOT_PATH%" --path "%PROJECT_ROOT%" --log-file "%LOG_FILE%" %*
exit /b %ERRORLEVEL%
