# Besoins Fonctionnels

Les besoins fonctionnels définissent les attentes des utilisateurs en termes de fonctionnalités. L'application doit répondre aux exigences suivantes :

## Tableau : Les fonctionnalités principales offertes à l'utilisateur

| Acteur | Fonctionnalité | Description |
|--------|----------------|-------------|
| **Personne sourde** | Reconnaître geste → texte | L'utilisateur effectue un geste devant la caméra. **HandLandmarker** détecte les 21 landmarks de la main, **ModelService** effectue l'inférence via **TFLiteModel**, et traduit le geste en texte. |
| | Reconnaître geste → parole | Après traduction en texte via **TranslationService**, l'application synthétise la parole via **TextToSpeechService** dans la langue choisie (FR/EN/AR). |
| | Choisir mode reconnaissance | L'utilisateur sélectionne le mode via **RecognitionScreen** : 🔤 **Lettres** (alphabet A-Z, 26 classes) ou 💬 **Mots** (vocabulaire 10 mots courants). |
| | Choisir langue | L'utilisateur sélectionne la langue de sortie via **ConfigurationManager** : 🇫🇷 Français, 🇬🇧 English, 🇹🇳 Darja (ar-TN). |
| | Changer source caméra | L'utilisateur bascule entre la caméra native du téléphone et l'**ESP32-CAM** via **CameraService**. |
| **Personne entendante** | Parler → gestes | L'utilisateur parle dans le microphone. **SpeechToTextService** convertit la voix en texte, puis **InverseModeScreen** affiche la séquence de gestes correspondants via **GestureData**. |
| | Traduire en plusieurs langues | **TranslationService** traduit chaque lettre dans la langue cible (FR/EN/Darja) avec cache pour optimisation. |
| | Visualiser séquence de gestes | Affichage séquentiel des images de gestes (156 images : 26 lettres × 6 variantes) avec contrôle de séquence. |
| **ESP32-CAM** | Capturer vidéo à distance | Le module **ESP32-CAM** capture les gestes à distance et transmet le flux MJPEG via WiFi sur `http://<IP>:81/stream`. **CameraService** récupère et traite les frames. |
| | Stream temps réel | Transmission en temps réel (30 FPS) avec optimisations : double buffering, qualité JPEG 12, WiFi optimisé. |
| **Système (IA)** | Détecter landmarks | **HandLandmarker** (MediaPipe) détecte les 21 points caractéristiques de la main avec coordonnées (x, y, z) normalisées. |
| | Effectuer inférence | **ModelService** utilise 3 **TFLiteModel** (lettres 26 classes, mots 10 classes, séquences LSTM) pour la reconnaissance. |
| | Traduire automatiquement | **GoogleTranslateAPI** fournit les traductions via **TranslationService** avec mapping statique prioritaire et cache. |

## Détails Techniques

### Mode Reconnaissance

- **Input** : Frame caméra (native ou ESP32-CAM)
- **Traitement** : HandLandmarker → 21 landmarks → 63 features (21 × 3)
- **Inférence** : TFLiteModel (lettres/mots/séquences)
- **Seuil confiance** : 0.7 pour lettres, 0.75 pour mots
- **Output** : Texte + Audio (TTS)

### Mode Inverse

- **Input** : Voix utilisateur
- **Traitement** : SpeechToTextService → Texte → Séparation lettres → Traduction
- **Output** : Séquence d'images de gestes

### Configuration

- **Langues** : Français, English, Darja Tunisienne (ar-TN)
- **Modes** : Lettres (26 classes) ou Mots (10 classes)
- **Caméras** : Native téléphone ou ESP32-CAM WiFi
- **Stockage** : SharedPreferences via ConfigurationManager
