#!/bin/bash
# Rebuild script with increased Gradle memory
# Fixes "Java heap space" error

set -e

echo "============================================"
echo "🔧 Rebuilding APK with Increased Memory"
echo "============================================"

cd ~/pfa_build

# 1. Copy gradle.properties to project
echo ""
echo "[1/4] Copying gradle.properties with increased heap size..."
cp /mnt/c/Users/dawse/Desktop/pfa/gradle.properties ~/pfa_build/
echo "✓ Gradle heap size increased to 4GB"

# 2. Copy to distribution folder (where Gradle actually runs)
echo ""
echo "[2/4] Copying to distribution folder..."
if [ -d ".buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp" ]; then
    cp gradle.properties .buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp/
    echo "✓ Copied to distribution folder"
else
    echo "⚠️  Distribution folder not found (will be created during build)"
fi

# 3. Set GRADLE_OPTS environment variable as backup
echo ""
echo "[3/4] Setting GRADLE_OPTS environment variable..."
export GRADLE_OPTS="-Xmx4096m -XX:MaxPermSize=512m"
echo "✓ GRADLE_OPTS=$GRADLE_OPTS"

# 4. Rebuild (no clean needed - just repackage)
echo ""
echo "============================================"
echo "⚙️  REBUILDING APK"
echo "============================================"
echo "This should be quick (~2-5 minutes)"
echo "All dependencies are already built!"
echo ""

buildozer -v android debug

# 5. Check result
echo ""
echo "============================================"
if [ -f "bin/*.apk" ]; then
    echo "✅ BUILD SUCCESSFUL!"
    echo "============================================"
    echo ""
    echo "📱 APK generated:"
    ls -lh bin/*.apk
    
    # Copy to Windows Desktop
    echo ""
    echo "📤 Copying to Windows Desktop..."
    cp bin/*.apk /mnt/c/Users/dawse/Desktop/
    echo "✓ APK copied to: C:\\Users\\dawse\\Desktop\\"
    echo ""
    echo "============================================"
    echo "🎉 DONE!"
    echo "============================================"
else
    echo "❌ Build failed again"
    echo "Check the error above"
fi
