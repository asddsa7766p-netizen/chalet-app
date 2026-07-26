@echo off
REM Build script for Friends Chalets production release
cd /d C:\Users\palestine\Desktop\app
echo Cleaning previous builds...
call flutter clean
echo.
echo Building release APK...
call flutter build apk --release > build_log_apk.txt 2>&1
echo APK Build Status: %ERRORLEVEL% >> build_log_apk.txt
echo.
echo Building release App Bundle...
call flutter build appbundle --release > build_log_bundle.txt 2>&1
echo Bundle Build Status: %ERRORLEVEL% >> build_log_bundle.txt
echo.
echo Build complete! Check build_log_apk.txt and build_log_bundle.txt for details.
pause
