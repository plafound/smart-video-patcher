@echo off
setlocal

title Smart Video Patcher

echo.
echo ==================================================
echo             SMART VIDEO PATCHER v1
echo          TikTok + Instagram Reels
echo ==================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass ^
    -File "%~dp0patcher.ps1"

echo.
echo ==================================================
echo          PATCHER SELESAI / ERROR
echo ==================================================
echo.
echo Tekan tombol apa saja untuk menutup...
pause >nul