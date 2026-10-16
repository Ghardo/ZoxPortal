@echo off
set "TEMP_FILE=%TEMP%\zoxide_target.txt"
if exist "%TEMP_FILE%" del "%TEMP_FILE%"

REM Bring our own Alacritty window to the foreground in parallel (PowerToys often starts it in the background)
start "" /b pwsh -NoProfile -File "%~dp0focus_window.ps1" -Ancestor <NUL >NUL 2>&1

REM fzf runs directly in this Alacritty window
zoxide query -l | fzf --no-sort --tiebreak=index --scheme=path > "%TEMP_FILE%"

if not exist "%TEMP_FILE%" exit
for %%I in ("%TEMP_FILE%") do if %%~zI == 0 exit

set /p TARGET_PATH=<"%TEMP_FILE%"
del "%TEMP_FILE%"

if "%TARGET_PATH%"=="" exit

REM Start the backend detached and hidden.
REM Alacritty then closes automatically right away.
start "" pwsh -NoProfile -WindowStyle Hidden -File "%~dp0zoxide_backend.ps1" "%TARGET_PATH%"