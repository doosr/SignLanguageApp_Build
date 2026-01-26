#!/bin/bash
# Script de RECOMPILATION rapide
# Utiliser après avoir modifié main.py ou buildozer.spec

echo "🔄 RECOMPILATION APK"
echo "===================="

# Activer environnement
source ~/buildozer-env/bin/activate

# Aller dans le dossier
cd ~/pfa_build

# Copier les fichiers modifiés
echo "📋 Mise à jour des fichiers..."
cp -r /mnt/c/Users/dawse/Desktop/pfa/*.py .
cp -r /mnt/c/Users/dawse/Desktop/pfa/*.spec .
cp -r /mnt/c/Users/dawse/Desktop/pfa/*.json .
cp -r /mnt/c/Users/dawse/Desktop/pfa/*.p .
cp -r /mnt/c/Users/dawse/Desktop/pfa/*.task .
cp -r /mnt/c/Users/dawse/Desktop/pfa/*.png . 2>/dev/null

echo "✓ Fichiers mis à jour"

# Nettoyer
echo ""
echo "🧹 Nettoyage..."
buildozer android clean

# Recompiler
echo ""
echo "⚙️  Compilation... (10-15 min)"
buildozer android debug

# Copier APK
echo ""
echo "📤 Copie vers Windows..."
cp bin/*.apk /mnt/c/Users/dawse/Desktop/

echo ""
echo "✅ TERMINÉ !"
echo "APK disponible sur votre Desktop Windows"
