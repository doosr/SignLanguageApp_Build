# 🏗️ Architecture

## Vue d'ensemble

SignLanguage utilise une architecture **on-device** en 4 couches pour garantir la vie privée et des performances optimales.

```
┌─────────────────────────────────────┐
│     Couche Présentation (UI)        │
│         Flutter + Provider          │
├─────────────────────────────────────┤
│    Couche Logique Métier            │
│  Modes, Traduction, TTS/STT         │
├─────────────────────────────────────┤
│  Couche Intelligence Artificielle   │
│   MediaPipe + TensorFlow Lite       │
├─────────────────────────────────────┤
│     Couche Acquisition              │
│   Caméra native / ESP32-CAM         │
└─────────────────────────────────────┘
```

## Couches

### 1. Couche Acquisition

**Responsabilité** : Capture vidéo en temps réel

**Composants** :

- **Caméra native** : Plugin `camera` Flutter (640×480, 20-30 FPS)
- **ESP32-CAM** : Streaming MJPEG via WiFi (port 81)

**Technologies** :

- Flutter `camera` plugin
- ESP32 C/C++ (Arduino framework)
- HTTP streaming

### 2. Couche Intelligence Artificielle

**Responsabilité** : Détection et reconnaissance des gestes

**Pipeline** :

1. **Détection landmarks** : MediaPipe Hand Landmarker (21 points)
2. **Normalisation** : Coordonnées relatives au point minimum
3. **Inférence** : TensorFlow Lite (CNN pour lettres, LSTM pour mots)
4. **Stabilisation** : Rolling window + vote majoritaire

**Modèles** :

| Modèle | Architecture | Précision | Latence | Taille |
|--------|--------------|-----------|---------|--------|
| Lettres | CNN (2 Conv2D + Dense) | 90.3% | 40ms | 2.1 MB |
| Mots | LSTM (2 couches) | 78.5% | 85ms | 3.8 MB |

**Technologies** :

- MediaPipe (Google)
- TensorFlow Lite
- Python (entraînement)
- Dart (inférence)

### 3. Couche Logique Métier

**Responsabilité** : Gestion des modes et traduction

**Services** :

- **ModeManager** : Gestion reconnaissance/inverse
- **TranslationService** : Traduction FR/EN/AR
- **TTSService** : Synthèse vocale (flutter_tts)
- **STTService** : Reconnaissance vocale (speech_to_text)
- **HistoryManager** : Historique des traductions

**State Management** : Provider pattern

### 4. Couche Présentation

**Responsabilité** : Interface utilisateur accessible

**Écrans** :

- `HomeScreen` : Sélection du mode
- `RecognitionScreen` : Mode reconnaissance
- `InverseModeScreen` : Mode inverse
- `LanguageSelectionScreen` : Choix de langue
- `ESP32ConfigScreen` : Configuration ESP32-CAM

**Design** : Material Design + emojis pour accessibilité

## Flux de données

### Mode Reconnaissance

```
Caméra → Frame (30 FPS)
  ↓
MediaPipe → 21 Landmarks
  ↓
Normalisation → 84 features
  ↓
TFLite → Prédiction (lettre/mot)
  ↓
Buffer → Vote majoritaire
  ↓
Traduction → Texte (FR/EN/AR)
  ↓
TTS → Parole
  ↓
UI → Affichage
```

### Mode Inverse

```
Micro → Audio
  ↓
STT → Texte
  ↓
Découpage → Lettres
  ↓
Mapping → Images gestes LSF
  ↓
UI → Affichage séquentiel
```

## Architecture IoT (ESP32-CAM)

```
ESP32-CAM (192.168.1.X)
  ↓
WiFi → HTTP Server (port 81)
  ↓
MJPEG Stream → /stream
  ↓
Flutter App → HTTP GET
  ↓
Frame extraction → MediaPipe
```

**Latence totale** : ~195ms (120ms réseau + 75ms traitement)

## Optimisations

### Performances

- **Frame skipping** : 1 frame sur 8 (12.5% traité)
- **Résolution basse** : 640×480 (optimal pour reconnaissance)
- **GPU delegate** : Accélération matérielle MediaPipe
- **Lazy loading** : Chargement modèles en arrière-plan

### Mémoire

- **Modèles quantifiés** : TFLite INT8 (réduction 75%)
- **Image streaming** : Pas de stockage frames
- **Buffer limité** : Max 8 frames en mémoire

### Batterie

- **FPS adaptatif** : Réduit si batterie faible
- **Arrêt automatique** : Stop stream si app en arrière-plan

## Sécurité

### Vie privée

- ✅ **On-device** : Aucune donnée envoyée au cloud
- ✅ **Pas de stockage** : Frames non sauvegardées
- ✅ **Permissions minimales** : Caméra + micro uniquement

### Données

- **Chiffrement** : `flutter_secure_storage` pour préférences sensibles
- **Validation** : Entrées utilisateur validées (IP ESP32)

## Technologies

| Couche | Technologies |
|--------|--------------|
| Frontend | Flutter 3.16, Dart 3.3 |
| IA | TensorFlow Lite, MediaPipe |
| Backend | On-device (aucun serveur) |
| IoT | ESP32-CAM, C/C++, Arduino |
| State | Provider pattern |
| Plugins | camera, tflite_flutter, flutter_tts, speech_to_text |

## Diagrammes

### Diagramme de classes (simplifié)

```
RecognitionScreen
  ├── CameraService
  ├── MediaPipeProcessor
  ├── TFLiteClassifier
  ├── TranslationService
  └── TTSService

InverseModeScreen
  ├── STTService
  └── GestureImageProvider
```

### Diagramme de séquence (reconnaissance)

```
User → Camera : Fait un geste
Camera → MediaPipe : Frame
MediaPipe → TFLite : 21 landmarks
TFLite → Buffer : Prédiction
Buffer → UI : Vote majoritaire
UI → TTS : Texte
TTS → User : Parole
```

## Évolutions futures

- [ ] Support phrases complètes (NLP)
- [ ] Reconnaissance faciale (expressions)
- [ ] Mode hors ligne complet
- [ ] Synchronisation multi-devices
- [ ] API REST (optionnelle)
