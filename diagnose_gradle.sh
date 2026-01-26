#!/bin/bash
# Diagnose the actual Gradle error

cd ~/pfa_build

echo "============================================"
echo "🔍 Diagnosing Gradle Error"
echo "============================================"
echo ""

# Check if distribution exists
if [ ! -d ".buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp" ]; then
    echo "❌ Distribution folder not found"
    echo "The build hasn't reached the Gradle stage yet"
    exit 1
fi

cd .buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp

echo "📁 In distribution folder:"
pwd
echo ""

echo "📄 Checking for gradle.properties..."
if [ -f "gradle.properties" ]; then
    echo "✓ gradle.properties exists"
    echo "Contents:"
    cat gradle.properties
else
    echo "❌ gradle.properties NOT FOUND - copying now..."
    cp ~/pfa_build/gradle.properties .
fi
echo ""

echo "🔍 Running Gradle with detailed output..."
echo "============================================"
echo ""

# Run Gradle directly with full output
./gradlew clean assembleDebug --stacktrace --info 2>&1 | tee ~/pfa_build/gradle_full.log

echo ""
echo "============================================"
echo "📊 Analysis"
echo "============================================"
echo ""

# Check for common errors
if grep -q "OutOfMemoryError\|Java heap space" ~/pfa_build/gradle_full.log; then
    echo "❌ MEMORY ERROR DETECTED"
    echo "   Despite increasing heap size, Gradle still ran out of memory"
    echo ""
    echo "   Possible solutions:"
    echo "   1. Increase WSL memory limit (edit .wslconfig on Windows)"
    echo "   2. Remove large dependencies (opencv, mediapipe)"
    echo "   3. Use Google Colab to build (has more RAM)"
    echo ""
elif grep -q "AAPT" ~/pfa_build/gradle_full.log; then
    echo "❌ ANDROID ASSET PACKAGING ERROR"
    echo "   Issue with packaging app resources"
    echo ""
elif grep -q "BUILD SUCCESSFUL" ~/pfa_build/gradle_full.log; then
    echo "✅ BUILD SUCCESSFUL!"
    echo ""
    ls -lh app/build/outputs/apk/debug/*.apk
else
    echo "❓ Unknown error - check the log above"
    echo ""
    echo "Last 30 lines of error:"
    tail -n 30 ~/pfa_build/gradle_full.log
fi

echo ""
echo "Full log saved to: ~/pfa_build/gradle_full.log"
