@echo off
setlocal
if not exist "%~dp0Blackwall-Defender.ps1" (
 echo Keep this launcher in the extracted Blackwall Defender folder. Create a desktop shortcut to it instead of moving it alone.
 pause
 exit /b 1
)
start "Blackwall Defender" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0Blackwall-Defender.ps1"

