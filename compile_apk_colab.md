# Compiler APK avec Google Colab

## Étapes complètes

### 1. Préparer vos fichiers

Créer un dossier ZIP avec :

```
project/
├── main.py
├── buildozer.spec
├── model.p
├── model_sequence.p
├── translations.json
├── hand_landmarker.task
└── data.pickle (optionnel si trop gros)
```

### 2. Ouvrir Google Colab

1. Aller sur : <https://colab.research.google.com/>
2. Créer un nouveau notebook
3. Copier ce code dans des cellules :

#### Cellule 1 : Installation

```python
!pip install buildozer
!pip install cython==0.29.33
!sudo apt-get update
!sudo apt-get install -y git zip unzip openjdk-17-jdk wget
!sudo apt-get install -y python3-pip autoconf libtool pkg-config zlib1g-dev \
    libncurses5-dev libncursesw5-dev libtinfo5 cmake libffi-dev libssl-dev
```

#### Cellule 2 : Upload projet

```python
from google.colab import files
uploaded = files.upload()  # Sélectionner votre ZIP

# Extraire
!unzip -q *.zip -d project
%cd project
```

#### Cellule 3 : Compiler APK

```python
# Compiler (prend 20-40 minutes la première fois)
!buildozer android debug

# Télécharger l'APK
from google.colab import files
import os

apk_path = None
for root, dirs, filenames in os.walk('.'):
    for f in filenames:
        if f.endswith('.apk'):
            apk_path = os.path.join(root, f)
            break

if apk_path:
    files.download(apk_path)
    print(f"APK téléchargé : {apk_path}")
else:
    print("APK non trouvé!")
```

### 3. Installer sur Android

1. Activer "Sources inconnues" sur votre téléphone
2. Transférer l'APK sur Android
3. Installer et lancer

---

## Option B : WSL (Windows Subsystem for Linux)

Vous avez déjà les scripts :

- `01_install_wsl.ps1`
- `02_setup_buildozer.sh`

### Utiliser WSL

```powershell
# 1. Exécuter depuis PowerShell (Admin)
.\01_install_wsl.ps1

# 2. Redémarrer Windows

# 3. Ouvrir WSL et exécuter
bash 02_setup_buildozer.sh

# 4. Compiler
cd /mnt/c/Users/dawse/Desktop/pfa
buildozer android debug
```

---

## Option C : Linux natif

Si vous avez accès à un PC Linux :

```bash
# Installation
sudo apt update
sudo apt install -y git zip unzip openjdk-17-jdk python3-pip
pip3 install buildozer cython==0.29.33

# Compilation
cd /path/to/pfa
buildozer android debug
```

---

## 🎯 Fichier APK final

Sera créé dans :

```
pfa/bin/signlanguageapp-0.1-arm64-v8a-debug.apk
```

## Tester l'APK

1. **Transférer sur Android** (ADB, email, USB)
2. **Installer l'APK**
3. **Accorder permissions** : Caméra, Microphone
4. **Se connecter au même WiFi que l'ESP32**
5. **Entrer l'IP ESP32** : `192.168.1.XXX`
6. **Cliquer "Connect ESP32"**
7. **Le flux vidéo devrait s'afficher !**
