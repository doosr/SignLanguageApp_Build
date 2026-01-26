#!/bin/bash
# Script de compilation APK automatique pour WSL
# Exécuter avec: bash compile_apk_wsl.sh

set -e  # Arrêter en cas d'erreur

echo "============================================"
echo "🚀 Compilation APK - SignFlow"
echo "============================================"

# 1. Créer le dossier de build
echo ""
echo "📁 Création du dossier de build..."
mkdir -p ~/pfa_build
cd ~/pfa_build

# 2. Copier les fichiers depuis Windows
echo ""
echo "📋 Copie des fichiers du projet..."
cp -r /mnt/c/Users/dawse/Desktop/pfa/* ~/pfa_build/
echo "✓ Fichiers copiés"

# 3. Vérifier Python
echo ""
echo "🐍 Vérification de Python..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 non trouvé. Installation..."
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv
else
    echo "✓ Python3 installé: $(python3 --version)"
fi

# 4. Vérifier Buildozer
echo ""
echo "🔧 Vérification de Buildozer..."
if ! command -v buildozer &> /dev/null; then
    echo "❌ Buildozer non trouvé. Installation des dépendances..."
    
    # Installer les dépendances système
    sudo apt update
    sudo apt install -y \
        git zip unzip openjdk-17-jdk autoconf libtool \
        pkg-config zlib1g-dev libncurses5-dev libncursesw5-dev \
        libtinfo5 cmake libffi-dev libssl-dev
    
    # Installer Buildozer
    echo "📦 Installation de Buildozer..."
    pip3 install --user buildozer cython
    
    # Ajouter au PATH
    export PATH=$PATH:~/.local/bin
    echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
    
    echo "✓ Buildozer installé"
else
    echo "✓ Buildozer déjà installé: $(buildozer --version)"
fi

# 5. Nettoyer les anciens builds
echo ""
echo "🧹 Nettoyage des anciens builds..."
if [ -d ".buildozer" ]; then
    buildozer android clean
fi

# 6. Lancer la compilation
echo ""
echo "============================================"
echo "⚙️  COMPILATION DE L'APK"
echo "============================================"
echo "⏱️  Durée estimée: 30-45 minutes (première fois)"
echo "⏱️  Durée estimée: 10-15 minutes (recompilations)"
echo ""

buildozer -v android debug

# 7. Vérifier le résultat
echo ""
echo "============================================"
if [ -f "bin/*.apk" ]; then
    echo "✅ COMPILATION RÉUSSIE !"
    echo "============================================"
    echo ""
    echo "📱 APK généré:"
    ls -lh bin/*.apk
    
    # Copier vers Windows Desktop
    echo ""
    echo "📤 Copie vers Windows Desktop..."
    cp bin/*.apk /mnt/c/Users/dawse/Desktop/
    echo "✓ APK copié vers: C:\Users\dawse\Desktop\"
    echo ""
    echo "============================================"
    echo "🎉 TERMINÉ !"
    echo "============================================"
    echo ""
    echo "Installez l'APK sur votre téléphone Android"
else
    echo "❌ ERREUR: APK non trouvé"
    echo "Vérifiez les logs ci-dessus"
fi
