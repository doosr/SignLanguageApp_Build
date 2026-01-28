# ESP32-CAM Gesture Detection Stream

## 📦 Matériel Requis

- ESP32-CAM (modèle AI-Thinker recommandé)
- Programmer FTDI/USB-to-Serial
- Câble micro-USB
- Réseau WiFi 2.4GHz

## 🔧 Installation Arduino IDE

### 1. Installer ESP32 Board Manager

1. Ouvrir Arduino IDE
2. Aller dans **Fichier → Préférences**
3. Ajouter cette URL dans "URLs de gestionnaire de cartes supplémentaires":

   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```

4. Aller dans **Outils → Type de carte → Gestionnaire de cartes**
5. Rechercher "esp32" et installer "esp32 by Espressif Systems"

### 2. Configuration de la carte

- **Carte**: AI Thinker ESP32-CAM
- **Port**: Sélectionner le port COM approprié
- **Upload Speed**: 115200
- **Flash Frequency**: 80MHz
- **Partition Scheme**: Huge APP (3MB No OTA)

## ⚙️ Configuration du Code

### Modifier les credentials WiFi

Dans `esp32_cam_stream.ino`, lignes 7-8:

```cpp
const char* ssid = "NOM_DE_VOTRE_WIFI";
const char* password = "VOTRE_MOT_DE_PASSE";
```

## 📤 Téléversement du Code

### Branchement ESP32-CAM avec FTDI

```
ESP32-CAM  ->  FTDI
GND        ->  GND
5V         ->  VCC (5V)
U0R (RX)   ->  TX
U0T (TX)   ->  RX
IO0        ->  GND (pour mode flash)
```

### Étapes

1. Connecter IO0 à GND (mode programmation)
2. Brancher l'USB
3. Cliquer sur "Téléverser" dans Arduino IDE
4. Attendre la fin du téléversement
5. **Débrancher IO0 de GND**
6. Appuyer sur le bouton RESET de l'ESP32-CAM

## 🚀 Utilisation

### 1. Démarrage de l'ESP32-CAM

1. Ouvrir le **Moniteur Série** (115200 bauds)
2. Vous verrez:

   ```
   ESP32-CAM Starting...
   Camera initialized successfully!
   Connecting to WiFi....
   WiFi connected!
   Camera Stream Ready at: http://192.168.1.XXX
   Stream URL: http://192.168.1.XXX/stream
   ```

3. **Noter l'adresse IP affichée**

### 2. Configuration de l'App Flutter

1. Modifier `currentEspIp` dans `main.dart` (ligne 69):

   ```dart
   String currentEspIp = "192.168.1.XXX";  // Remplacer par l'IP de votre ESP32
   ```

2. Ou cliquer sur le bouton ESP32 dans l'app et entrer l'IP

### 3. Accès au Stream

**Option A: Depuis l'App Flutter**

- Cliquer sur le bouton bleu "ESP32: 192.168.1.XXX"
- Cliquer sur "Navigateur"
- Le stream s'ouvre dans le navigateur

**Option B: Test Direct**

- Ouvrir un navigateur (Chrome recommandé)
- Aller à: `http://IP_DE_VOTRE_ESP32/stream`
- Vous devriez voir le flux vidéo en direct

## 🔍 Dépannage

### Problème: "Camera init failed"

- Vérifier les connexions de la caméra
- Essayer de réduire la résolution (FRAMESIZE_QVGA au lieu de FRAMESIZE_VGA)

### Problème: "WiFi connection failed"

- Vérifier le nom et mot de passe WiFi
- S'assurer d'utiliser un réseau 2.4GHz (pas 5GHz)
- Rapprocher l'ESP32 du routeur

### Problème: "Cannot access stream"

- Vérifier que le téléphone et l'ESP32 sont sur le même réseau WiFi
- Tester l'IP directement dans un navigateur
- Vérifier le pare-feu

### Problème: Images gelées/lentes

- Réduire la qualité JPEG (augmenter `jpeg_quality` de 10 à 15)
- Réduire la résolution (FRAMESIZE_SVGA)
- Rapprocher l'ESP32 du routeur WiFi

## 📊 Résolutions Disponibles

```cpp
FRAMESIZE_QVGA   // 320x240
FRAMESIZE_VGA    // 640x480  (recommandé)
FRAMESIZE_SVGA   // 800x600
FRAMESIZE_XGA    // 1024x768
FRAMESIZE_SXGA   // 1280x1024
```

## 🌐 URLs Disponibles

- Page d'accueil: `http://IP_ESP32/`
- Stream direct: `http://IP_ESP32/stream`

## 💡 Conseils

- Pour une meilleure performance, utiliser un réseau WiFi stable
- Éviter les environnements avec beaucoup d'interférences WiFi
- Ajouter un dissipateur thermique si l'ESP32 chauffe
- Utiliser une alimentation 5V stable (min 500mA)

## 🔐 Sécurité

⚠️ **IMPORTANT**: Ce code n'implémente aucune authentification. N'utilisez pas sur un réseau public!

Pour ajouter une sécurité basique, vous pouvez:

- Utiliser un réseau WiFi privé
- Implémenter une authentification HTTP basique
- Utiliser un VPN

## 📝 Prochaines Étapes

Pour implémenter la détection de gestes sur ESP32 (avancé):

1. Réduire la taille des modèles TFLite (quantization int8)
2. Utiliser TensorFlow Lite Micro pour ESP32
3. Implémenter l'inférence directement sur l'ESP32

Documentation TFLite Micro: <https://www.tensorflow.org/lite/microcontrollers>
