# 📚 Guide Complet de Déploiement

## Vue d'ensemble

```
┌─────────────────┐
│   PC Windows    │  ← Développement Python/Kivy
│   (main.py)     │
└────────┬────────┘
         │
         ├─────────────────────────────┐
         │                             │
         ▼                             ▼
┌─────────────────┐         ┌──────────────────┐
│  ESP32-CAM      │         │  Android (APK)   │
│  (C++ Arduino)  │◄───────►│  (Kivy compilé)  │
│  Flux vidéo     │  WiFi   │  Affichage       │
└─────────────────┘         └──────────────────┘
```

---

## 🔧 Partie 1 : ESP32-CAM (C/C++ Arduino)

### Fichier : `esp32_cam_full.ino`

**Ce fichier NE PEUT PAS être Python !** L'ESP32 exécute du C/C++.

### Configuration

1. **Installer Arduino IDE** : <https://www.arduino.cc/en/software>

2. **Ajouter support ESP32** :
   - Fichier → Préférences
   - URLs gestionnaire : `https://dl.espressif.com/dl/package_esp32_index.json`
   - Outils → Gestionnaire de cartes → Installer "esp32"

3. **Sélectionner carte** :
   - Type : AI Thinker ESP32-CAM
   - Port : COM approprié

4. **Modifier WiFi** dans `esp32_cam_full.ino` :

   ```cpp
   const char* ssid = "VOTRE_WIFI";
   const char* password = "VOTRE_PASSWORD";
   ```

5. **Connecter matériel** :

   ```
   ESP32-CAM → FTDI USB-TTL
   GND     → GND
   5V      → VCC
   U0R     → TX
   U0T     → RX
   IO0     → GND (pendant upload seulement)
   ```

6. **Téléverser** :
   - Cliquer bouton Upload (→)
   - Attendre compilation
   - Déconnecter IO0 après upload
   - Appuyer RESET

7. **Obtenir IP** :
   - Outils → Moniteur série (115200 baud)
   - Noter l'IP : `http://192.168.1.XXX:81/stream`

---

## 📱 Partie 2 : Android (APK depuis Python/Kivy)

### Fichier : `main.py` (Python/Kivy)

**Ce fichier doit être compilé en APK avec Buildozer.**

### ⚠️ Limitation Windows

**Buildozer ne fonctionne PAS nativement sur Windows !**

### Solutions

#### A. Google Colab (RECOMMANDÉ - Gratuit, Simple, Cloud)

Voir fichier : `compile_apk_colab.md`

**Résumé rapide :**

1. Zipper : `main.py`, `buildozer.spec`, `*.p`, `*.json`, `*.task`
2. Ouvrir Google Colab
3. Installer buildozer
4. Upload ZIP
5. Compiler avec `buildozer android debug`
6. Télécharger APK (~20-40 min)

#### B. WSL2 (Local Windows)

```powershell
# PowerShell Admin
wsl --install

# Redémarrer PC

# Dans WSL Ubuntu
sudo apt update
pip3 install buildozer cython==0.29.33

# Compiler
cd /mnt/c/Users/dawse/Desktop/pfa
buildozer android debug
```

#### C. Machine Linux

```bash
pip install buildozer cython==0.29.33
cd ~/pfa
buildozer android debug
```

---

## 🔗 Partie 3 : Connexion ESP32 ↔ Android

### Configuration réseau

```
WiFi Router
    ├── ESP32-CAM (IP: 192.168.1.100)
    └── Android Phone (IP: 192.168.1.XXX)
```

**Impératif : Même réseau WiFi !**

### Dans l'application Android

1. Lancer l'APK
2. Champ IP : Entrer `192.168.1.100` (IP de votre ESP32)
3. Bouton : "Connect ESP32"
4. ✅ Flux vidéo s'affiche

---

## 🎯 Résumé des Fichiers

| Fichier               | Plateforme    | Langage | Déploiement                  |
|-----------------------|---------------|---------|------------------------------|
| `esp32_cam_full.ino`  | ESP32-CAM     | C++     | Arduino IDE → Upload         |
| `main.py`             | Android       | Python  | Buildozer → APK              |
| `buildozer.spec`      | Android       | Config  | Configuration Buildozer      |
| `model.p`             | Android       | Data    | Inclus dans APK              |
| `translations.json`   | Android       | Data    | Inclus dans APK              |

---

## ✅ Checklist de Déploiement

### ESP32-CAM

- [ ] Arduino IDE installé
- [ ] Support ESP32 ajouté
- [ ] WiFi configuré dans code
- [ ] Code téléversé
- [ ] IP récupérée du moniteur série
- [ ] Test : Ouvrir `http://IP:81/stream` dans navigateur

### Android

- [ ] Fichiers préparés (main.py, buildozer.spec, modèles)
- [ ] Buildozer installé (Colab/WSL/Linux)
- [ ] `buildozer android debug` exécuté
- [ ] APK généré
- [ ] APK transféré sur téléphone
- [ ] APK installé
- [ ] Permissions accordées (Caméra, Micro)

### Test Final

- [ ] ESP32 et Android sur même WiFi
- [ ] IP ESP32 entrée dans app
- [ ] Connexion établie
- [ ] Flux vidéo visible
- [ ] Reconnaissance de signes fonctionne
- [ ] Audio TTS fonctionne

---

## 🆘 Dépannage

### ESP32 ne se connecte pas au WiFi

- Vérifier SSID et mot de passe
- Vérifier portée WiFi
- Essayer redémarrer ESP32 (bouton RESET)

### Pas d'IP dans moniteur série

- Vérifier vitesse : 115200 baud
- Vérifier connexion USB-TTL

### APK ne compile pas

- Utiliser Google Colab (plus fiable)
- Vérifier versions : `cython==0.29.33`

### Android ne peut pas se connecter à ESP32

- Vérifier même réseau WiFi
- Ping l'IP depuis téléphone
- Firewall du routeur ?

### Flux vidéo ne s'affiche pas

- Tester URL dans navigateur : `http://IP:81/stream`
- Vérifier ESP32 fonctionne (LED)
- Redémarrer ESP32
