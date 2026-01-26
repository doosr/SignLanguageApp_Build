#!/bin/bash
# Script de compilation finale APK avec toutes les mises à jour
# Date: 2026-01-25

set -e

echo "=================================================="
echo "📱 COMPILATION APK - VERSION FINALE"
echo "=================================================="
echo ""
echo "✨ Mises à jour incluses:"
echo "  ✅ Bug ligne 114 corrigé (info_layout)"
echo "  ✅ Matplotlib ajouté aux dépendances"
echo "  ✅ NDK API augmenté à 24"
echo "  ✅ Synthèse Vocale gTTS (Arabe lent/correct)"
echo "  ✅ Images Illustratives (Recherche récursive)"
echo "  ✅ Branche stable Python-for-android (Master)"
echo "  ✅ Nettoyage complet automatique"
echo ""

# 0. NETTOYAGE COMPLET (Obligatoire pour corriger erreur cv2/python3.14)
echo "[0/8] Nettoyage complet des anciens fichiers de build..."
rm -rf ~/pfa_build/.buildozer
echo "✓ Nettoyé"


# 1. Activer environnement
if [ -z "$VIRTUAL_ENV" ]; then
    echo "[1/8] Activation environnement virtuel..."
    source ~/buildozer-env/bin/activate
    echo "✓ Activé"
else
    echo "[1/8] Environnement déjà actif"
fi

cd ~/pfa_build

# 2. Synchroniser les fichiers
echo ""
echo "[2/8] Synchronisation des fichiers depuis Windows..."
cp -r /mnt/c/Users/dawse/Desktop/pfa/* ~/pfa_build/
echo "✓ Fichiers synchronisés"

# 3. Vérifier les fichiers essentiels
echo ""
echo "[3/8] Vérification des fichiers..."
REQUIRED_FILES=(
    "main.py"
    "buildozer.spec"
    "model.p"
    "model_sequence.p"
    "hand_landmarker.task"
    "translations.json"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ❌ MANQUANT: $file"
    fi
done

# 4. Configurer Gradle
echo ""
echo "[4/8] Configuration Gradle..."
export GRADLE_OPTS="-Xmx4096m -Dorg.gradle.jvmargs=-Xmx4096m"
export _JAVA_OPTIONS="-Xmx4096m"

cp gradle.properties ~/.gradle/ 2>/dev/null || true

echo "✓ Gradle configuré (4GB RAM)"

# 5. Nettoyer builds précédents
echo ""
echo "[5/8] Nettoyage des builds précédents..."
rm -f bin/*.apk 2>/dev/null || true
rm -rf .buildozer/android/platform/build-arm64-v8a/build/python-installs 2>/dev/null || true
echo "✓ Nettoyé"

# 6. Afficher la configuration
echo ""
echo "[6/8] Configuration finale:"
echo "  Package: org.test.signlanguageapp"
echo "  Version: 0.1.0"
echo "  Android API: 31"
echo "  Min API: 24 (Android 7.0+)"
echo "  Architecture: arm64-v8a"
echo "  Requirements: python3,kivy,opencv,mediapipe,plyer,numpy,pillow,scikit-learn,gtts"

# 7. COMPILATION
echo ""
echo "=================================================="
echo "⚙️  COMPILATION EN COURS"
echo "=================================================="
echo "⏱️  Temps estimé: 10-20 minutes"
echo "📝 Logs sauvegardés dans: compilation_finale.log"
echo ""

buildozer -v android debug 2>&1 | tee compilation_finale.log

# 8. Vérification et copie
echo ""
echo "=================================================="
APK_FILE=$(ls bin/*.apk 2>/dev/null | head -n1)

if [ -f "$APK_FILE" ]; then
    APK_SIZE=$(du -h "$APK_FILE" | cut -f1)
    APK_DATE=$(date +%Y%m%d-%H%M%S)
    NEW_NAME="SignLanguageApp-v0.1.0-$APK_DATE.apk"
    
    echo "✅ COMPILATION RÉUSSIE!"
    echo "=================================================="
    echo ""
    echo "📱 APK créé:"
    echo "   Fichier: $APK_FILE"
    echo "   Taille: $APK_SIZE"
    echo ""
    echo "📤 Copie vers Windows Desktop..."
    cp "$APK_FILE" "/mnt/c/Users/dawse/Desktop/$NEW_NAME"
    echo "✓ APK copié: C:\\Users\\dawse\\Desktop\\$NEW_NAME"
    echo ""
    echo "=================================================="
    echo "🎉 APK PRÊT À INSTALLER!"
    echo "=================================================="
    echo ""
    echo "📋 Prochaines étapes:"
    echo "1. Transférez l'APK sur votre téléphone Android"
    echo "2. Désinstallez l'ancienne version (si présente)"
    echo "3. Installez le nouvel APK"
    echo "4. Autorisez les permissions (Caméra, Micro)"
    echo "5. Profitez des nouvelles fonctionnalités! 🚀"
    echo ""
    echo "✨ Nouvelles fonctionnalités:"
    echo "   • Bouton MODE LETTRES/MOTS"
    echo "   • Sélecteur Caméra Téléphone/ESP32"
    echo "   • Animations professionnelles sur détection"
    echo "   • Interface sans emojis (texte pur)"
    echo "   • Stabilité améliorée"
    echo ""
else
    echo "❌ ÉCHEC DE LA COMPILATION"
    echo "=================================================="
    echo ""
    echo "🔍 Dernières erreurs:"
    tail -n 100 compilation_finale.log | grep -i "error\|failed\|exception" | tail -n 20
    echo ""
    echo "📝 Consultez le log complet: compilation_finale.log"
    echo ""
    echo "💡 Solutions possibles:"
    echo "1. Vérifiez que tous les fichiers sont présents"
    echo "2. Augmentez la mémoire Gradle si nécessaire"
    echo "3. Nettoyez complètement: rm -rf .buildozer"
    echo "4. Relancez la compilation"
fi

echo ""
echo "=================================================="
