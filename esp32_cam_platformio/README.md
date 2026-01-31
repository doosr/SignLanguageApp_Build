# ESP32-CAM PlatformIO - Sign Language Recognition

Ce projet contient le code ESP32-CAM pour le streaming vidéo utilisé par l'application Flutter de reconnaissance de langage des signes.

## 📋 Prérequis

- **PlatformIO** installé (extension VS Code ou CLI)
- **ESP32-CAM** (modèle AI Thinker recommandé)
- **Programmateur FTDI** (USB to TTL) ou carte ESP32 pour programmer l'ESP32-CAM
- **Réseau WiFi** 2.4GHz

## 🔧 Configuration

### 1. Modifier les paramètres WiFi

Éditez le fichier `include/config.h` et remplacez:

```cpp
#define WIFI_SSID "VotreSSID"
#define WIFI_PASSWORD "VotreMotDePasse"
```

### 2. Configuration de la caméra (optionnel)

Dans `include/config.h`, vous pouvez ajuster:

- **Résolution**: `CAMERA_FRAME_SIZE` (QVGA, VGA, SVGA, XGA, SXGA)
- **Qualité JPEG**: `JPEG_QUALITY` (0-63, plus bas = meilleure qualité)
- **Buffers**: `FRAME_BUFFERS` (1-2)

## 📦 Compilation et Upload

### Avec PlatformIO CLI

```bash
# Compiler le projet
pio run

# Uploader vers l'ESP32-CAM
pio run --target upload

# Moniteur série
pio device monitor
```

### Avec VS Code

1. Ouvrir le dossier `esp32_cam_platformio` dans VS Code
2. Cliquer sur l'icône PlatformIO dans la barre latérale
3. Cliquer sur "Build" pour compiler
4. Cliquer sur "Upload" pour téléverser

## 🔌 Connexion FTDI pour programmation

| FTDI | ESP32-CAM |
|------|-----------|
| GND  | GND       |
| 5V   | 5V        |
| TX   | U0R (RX)  |
| RX   | U0T (TX)  |

**Important**:

- Connecter **GPIO 0** à **GND** pour entrer en mode programmation
- Déconnecter GPIO 0 de GND après l'upload pour exécution normale
- Appuyer sur le bouton RESET après l'upload

## 🌐 Endpoints disponibles

Une fois l'ESP32-CAM connecté au WiFi, vous pouvez accéder à:

| Endpoint | Description |
|----------|-------------|
| `http://<IP>/` | Page d'accueil avec informations système |
| `http://<IP>/stream` | Stream vidéo MJPEG en temps réel |
| `http://<IP>/capture` | Capture une image JPEG |

## 📱 Intégration avec l'application Flutter

1. Notez l'adresse IP affichée dans le moniteur série
2. Dans l'application Flutter, allez dans **Configuration ESP32-CAM**
3. Entrez l'adresse IP de l'ESP32-CAM
4. Testez la connexion
5. Activez la caméra distante

## 🐛 Dépannage

### L'ESP32-CAM ne se connecte pas au WiFi

- Vérifiez le SSID et le mot de passe dans `config.h`
- Assurez-vous d'utiliser un réseau 2.4GHz (pas 5GHz)
- Vérifiez la portée du signal WiFi

### Erreur d'initialisation de la caméra

- Vérifiez que vous utilisez le bon modèle (AI Thinker)
- Assurez-vous que la caméra est correctement connectée
- Essayez de redémarrer l'ESP32-CAM

### Pas d'image dans le stream

- Vérifiez que la LED s'allume pendant le streaming
- Testez l'endpoint `/capture` pour une image unique
- Réduisez la résolution dans `config.h`

### Upload échoue

- Vérifiez les connexions FTDI
- Assurez-vous que GPIO 0 est connecté à GND
- Appuyez sur RESET avant l'upload
- Essayez une vitesse d'upload plus basse (115200)

## 📊 Moniteur série

Pour voir les logs de débogage:

```bash
pio device monitor -b 115200
```

Vous verrez:

- État de connexion WiFi
- Adresse IP assignée
- État d'initialisation de la caméra
- Connexions clients au stream

## ⚙️ Paramètres avancés

### Optimisation de la qualité vidéo

Pour une meilleure reconnaissance des gestes, le code configure automatiquement:

- Balance des blancs automatique
- Exposition automatique
- Correction gamma
- Correction de lentille

### Performance

- **Avec PSRAM**: Résolution VGA (640x480), qualité 10, 2 buffers
- **Sans PSRAM**: Résolution QVGA (320x240), qualité 12, 1 buffer

## 📄 Structure du projet

```
esp32_cam_platformio/
├── include/
│   ├── config.h          # Configuration WiFi et caméra
│   └── camera_pins.h     # Pins de la caméra
├── src/
│   └── main.cpp          # Code principal
├── platformio.ini        # Configuration PlatformIO
└── README.md            # Ce fichier
```

## 🔐 Sécurité

⚠️ **Important**: Ce code est destiné à un usage local/développement. Pour une utilisation en production:

- Ajoutez une authentification
- Utilisez HTTPS
- Ne pas exposer directement sur Internet
- Changez les identifiants par défaut

## 📝 Licence

Ce projet fait partie de l'application Sign Language Recognition.

## 🤝 Support

Pour toute question ou problème:

1. Vérifiez la section Dépannage ci-dessus
2. Consultez les logs du moniteur série
3. Vérifiez que tous les paramètres sont corrects dans `config.h`
