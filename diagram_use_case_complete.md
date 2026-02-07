# Diagramme de Cas d'Utilisation Complet - SignLanguage App

```mermaid
graph TB
    %% Acteurs
    PS[("👤<br/>Personne<br/>Sourde")]
    PE[("👤<br/>Personne<br/>Entendante")]
    ESP32[("📷<br/>ESP32-CAM")]
    ADMIN[("⚙️<br/>Administrateur")]
    
    %% Système principal
    subgraph SYSTEM["Application SignLanguage"]
        %% Mode Reconnaissance
        subgraph MODE_RECO["Mode Reconnaissance"]
            UC1([Reconnaître geste<br/>lettre])
            UC2([Reconnaître geste<br/>mot])
            UC3([Traduire en texte])
            UC4([Synthétiser vocalement<br/>TTS])
            UC5([Afficher résultat<br/>visuel])
        end
        
        %% Mode Inverse
        subgraph MODE_INV["Mode Inverse"]
            UC6([Reconnaître voix<br/>STT])
            UC7([Convertir texte<br/>en gestes])
            UC8([Afficher séquence<br/>de gestes])
        end
        
        %% Configuration
        subgraph CONFIG["Configuration"]
            UC9([Sélectionner langue<br/>FR/EN/Darja])
            UC10([Choisir mode<br/>lettre/mot])
            UC11([Configurer ESP32-CAM<br/>IP/Stream])
            UC12([Changer source caméra<br/>Phone/ESP32])
        end
        
        %% Gestion données
        subgraph DATA["Gestion Données"]
            UC13([Entraîner modèle<br/>TFLite])
            UC14([Collecter images<br/>gestes])
            UC15([Exporter statistiques<br/>reconnaissance])
        end
    end
    
    %% Relations Personne Sourde
    PS -->|Fait geste| UC1
    PS -->|Fait geste| UC2
    UC1 --> UC3
    UC2 --> UC3
    UC3 --> UC4
    UC3 --> UC5
    
    %% Relations Mode Inverse
    PE -->|Parle| UC6
    UC6 --> UC7
    UC7 --> UC8
    UC8 -->|Voit gestes| PS
    
    %% Relations Configuration
    PS --> UC9
    PE --> UC9
    PS --> UC10
    PE --> UC10
    PS --> UC11
    PS --> UC12
    
    %% Relations ESP32-CAM
    ESP32 -->|Stream vidéo| UC1
    ESP32 -->|Stream vidéo| UC2
    
    %% Relations Administrateur
    ADMIN --> UC13
    ADMIN --> UC14
    ADMIN --> UC15
    
    %% Relations includes/extends
    UC3 -.->|<<include>>| UC9
    UC4 -.->|<<include>>| UC9
    UC6 -.->|<<include>>| UC9
    UC7 -.->|<<include>>| UC9
    
    UC1 -.->|<<extend>>| UC12
    UC2 -.->|<<extend>>| UC12
    
    classDef actorStyle fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef ucStyle fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef systemStyle fill:#f3e5f5,stroke:#4a148c,stroke-width:3px
    
    class PS,PE,ESP32,ADMIN actorStyle
    class UC1,UC2,UC3,UC4,UC5,UC6,UC7,UC8,UC9,UC10,UC11,UC12,UC13,UC14,UC15 ucStyle
```

## Description des Cas d'Utilisation

### Mode Reconnaissance

- **UC1 - Reconnaître geste lettre** : Détecte et identifie une lettre de l'alphabet en langage des signes (A-Z)
- **UC2 - Reconnaître geste mot** : Détecte et identifie un mot complet en langage des signes (HELLO, THANK YOU, etc.)
- **UC3 - Traduire en texte** : Convertit le geste reconnu en texte dans la langue sélectionnée
- **UC4 - Synthétiser vocalement** : Lit le texte traduit à voix haute via TTS
- **UC5 - Afficher résultat visuel** : Affiche le résultat à l'écran avec animations

### Mode Inverse

- **UC6 - Reconnaître voix** : Capture et transcrit la parole en texte via Speech-to-Text
- **UC7 - Convertir texte en gestes** : Transforme chaque lettre du texte en geste correspondant
- **UC8 - Afficher séquence de gestes** : Affiche les images des gestes en séquence

### Configuration

- **UC9 - Sélectionner langue** : Choix entre Français, Anglais, ou Arabe
- **UC10 - Choisir mode** : Sélection du mode reconnaissance (lettres ou mots)
- **UC11 - Configurer ESP32-CAM** : Configuration de l'IP et du stream de l'ESP32-CAM
- **UC12 - Changer source caméra** : Basculer entre caméra du téléphone et ESP32-CAM

### Gestion Données (Admin)

- **UC13 - Entraîner modèle** : Entraîner les modèles TensorFlow Lite avec nouvelles données
- **UC14 - Collecter images** : Capturer des images de gestes pour enrichir le dataset
- **UC15 - Exporter statistiques** : Générer des rapports sur les performances de reconnaissance
