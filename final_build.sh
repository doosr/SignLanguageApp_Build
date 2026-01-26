#!/bin/bash
# Final rebuild with corrected Java options (no MaxPermSize)

set -e

echo "============================================"
echo "🎯 Final APK Build - Corrected Java Options"
echo "============================================"

cd ~/pfa_build

# 1. Stop any Gradle daemons with old settings
echo ""
echo "[1/5] Stopping old Gradle daemons..."
if [ -d ".buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp" ]; then
    cd .buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp
    ./gradlew --stop 2>/dev/null || true
    cd ~/pfa_build
fi
echo "✓ Done"

# 2. Copy corrected gradle.properties
echo ""
echo "[2/5] Copying corrected gradle.properties..."
cp /mnt/c/Users/dawse/Desktop/pfa/gradle.properties ~/pfa_build/
mkdir -p ~/.gradle
cp /mnt/c/Users/dawse/Desktop/pfa/gradle.properties ~/.gradle/
if [ -d ".buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp" ]; then
    cp /mnt/c/Users/dawse/Desktop/pfa/gradle.properties .buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp/
fi
echo "✓ Gradle properties updated (MaxPermSize removed)"

# 3. Set corrected environment variables
echo ""
echo "[3/5] Setting corrected environment variables..."
export GRADLE_OPTS="-Xmx4096m -Dorg.gradle.jvmargs=-Xmx4096m"
export _JAVA_OPTIONS="-Xmx4096m"
echo "✓ GRADLE_OPTS=$GRADLE_OPTS"
echo "✓ _JAVA_OPTIONS=$_JAVA_OPTIONS"

# 4. Show Java version
echo ""
echo "[4/5] Java version info..."
java -version 2>&1 | head -n 3
echo ""

# 5. Rebuild
echo ""
echo "============================================"
echo "⚙️  REBUILDING APK"
echo "============================================"
echo "All dependencies are built - this will be quick!"
echo ""

buildozer -v android debug 2>&1 | tee final_build.log

# 6. Check result
echo ""
echo "============================================"
APK_FILE=$(ls bin/*.apk 2>/dev/null | head -n1)
if [ -f "$APK_FILE" ]; then
    echo "✅ BUILD SUCCESSFUL!"
    echo "============================================"
    echo ""
    echo "📱 APK Details:"
    ls -lh bin/*.apk
    APK_SIZE=$(du -h "$APK_FILE" | cut -f1)
    echo ""
    echo "   File: $(basename $APK_FILE)"
    echo "   Size: $APK_SIZE"
    
    # Copy to Windows Desktop
    echo ""
    echo "📤 Copying to Windows Desktop..."
    cp bin/*.apk /mnt/c/Users/dawse/Desktop/
    echo "✓ APK available at: C:\\Users\\dawse\\Desktop\\$(basename $APK_FILE)"
    echo ""
    echo "============================================"
    echo "🎉 SUCCESS!"
    echo "============================================"
    echo ""
    echo "Next steps:"
    echo "1. Transfer APK to your Android device"
    echo "2. Enable 'Install from Unknown Sources'"
    echo "3. Install and test the app"
else
    echo "❌ BUILD FAILED"
    echo "============================================"
    echo ""
    echo "Showing last error:"
    grep -B 5 -A 10 "FAILED\|ERROR\|Exception" final_build.log | tail -n 30
fi
