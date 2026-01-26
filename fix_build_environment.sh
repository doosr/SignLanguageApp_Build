#!/bin/bash
# Script to fix buildozer environment for Python 3 compatibility
# Run this BEFORE attempting to build the APK

set -e

echo "============================================"
echo "🔧 Fixing Buildozer Environment"
echo "============================================"

# 1. Clean existing build artifacts
echo ""
echo "[1/5] Cleaning previous build artifacts..."
cd ~/pfa_build
if [ -d ".buildozer" ]; then
    echo "Removing old .buildozer directory..."
    rm -rf .buildozer
fi
if [ -d "bin" ]; then
    echo "Removing old bin directory..."
    rm -rf bin
fi
echo "✓ Cleanup complete"

# 2. Reinstall correct versions
echo ""
echo "[2/5] Reinstalling buildozer dependencies..."

# Uninstall existing versions
pip3 uninstall -y cython buildozer python-for-android 2>/dev/null || true

# Install specific compatible versions
echo "Installing Cython 0.29.33..."
pip3 install cython==0.29.33

echo "Installing latest Buildozer..."
pip3 install --upgrade buildozer

echo "Installing python-for-android develop branch..."
pip3 install --upgrade git+https://github.com/kivy/python-for-android.git@develop

echo "✓ Dependencies installed"

# 3. Verify installations
echo ""
echo "[3/5] Verifying installations..."
echo "Python: $(python3 --version)"
echo "Pip: $(pip3 --version)"
echo "Cython: $(python3 -c 'import Cython; print(Cython.__version__)')"
echo "Buildozer: $(buildozer --version)"
echo "✓ Verification complete"

# 4. Pre-download Android SDK/NDK (optional but recommended)
echo ""
echo "[4/5] Initializing buildozer (this will download SDK/NDK)..."
echo "This may take a while on first run..."
buildozer android debug 2>&1 | head -n 50 || true
echo "✓ Initialization started"

# 5. Final instructions
echo ""
echo "============================================"
echo "✅ Environment Fix Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Run: bash compile_apk_wsl.sh"
echo "   OR"
echo "2. Run: buildozer -v android debug"
echo ""
echo "If you still encounter the 'long' error:"
echo "- Check that Cython is 0.29.33: python3 -c 'import Cython; print(Cython.__version__)'"
echo "- Try: buildozer android clean"
echo "- Then rebuild with: buildozer -v android debug"
echo ""
