# Classes Principales - SignLanguage App

## Description des Classes

Le diagramme de classes ci-dessous offre une vue d'ensemble de l'architecture statique de l'application. Il illustre les classes principales et leurs relations.

### Classes Principales

#### Interface Utilisateur

- **RecognitionScreen** : Écran principal de reconnaissance de gestes, gère la caméra, les prédictions des modèles, la traduction et la synthèse vocale
- **InverseModeScreen** : Écran du mode inverse (voix → gestes), gère la reconnaissance vocale et l'affichage de la séquence de gestes

#### Services de Traitement

- **ModelService** : Gestion des modèles TensorFlow Lite (lettres, mots, séquences), normalisation des landmarks et inférence
- **CameraService** : Gestion de la caméra (native téléphone ou ESP32-CAM via WiFi)
- **TranslationService** : Service de traduction multilingue (FR/EN/Darja) avec cache et mappings statiques

#### Intelligence Artificielle

- **HandLandmarker** : Détection des 21 landmarks de la main via MediaPipe
- **TFLiteModel** : Modèle TensorFlow Lite générique pour l'inférence (lettres/mots/séquences)
- **Landmark** : Représentation d'un point caractéristique de la main (x, y, z, visibilité)

#### Services Audio

- **TextToSpeechService** : Service de synthèse vocale (TTS) pour lire les traductions
- **SpeechToTextService** : Service de reconnaissance vocale (STT) pour le mode inverse

#### APIs Externes

- **GoogleTranslateAPI** : Interface avec l'API Google Translate pour les traductions

#### Données et Configuration

- **GestureData** : Données associées à un geste (lettre, chemin image, traductions)
- **ConfigurationManager** : Gestion de la configuration de l'application (langue, mode, ESP32)

## Relations Entre Classes

### Associations Principales

- **RecognitionScreen** utilise : ModelService, CameraService, TranslationService, TextToSpeechService, ConfigurationManager
- **InverseModeScreen** utilise : SpeechToTextService, TranslationService, GestureData, ConfigurationManager
- **ModelService** utilise : HandLandmarker, TFLiteModel (×3), Landmark
- **TranslationService** utilise : GoogleTranslateAPI

### Multiplicités

- RecognitionScreen → ModelService : 1:1
- RecognitionScreen → CameraService : 1:1
- ModelService → TFLiteModel : 1:3 (lettres, mots, séquences)
- HandLandmarker → Landmark : 1:0..21 (jusqu'à 21 points détectés)
- InverseModeScreen → GestureData : 1:* (séquence de gestes)

## Architecture Logicielle

L'application suit une architecture en couches :

1. **Couche Présentation** : RecognitionScreen, InverseModeScreen
2. **Couche Services** : ModelService, CameraService, TranslationService, STT, TTS
3. **Couche IA/ML** : HandLandmarker, TFLiteModel, GoogleTranslateAPI
4. **Couche Données** : GestureData, ConfigurationManager, Cache, SharedPreferences

Cette organisation assure une séparation claire des responsabilités et facilite la maintenance et l'évolution de l'application.
