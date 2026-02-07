# Diagramme de Cas d'Utilisation Corrigé - SignLanguage App

```mermaid
graph TB
    %% Acteurs
    PS[("👤<br/>Personne<br/>Sourde")]
    PE[("👤<br/>Personne<br/>Entendante")]
    ESP32[("📷<br/>ESP32-CAM")]
    IA[("🤖<br/>Système IA")]
    
    %% Système principal
    subgraph SYSTEM["Application SignLanguage"]
        %% Mode Reconnaissance
        subgraph MODE_RECO["Mode Reconnaissance"]
            UC1([Reconnaître<br/>un geste])
            UC2([Choisir mode<br/>Lettres/Mots])
            
            subgraph IA_RECO["Composants IA"]
                UC3([Détecter landmarks<br/>HandLandmarker])
                UC4([Inférence modèle<br/>ModelService + TFLiteModel])
                UC5([Traduire texte<br/>TranslationService])
                UC6([Synthétiser parole<br/>TextToSpeechService])
            end
        end
        
        %% Mode Inverse
        subgraph MODE_INV["Mode Inverse"]
            UC7([Mode Inverse<br/>Voix → Gestes])
            
            subgraph IA_INV["Composants IA"]
                UC8([Reconnaître voix<br/>SpeechToTextService])
                UC9([Traduire lettres<br/>TranslationService])
                UC10([Afficher gestes<br/>GestureData])
            end
        end
        
        %% Configuration
        subgraph CONFIG["Configuration"]
            UC11([Sélectionner langue<br/>FR/EN/Darja])
            UC12([Configurer<br/>ESP32-CAM])
            UC13([Changer caméra<br/>CameraService])
        end
    end
    
    %% Relations Personne Sourde
    PS -->|Fait geste| UC1
    PS --> UC2
    PS --> UC11
    PS --> UC12
    
    %% Relations reconnaissance
    UC1 -.->|<<include>>| UC3
    UC3 -.->|<<include>>| UC4
    UC4 -.->|<<include>>| UC5
    UC5 -.->|<<include>>| UC6
    
    %% Relations Personne Entendante
    PE -->|Parle| UC7
    PE --> UC11
    
    %% Relations mode inverse
    UC7 -.->|<<include>>| UC8
    UC8 -.->|<<include>>| UC9
    UC9 -.->|<<include>>| UC10
    
    %% Relations ESP32-CAM
    ESP32 -->|Stream vidéo| UC13
    UC13 -.->|<<extend>>| UC1
    
    %% Relations Système IA
    IA -.->|Traite| UC3
    IA -.->|Traite| UC4
    IA -.->|Traite| UC5
    IA -.->|Traite| UC6
    IA -.->|Traite| UC8
    IA -.->|Traite| UC9
    
    classDef actorStyle fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef ucStyle fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef iaStyle fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    
    class PS,PE,ESP32,IA actorStyle
    class UC1,UC2,UC7,UC11,UC12,UC13 ucStyle
    class UC3,UC4,UC5,UC6,UC8,UC9,UC10 iaStyle
```

## Légende

### Acteurs

- **Personne Sourde** : Utilise le mode reconnaissance (geste → texte/parole)
- **Personne Entendante** : Utilise le mode inverse (voix → gestes)
- **ESP32-CAM** : Caméra WiFi pour capture à distance
- **Système IA** : Composants d'intelligence artificielle

### Cas d'Utilisation Principaux

**Mode Reconnaissance** :

- UC1 : Reconnaître un geste
- UC2 : Choisir mode (Lettres A-Z ou Mots)

**Composants IA - Reconnaissance** :

- UC3 : Détecter landmarks (HandLandmarker MediaPipe - 21 points)
- UC4 : Inférence modèle (ModelService + TFLiteModel)
- UC5 : Traduire texte (TranslationService + GoogleTranslateAPI)
- UC6 : Synthétiser parole (TextToSpeechService)

**Mode Inverse** :

- UC7 : Mode Inverse (Voix → Gestes)

**Composants IA - Mode Inverse** :

- UC8 : Reconnaître voix (SpeechToTextService)
- UC9 : Traduire lettres (TranslationService)
- UC10 : Afficher gestes (GestureData - 156 images)

**Configuration** :

- UC11 : Sélectionner langue (FR/EN/Darja)
- UC12 : Configurer ESP32-CAM
- UC13 : Changer source caméra (CameraService)

### Relations

- **Flèches pleines** : Association acteur → cas d'utilisation
- **Flèches pointillées** : Relations <<include>> et <<extend>>
- **Couleurs** :
  - Bleu : Acteurs
  - Jaune : Cas d'utilisation principaux
  - Vert : Composants IA
