# Diagramme de Classes - SignLanguage App

```mermaid
classDiagram
    %% Classes principales
    class RecognitionScreen {
        -CameraController _cameraController
        -ModelService _modelService
        -TranslationService _translationService
        -FlutterTts _flutterTts
        -String phrase
        -String detectedText
        -String selectedLanguage
        -String selectedMode
        +initState()
        +dispose()
        +_initializeCamera()
        +_processFrame()
        +_translatePhrase(String)
        +_speak()
        +_switchLanguage(String)
    }
    
    class InverseModeScreen {
        -SpeechToText _speechToText
        -GoogleTranslator _translator
        -List~String~ gestureSequence
        -String selectedLanguage
        -bool isListening
        -Map~String,String~ translationCache
        +initState()
        +dispose()
        +_startListening()
        +_stopListening()
        +_translateLetter(String, String)
        +_displayGestureSequence()
    }
    
    class ModelService {
        -Interpreter interpreterLetters
        -Interpreter interpreterWords
        -Interpreter interpreterSequence
        -HandLandmarker handLandmarker
        -double confidenceThreshold
        +initialize()
        +dispose()
        +predictLetter(List~Landmark~)
        +predictWord(List~Landmark~)
        +predictSequence(List~List~Landmark~~)
        +normalizeAspectRatio(List~Landmark~)
    }
    
    class TranslationService {
        -GoogleTranslator translator
        -Map~String,String~ cache
        -Map~String,Map~ lettersMapping
        -Map~String,Map~ wordsMapping
        +translateText(String, String)
        +getLetterMapping(String, String)
        +getWordMapping(String, String)
        -_checkCache(String)
        -_saveToCache(String, String)
    }
    
    class CameraService {
        -CameraController controller
        -String esp32Ip
        -bool isUsingESP32
        -StreamSubscription esp32Stream
        +initializePhoneCamera()
        +connectToESP32(String)
        +switchCamera()
        +captureFrame()
        +dispose()
    }
    
    class HandLandmarker {
        -String modelPath
        -List~Landmark~ landmarks
        +initialize()
        +detectHand(Image)
        +getLandmarks()
        +getNormalizedLandmarks()
    }
    
    class Landmark {
        +double x
        +double y
        +double z
        +double visibility
        +normalize()
        +toFeatureVector()
    }
    
    class TFLiteModel {
        -String modelPath
        -Interpreter interpreter
        -List~int~ inputShape
        -List~int~ outputShape
        +loadModel()
        +predict(List~double~)
        +dispose()
    }
    
    class GoogleTranslateAPI {
        -String apiKey
        -String baseUrl
        +translate(String, String, String)
        +detectLanguage(String)
    }
    
    class SpeechToTextService {
        -SpeechToText stt
        -String locale
        -bool isAvailable
        +initialize()
        +startListening(Function)
        +stopListening()
        +cancelListening()
    }
    
    class TextToSpeechService {
        -FlutterTts tts
        -String language
        -double pitch
        -double rate
        +initialize()
        +speak(String)
        +stop()
        +setLanguage(String)
    }
    
    class GestureData {
        -String letter
        -String imagePath
        -Map~String,String~ translations
        +getImagePath()
        +getTranslation(String)
    }
    
    class ConfigurationManager {
        -SharedPreferences prefs
        -String currentLanguage
        -String currentMode
        -String esp32Ip
        +loadConfig()
        +saveLanguage(String)
        +saveMode(String)
        +saveESP32Config(String)
    }
    
    %% Relations
    RecognitionScreen --> ModelService : uses
    RecognitionScreen --> CameraService : uses
    RecognitionScreen --> TranslationService : uses
    RecognitionScreen --> TextToSpeechService : uses
    RecognitionScreen --> ConfigurationManager : uses
    
    InverseModeScreen --> SpeechToTextService : uses
    InverseModeScreen --> TranslationService : uses
    InverseModeScreen --> GestureData : uses
    InverseModeScreen --> ConfigurationManager : uses
    
    ModelService --> HandLandmarker : uses
    ModelService --> TFLiteModel : contains
    ModelService --> Landmark : processes
    
    HandLandmarker --> Landmark : produces
    
    TranslationService --> GoogleTranslateAPI : uses
    
    CameraService --> RecognitionScreen : provides frames
    
    TFLiteModel ..|> ModelService : implements
    
    %% Multiplicités
    RecognitionScreen "1" --> "1" CameraService
    RecognitionScreen "1" --> "1" ModelService
    ModelService "1" --> "3" TFLiteModel
    ModelService "1" --> "1" HandLandmarker
    HandLandmarker "1" --> "0..21" Landmark
    InverseModeScreen "1" --> "*" GestureData
```

## Description des Classes

### Classes d'Interface (UI)

- **RecognitionScreen** : Écran principal pour la reconnaissance de gestes
- **InverseModeScreen** : Écran pour le mode inverse (voix → gestes)

### Classes de Services

- **ModelService** : Gestion des modèles TensorFlow Lite
- **TranslationService** : Gestion des traductions multilingues
- **CameraService** : Gestion de la caméra (téléphone et ESP32)
- **SpeechToTextService** : Service de reconnaissance vocale
- **TextToSpeechService** : Service de synthèse vocale

### Classes d'IA/ML

- **HandLandmarker** : Détection des landmarks de la main (MediaPipe)
- **TFLiteModel** : Modèle TensorFlow Lite générique
- **Landmark** : Représentation d'un point caractéristique de la main

### Classes de Données

- **GestureData** : Données d'un geste (lettre, image, traductions)
- **ConfigurationManager** : Gestion de la configuration de l'app

### Classes API

- **GoogleTranslateAPI** : Interface avec l'API Google Translate
