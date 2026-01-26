#!/bin/bash
# Complete fix for Gradle build issues
# Ensures gradle.properties is properly applied and kills old Gradle daemons

set -e

echo "============================================"
echo "🔧 Complete Gradle Fix & Rebuild"
echo "============================================"

cd ~/pfa_build

# 1. Kill any existing Gradle daemons (they cache old settings)
echo ""
echo "[1/6] Killing existing Gradle daemons..."
if [ -d ".buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp" ]; then
    cd .buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp
    ./gradlew --stop 2>/dev/null || echo "No Gradle daemon was running"
    cd ~/pfa_build
else
    echo "Distribution folder not found yet"
fi
echo "✓ Gradle daemons stopped"

# 2. Copy gradle.properties to multiple locations
echo ""
echo "[2/6] Copying gradle.properties to all necessary locations..."

# Main build directory
cp /mnt/c/Users/dawse/Desktop/pfa/gradle.properties ~/pfa_build/
echo "  ✓ Copied to ~/pfa_build/"

# User's home .gradle folder
mkdir -p ~/.gradle
cp /mnt/c/Users/dawse/Desktop/pfa/gradle.properties ~/.gradle/
echo "  ✓ Copied to ~/.gradle/"

# Distribution folder (if exists)
if [ -d ".buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp" ]; then
    cp /mnt/c/Users/dawse/Desktop/pfa/gradle.properties .buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp/
    echo "  ✓ Copied to distribution folder"
fi

# 3. Set environment variables
echo ""
echo "[3/6] Setting Gradle environment variables..."
export GRADLE_OPTS="-Xmx4096m -XX:MaxPermSize=512m -Dorg.gradle.jvmargs=-Xmx4096m"
export _JAVA_OPTIONS="-Xmx4096m"
echo "  ✓ GRADLE_OPTS=$GRADLE_OPTS"
echo "  ✓ _JAVA_OPTIONS=$_JAVA_OPTIONS"

# 4. Check how much RAM WSL has
echo ""
echo "[4/6] Checking WSL memory..."
free -h
echo ""
echo "⚠️  If 'available' memory is less than 4GB, the build might still fail"
echo "    In that case, close other applications or increase WSL memory limit"

# 5. Alternative: Try building with fewer assets
echo ""
echo "[5/6] Preparing buildozer.spec..."
cd ~/pfa_build

# Check if we should exclude some data
echo "Note: If this fails again, we may need to reduce asset size"
echo "      (e.g., exclude pickle files or compress models)"

# 6. Rebuild
echo ""
echo "============================================"
echo "⚙️  REBUILDING APK WITH INCREASED MEMORY"
echo "============================================"
echo "Time estimate: 2-5 minutes (dependencies already built)"
echo ""

# Use buildozer with explicit verbose logging
buildozer -v android debug 2>&1 | tee rebuild.log

# 7. Check result
echo ""
echo "============================================"
APK_FILE=$(ls bin/*.apk 2>/dev/null | head -n1)
if [ -f "$APK_FILE" ]; then
    echo "✅ BUILD SUCCESSFUL!"
    echo "============================================"
    echo ""
    echo "📱 APK generated:"
    ls -lh bin/*.apk
    
    # Show APK size
    APK_SIZE=$(du -h "$APK_FILE" | cut -f1)
    echo ""
    echo "APK size: $APK_SIZE"
    
    # Copy to Windows Desktop
    echo ""
    echo "📤 Copying to Windows Desktop..."
    cp bin/*.apk /mnt/c/Users/dawse/Desktop/
    echo "✓ APK copied to: C:\\Users\\dawse\\Desktop\\"
    echo ""
    echo "============================================"
    echo "🎉 SUCCESS! Your APK is ready!"
    echo "============================================"
else
    echo "❌ BUILD FAILED"
    echo "============================================"
    echo ""
    echo "Last 50 lines of build log:"
    tail -n 50 rebuild.log
    echo ""
    echo "Check rebuild.log for the full error"
    echo "The error is usually near the end of the log"
fi
