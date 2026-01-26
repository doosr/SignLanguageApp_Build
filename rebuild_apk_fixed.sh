#!/bin/bash
# Script de recompilation APK après correction du bug
# Usage: bash rebuild_apk_fixed.sh

set -e

echo "============================================"
echo "🔧 Recompilation APK - Version Corrigée"
echo "============================================"
echo ""
echo "Bug corrigé: ligne 114 (self.info_layout) supprimée"
echo ""

# Activer l'environnement virtuel si nécessaire
if [ -z "$VIRTUAL_ENV" ]; then
    echo "[1/6] Activation de l'environnement virtuel..."
    source ~/buildozer-env/bin/activate
    echo "✓ Environnement activé"
else
    echo "[1/6] Environnement virtuel déjà actif"
fi

cd ~/pfa_build

# Copier les fichiers corrigés
echo ""
echo "[2/6] Copie des fichiers corrigés depuis Windows..."
cp -r /mnt/c/Users/dawse/Desktop/pfa/* ~/pfa_build/
echo "✓ Fichiers mis à jour"

# Copier gradle.properties
echo ""
echo "[3/6] Configuration Gradle..."
cp /mnt/c/Users/dawse/Desktop/pfa/gradle.properties ~/pfa_build/
mkdir -p ~/.gradle
cp /mnt/c/Users/dawse/Desktop/pfa/gradle.properties ~/.gradle/
if [ -d ".buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp" ]; then
    cp /mnt/c/Users/dawse/Desktop/pfa/gradle.properties .buildozer/android/platform/build-arm64-v8a/dists/signlanguageapp/
fi
echo "✓ Gradle configuré"

# Variables d'environnement
echo ""
echo "[4/6] Configuration des variables Java..."
export GRADLE_OPTS="-Xmx4096m -Dorg.gradle.jvmargs=-Xmx4096m"
export _JAVA_OPTIONS="-Xmx4096m"
echo "✓ Variables définies"

# Nettoyer l'ancien APK
echo ""
echo "[5/6] Nettoyage..."
rm -f bin/*.apk 2>/dev/null || true
echo "✓ Ancien APK supprimé"

# Recompiler
echo ""
echo "============================================"
echo "⚙️  COMPILATION DE L'APK CORRIGÉ"
echo "============================================"
echo "Temps estimé: 2-5 minutes (dépendances déjà buildées)"
echo ""

buildozer -v android debug 2>&1 | tee rebuild_fixed.log

# Vérifier le résultat
echo ""
echo "============================================"
APK_FILE=$(ls bin/*.apk 2>/dev/null | head -n1)
if [ -f "$APK_FILE" ]; then
    echo "✅ COMPILATION RÉUSSIE!"
    echo "============================================"
    echo ""
    echo "📱 Nouveau APK corrigé:"
    ls -lh bin/*.apk
    APK_SIZE=$(du -h "$APK_FILE" | cut -f1)
    echo "   Taille: $APK_SIZE"
    
    # Copier vers Windows Desktop
    echo ""
    echo "📤 Copie vers Windows Desktop..."
    NEW_NAME="SignLanguageApp-fixed-$(date +%Y%m%d-%H%M%S).apk"
    cp "$APK_FILE" "/mnt/c/Users/dawse/Desktop/$NEW_NAME"
    echo "✓ APK copié: C:\\Users\\dawse\\Desktop\\$NEW_NAME"
    echo ""
    echo "============================================"
    echo "🎉 APK CORRIGÉ PRÊT!"
    echo "============================================"
    echo ""
    echo "📋 Prochaines étapes:"
    echo "1. Désinstallez l'ancienne version de l'app sur votre téléphone"
    echo "2. Transférez le nouvel APK: $NEW_NAME"
    echo "3. Installez et testez"
    echo ""
else
    echo "❌ ÉCHEC DE LA COMPILATION"
    echo "============================================"
    echo ""
    echo "Erreur dans les logs:"
    tail -n 50 rebuild_fixed.log | grep -A 10 "ERROR\|FAILED\|Exception"
fi
