# 🚀 Compilation APK avec WSL - Guide Rapide

## Étape 1: Copier le Projet dans WSL

```bash
# Depuis PowerShell Windows
wsl
cd ~
mkdir -p pfa_build
exit
```

```powershell
# Copier les fichiers depuis Windows vers WSL
wsl cp -r /mnt/c/Users/dawse/Desktop/pfa/* ~/pfa_build/
```

## Étape 2: Installer Buildozer (Première fois uniquement)

```bash
# Entrer dans WSL
wsl

# Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Installer les dépendances
sudo apt install -y python3 python3-pip python3-venv git zip unzip openjdk-17-jdk autoconf libtool pkg-config zlib1g-dev libncurses5-dev libncursesw5-dev libtinfo5 cmake libffi-dev libssl-dev

# Installer Buildozer
pip3 install --user buildozer cython

# Ajouter au PATH
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
source ~/.bashrc
```

## Étape 3: Compiler l'APK

```bash
# Aller dans le dossier du projet
cd ~/pfa_build

# Nettoyer (si recompilation)
buildozer android clean

# Compiler l'APK
buildozer -v android debug
```

**Durée estimée**: 30-45 minutes (première compilation)

## Étape 4: Récupérer l'APK

```bash
# L'APK sera dans :
ls ~/pfa_build/bin/*.apk

# Copier vers Windows
cp ~/pfa_build/bin/*.apk /mnt/c/Users/dawse/Desktop/
```

## 🎯 Commandes Rapides (Toutes en Une)

### Première Installation Complète

```bash
wsl
cd ~
mkdir -p pfa_build
cp -r /mnt/c/Users/dawse/Desktop/pfa/* ~/pfa_build/
cd ~/pfa_build
sudo apt update && sudo apt install -y python3 python3-pip git zip unzip openjdk-17-jdk autoconf libtool pkg-config zlib1g-dev libncurses5-dev libncursesw5-dev libtinfo5 cmake libffi-dev libssl-dev
pip3 install --user buildozer cython
export PATH=$PATH:~/.local/bin
buildozer -v android debug
cp ~/pfa_build/bin/*.apk /mnt/c/Users/dawse/Desktop/
```

### Recompilation (après changements)

```bash
wsl
cd ~/pfa_build
cp -r /mnt/c/Users/dawse/Desktop/pfa/* ~/pfa_build/
buildozer android clean
buildozer -v android debug
cp ~/pfa_build/bin/*.apk /mnt/c/Users/dawse/Desktop/
```

## ⚠️ Problèmes Courants

### "buildozer: command not found"

```bash
export PATH=$PATH:~/.local/bin
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
```

### "Java not found"

```bash
sudo apt install -y openjdk-17-jdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

### Erreur de mémoire

```bash
# Augmenter la mémoire WSL dans .wslconfig (Windows)
# C:\Users\dawse\.wslconfig
[wsl2]
memory=8GB
```

## ✅ Vérification

```bash
# Vérifier Python
python3 --version

# Vérifier Buildozer
buildozer --version

# Vérifier Java
java -version
```

---

**Prêt ?** Exécutez les commandes ci-dessus ! 🎉
