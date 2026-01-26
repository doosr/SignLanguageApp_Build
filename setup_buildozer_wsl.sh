#!/bin/bash

echo "=========================================="
echo "Installation Buildozer dans WSL"
echo "=========================================="

# 1. Mise à jour du système
echo ""
echo "[1/6] Mise à jour du système..."
sudo apt update

# 2. Installation de Python et pip
echo ""
echo "[2/6] Installation de Python3 et pip..."
sudo apt install -y python3 python3-pip python3-venv

# 3. Installation des dépendances système
echo ""
echo "[3/6] Installation des dépendances système..."
sudo apt install -y git zip unzip openjdk-17-jdk wget
sudo apt install -y autoconf libtool pkg-config zlib1g-dev libncurses5-dev \
    libncursesw5-dev libtinfo5 cmake libffi-dev libssl-dev

# 4. Installation de Buildozer
echo ""
echo "[4/6] Installation de Buildozer et Cython..."
pip3 install --upgrade pip
# Install specific versions known to work together
pip3 install --upgrade buildozer
pip3 install cython==0.29.33
# Install python-for-android develop branch
pip3 install --upgrade git+https://github.com/kivy/python-for-android.git@develop

# 5. Ajouter pip au PATH
echo ""
echo "[5/6] Configuration du PATH..."
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

# 6. Vérification
echo ""
echo "[6/6] Vérification de l'installation..."
echo "Python: $(python3 --version)"
echo "Pip: $(pip3 --version)"
echo "Buildozer: $(buildozer --version 2>/dev/null || echo 'Redémarrez le terminal pour utiliser buildozer')"

echo ""
echo "=========================================="
echo "✅ Installation terminée !"
echo "=========================================="
echo ""
echo "IMPORTANT : Fermez et rouvrez votre terminal WSL, puis :"
echo "  cd /mnt/c/Users/dawse/Desktop/pfa"
echo "  buildozer android debug"
