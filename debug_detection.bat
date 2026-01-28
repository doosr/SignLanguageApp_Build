@echo off
echo ====================================
echo Flutter Gesture Detection Debugger
echo ====================================
echo.

echo [1] Checking device connection...
adb devices
if errorlevel 1 (
    echo ERROR: ADB not found! Install Android Platform Tools
    pause
    exit /b 1
)
echo.

echo [2] Clearing old logs...
adb logcat -c
echo.

echo [3] Starting Flutter app in new window...
start "Flutter Run" cmd /k "cd /d %~dp0flutter_app && flutter run --verbose"
echo.

echo [4] Waiting for app to start...
timeout /t 10
echo.

echo [5] Monitoring logs (Press Ctrl+C to stop)...
echo Looking for: Camera, Vision, TFLite, Hands, Inference errors
echo.
adb logcat | findstr /I "flutter Camera Vision TFLite ERROR Hands detected Inference prediction Confidence"
