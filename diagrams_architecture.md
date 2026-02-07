# Diagrammes d'Architecture - SignLanguage App

## Diagramme de Cas d'Utilisation Amélioré

```mermaid
graph TB
    subgraph "Acteurs Externes"
        PS[👤 Personne Sourde]
        PE[👤 Personne Entendante]
        ESP32[📷 ESP32-CAM]
    end
    
    subgraph "Application SignLanguage"
        subgraph "Mode Reconnaissance"
            RG[Reconnaître un geste]
            TG[Traduire geste en texte]
            SY[Synthétiser en parole TTS]
            CM[Choisir mode lettre/mot]
            
            subgraph "Système IA - Reconnaissance"
                HL[Hand Landmarker<br/>MediaPipe]
                TFL1[Modèle TFLite<br/>Lettres]
                TFL2[Modèle TFLite<br/>Mots]
                SEQ[Modèle Séquence<br/>LSTM]
            end
        end
        
        subgraph "Mode Inverse"
            MI[Mode Inverse<br/>Voix → Gestes]
            RV[Reconnaître voix STT]
            AG[Afficher gestes<br/>correspondants]
            
            subgraph "Système IA - Inverse"
                STT[Speech-to-Text<br/>Google]
                GT[Google Translate<br/>API]
            end
        end
        
        SL[Sélectionner langue<br/>FR/EN/Darja]
        CE[Configurer ESP32-CAM]
    end
    
    PS -->|Fait geste| RG
    RG -->|Utilise| HL
    HL -->|Landmarks| TFL1
    HL -->|Landmarks| TFL2
    TFL1 -->|Lettres| SEQ
    TFL2 -->|Mots| SEQ
    SEQ -->|Prédiction| TG
    TG -->|Utilise| GT
    TG --> SY
    SY -->|Parole| PE
    
    PE -->|Parle| RV
    RV -->|Utilise| STT
    STT --> AG
    AG -->|Utilise| GT
    AG -->|Affiche| PS
    
    PS --> SL
    PE --> SL
    SL --> RG
    SL --> MI
    
    PS --> CE
    ESP32 -->|Stream vidéo| RG
```

## Architecture Système avec Composants IA

```mermaid
graph TB
    subgraph "Couche Présentation"
        UI[Interface Flutter]
        RS[Recognition Screen]
        IMS[Inverse Mode Screen]
    end
    
    subgraph "Couche Services"
        CS[Camera Service]
        MS[Model Service]
        TS[Translation Service]
        TTS[Text-to-Speech]
        STT[Speech-to-Text]
    end
    
    subgraph "Couche IA / ML"
        subgraph "Détection Gestes"
            HL[Hand Landmarker<br/>MediaPipe]
            NM[Normalisation<br/>Aspect Ratio]
        end
        
        subgraph "Modèles TensorFlow Lite"
            LM[sign_language_model.tflite<br/>26 lettres A-Z]
            WM[sign_language_words_model.tflite<br/>10 mots]
            SM[gesture_sequence_model.tflite<br/>LSTM pour séquences]
        end
        
        subgraph "Services Cloud IA"
            GTA[Google Translate API<br/>Traduction multilingue]
            GSTT[Google Speech-to-Text<br/>Reconnaissance vocale]
        end
    end
    
    subgraph "Couche Données"
        CACHE[Cache Traductions<br/>Map<String, String>]
        PREF[SharedPreferences<br/>Configuration]
        MAPS[Mappings Statiques<br/>Lettres/Mots/Gestes]
    end
    
    subgraph "Matériel"
        CAM[Caméra Téléphone<br/>Android/iOS]
        ESP[ESP32-CAM<br/>Stream WiFi]
        MIC[Microphone]
        SPK[Haut-parleur]
    end
    
    UI --> RS
    UI --> IMS
    RS --> CS
    RS --> MS
    RS --> TS
    RS --> TTS
    IMS --> STT
    IMS --> TS
    
    CS --> CAM
    CS --> ESP
    
    MS --> HL
    HL --> NM
    NM --> LM
    NM --> WM
    NM --> SM
    
    TS --> GTA
    TS --> CACHE
    TS --> MAPS
    
    STT --> GSTT
    GSTT --> MIC
    TTS --> SPK
    
    MS --> PREF
    TS --> PREF
```

## Flux de Données - Reconnaissance de Geste

```mermaid
sequenceDiagram
    participant U as Utilisateur
    participant UI as Interface
    participant CS as Camera Service
    participant HL as Hand Landmarker
    participant MS as Model Service
    participant TFL as TFLite Model
    participant TS as Translation Service
    participant GT as Google Translate
    participant TTS as Text-to-Speech
    
    U->>UI: Fait un geste
    UI->>CS: Capture frame caméra
    CS->>HL: Envoie image
    HL->>HL: Détecte 21 landmarks
    HL->>MS: Retourne landmarks normalisés
    MS->>MS: Normalise aspect ratio
    MS->>TFL: Envoie landmarks [63 features]
    TFL->>TFL: Inférence modèle
    TFL->>MS: Probabilités [26 classes]
    MS->>MS: Seuil confiance > 0.7
    MS->>UI: Lettre détectée (ex: "A")
    UI->>TS: Traduire "A"
    TS->>TS: Cherche dans cache
    alt Cache hit
        TS->>UI: Traduction en cache
    else Cache miss
        TS->>GT: Appel API Translate
        GT->>TS: Traduction (ex: "أ")
        TS->>TS: Met en cache
        TS->>UI: Retourne traduction
    end
    UI->>TTS: Synthétiser texte
    TTS->>U: Lecture audio
```

## Flux de Données - Mode Inverse (Voix → Gestes)

```mermaid
sequenceDiagram
    participant U as Utilisateur
    participant UI as Inverse Mode UI
    participant STT as Speech-to-Text
    participant TS as Translation Service
    participant GT as Google Translate
    participant UI2 as Gesture Display
    
    U->>UI: Appuie sur micro
    UI->>STT: Démarre écoute
    U->>STT: Parle (ex: "Bonjour")
    STT->>STT: Reconnaissance vocale
    STT->>UI: Texte reconnu "Bonjour"
    UI->>UI: Sépare en lettres [B,O,N,J,O,U,R]
    
    loop Pour chaque lettre
        UI->>TS: Traduire lettre
        TS->>TS: Vérifie mapping statique
        alt Mapping existe
            TS->>UI2: Lettre mappée
        else Pas de mapping
            TS->>GT: API Translate
            GT->>TS: Lettre traduite
            TS->>UI2: Lettre traduite
        end
        UI2->>UI2: Affiche image geste
    end
    
    UI2->>U: Affiche séquence complète
```

## Architecture en Couches

```mermaid
graph TB
    subgraph "Couche 1: Interface Utilisateur"
        A1[Écrans Flutter<br/>Material Design]
        A2[Widgets Personnalisés<br/>Camera Preview, Gesture List]
    end
    
    subgraph "Couche 2: Logique Métier"
        B1[Gestion d'État<br/>StatefulWidgets]
        B2[Controllers<br/>Camera, Model, Translation]
    end
    
    subgraph "Couche 3: Services ML/IA"
        C1[Hand Landmarker<br/>hand_landmarker v0.0.6]
        C2[TFLite Interpreter<br/>tflite_flutter v0.11.0]
        C3[Google APIs<br/>Translate + STT]
    end
    
    subgraph "Couche 4: Modèles IA"
        D1[sign_language_model.tflite<br/>Input: 63 features<br/>Output: 26 classes]
        D2[sign_language_words_model.tflite<br/>Input: 63 features<br/>Output: 10 classes]
        D3[gesture_sequence_model.tflite<br/>LSTM pour séquences]
    end
    
    subgraph "Couche 5: Données & Configuration"
        E1[Assets<br/>Images gestes 26×6 = 156]
        E2[Mappings JSON<br/>Lettres/Mots multilingues]
        E3[Cache Runtime<br/>Traductions]
    end
    
    subgraph "Couche 6: Matériel"
        F1[Caméra Native<br/>Android/iOS]
        F2[ESP32-CAM<br/>WiFi Stream MJPEG]
        F3[Audio<br/>Microphone + Speaker]
    end
    
    A1 --> B1
    A2 --> B1
    B1 --> B2
    B2 --> C1
    B2 --> C2
    B2 --> C3
    C1 --> D1
    C2 --> D1
    C2 --> D2
    C2 --> D3
    B2 --> E1
    B2 --> E2
    B2 --> E3
    C1 --> F1
    C1 --> F2
    C3 --> F3
```

## Composants IA - Détails Techniques

### 1. Hand Landmarker (MediaPipe)

- **Version**: hand_landmarker v0.0.6
- **Fonction**: Détecte 21 points caractéristiques de la main
- **Input**: Image RGB (variable)
- **Output**: 21 landmarks (x, y, z) + score confiance
- **Normalisation**: Coordonnées [0-1] relatives à la frame

### 2. Modèles TensorFlow Lite

#### sign_language_model.tflite

- **Type**: Dense Neural Network
- **Input Shape**: [1, 63] (21 landmarks × 3 coordonnées)
- **Output Shape**: [1, 26] (A-Z)
- **Activation**: Softmax
- **Taille**: ~50 KB
- **Entraîné sur**: Dataset custom avec variabilité

#### sign_language_words_model.tflite

- **Type**: Dense Neural Network
- **Input Shape**: [1, 63]
- **Output Shape**: [1, 10] (10 mots courants)
- **Mots**: HELLO, THANK YOU, PLEASE, etc.
- **Taille**: ~45 KB

#### gesture_sequence_model.tflite

- **Type**: LSTM (Long Short-Term Memory)
- **Input Shape**: [1, sequence_length, 63]
- **Output**: Séquence de lettres/mots
- **Usage**: Reconnaissance de phrases complètes
- **Taille**: ~120 KB

### 3. Services Cloud IA

#### Google Translate API

- **Usage**: Traduction multilingue (FR ↔ EN ↔ AR-TN)
- **Fallback**: Mappings statiques
- **Cache**: Map en mémoire pour éviter appels répétés
- **Latence**: ~200-500ms par requête

#### Google Speech-to-Text

- **Langues**: Français, Anglais, Arabe Tunisien
- **Mode**: Streaming ou one-shot
- **Précision**: ~95% en conditions normales
- **Usage**: Mode Inverse uniquement

## Optimisations IA Implémentées

### Normalisation Aspect Ratio

```dart
// Compensation aspect ratio pour mobile
double aspectRatio = frameWidth / frameHeight;
for (var landmark in landmarks) {
  landmark.x *= aspectRatio;
  // Normalisation pour TFLite
}
```

### Seuil de Confiance Adaptatif

```dart
double confidenceThreshold = mode == 'letters' ? 0.7 : 0.75;
if (prediction.confidence > confidenceThreshold) {
  // Accepter la prédiction
}
```

### Cache de Traductions

```dart
Map<String, String> _translationCache = {};
String cacheKey = '${letter}_${targetLang}';
if (_translationCache.containsKey(cacheKey)) {
  return _translationCache[cacheKey]!; // Hit
}
```

---

**Diagrammes créés avec Mermaid.js** - Compatible GitHub, Markdown, et outils de documentation
