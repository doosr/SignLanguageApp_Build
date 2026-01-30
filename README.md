# SignLanguage - Traduction de la Langue des Signes en Temps Réel

## 📱 Description

Ce rapport présente le développement de **SignLanguage**, une application mobile innovante de traduction de la langue des signes en temps réel, réalisée durant un stage de perfectionnement d'un mois à la Pépinière d'Entreprises APII Mahdia (janvier 2026).

SignLanguage utilise l'intelligence artificielle (MediaPipe + TensorFlow Lite) pour reconnaître les gestes de la main et les traduire instantanément en texte et en parole dans trois langues (français, anglais, arabe). L'application atteint **90.3% de précision** pour les lettres et **78.5% pour les mots**, avec une latence de seulement **75 millisecondes**.

Le projet combine développement mobile (Flutter), apprentissage automatique (CNN, LSTM), vision par ordinateur (MediaPipe) et IoT (ESP32-CAM). Il répond à un besoin social réel en facilitant la communication pour environ **100 000 personnes sourdes en Tunisie**.

## ✨ Fonctionnalités

### Mode Reconnaissance (Gestes → Texte/Parole)

- ✅ **Reconnaissance en temps réel** des gestes de la main
- ✅ **Détection de lettres** (A-Z, alphabet langue des signes)
- ✅ **Détection de mots** (vocabulaire courant)
- ✅ **Support multilingue** : Français, English, العربية
- ✅ **Synthèse vocale (TTS)** pour prononcer le texte traduit
- ✅ **Interface accessible** avec emojis pour personnes sourdes
- ✅ **Mode ESP32-CAM** pour caméra externe

### 🆕 Mode Inverse (Texte → Gestes) - À AJOUTER
>
> **Fonctionnalité à développer** : Permettre à l'utilisateur d'écrire du texte et afficher les gestes correspondants de la langue des signes lettre par lettre.
>
> **Objectif** : Une personne entendante écrit un message, et l'application montre les gestes à effectuer pour communiquer avec une personne sourde.
>
> **Implémentation prévue** :
>
> - Interface de saisie texte
> - Animation ou images des gestes pour chaque lettre
> - Lecture séquentielle lettre par lettre
> - Contrôle de vitesse d'affichage

## 🎯 Performance

| Métrique | Valeur | Objectif |
|----------|--------|----------|
| Précision Lettres | **90.3%** | ≥85% ✅ |
| Précision Mots | **78.5%** | ≥75% ✅ |
| Latence | **75ms** | <100ms ✅ |
| FPS | **24** | ≥20 ✅ |
| Langues supportées | **3** | FR/EN/AR ✅ |
| Taille APK | **42 MB** | <50MB ✅ |

## 🛠️ Technologies

- **Flutter 3.16**: Développement mobile cross-platform
- **MediaPipe Hands**: Détection de 21 landmarks de la main
- **TensorFlow Lite**: Modèles d'IA on-device (CNN pour lettres, LSTM pour mots)
- **ESP32-CAM**: Module caméra IoT pour capture distante
- **Text-to-Speech**: Synthèse vocale multilingue
- **Translator**: Traduction FR/EN/AR

## 📦 Installation

1. **Cloner le dépôt**

```bash
git clone https://github.com/votre-nom/SignLanguage.git
cd SignLanguage
```

1. **Installer les dépendances Flutter**

```bash
cd flutter_app
flutter pub get
```

1. **Copier les modèles TFLite**

```bash
# Les modèles sont dans flutter_app/assets/
# - letter_classifier.tflite
# - word_classifier.tflite
# - labels.txt
```

1. **Lancer l'application**

```bash
flutter run
```

## 🔬 Collecte de Données et Entraînement

### 1. Créer le Dataset

```bash
python create_dataset.py
# Suivez les gestes devant la webcam
# Génère: data.pickle (3000+ échantillons)
```

### 2. Entraîner les Modèles

```bash
python train_classifier.py
# Génère: letter_classifier.tflite (90.3% précision)
#         word_classifier.tflite (78.5% précision)
```

### 3. Tester l'Inférence

```bash
python inference_classifier.py  # Mode lettres
python inference_sequence.py    # Mode mots
```

## 📁 Structure du Projet

```
SignLanguage/
├── flutter_app/              # Application mobile Flutter
│   ├── lib/
│   │   └── main.dart        # Code principal
│   ├── assets/              # Modèles TFLite
│   └── pubspec.yaml
├── esp32_cam/               # Firmware ESP32-CAM
│   └── esp32_cam_stream.ino
├── create_dataset.py        # Collecte de données
├── train_classifier.py      # Entraînement modèles
├── inference_classifier.py  # Test lettres
├── inference_sequence.py    # Test mots
└── README.md
```

## 🌍 Mots-clés

`Langue des signes` • `Intelligence artificielle` • `Flutter` • `MediaPipe` • `TensorFlow Lite` • `Accessibilité` • `IoT` • `ESP32-CAM` • `Reconnaissance gestuelle` • `Vision par ordinateur` • `Inclusion sociale` • `Application mobile` • `Temps réel` • `On-device AI`

## 📊 Utilisation

1. **Lancer l'app SignLanguage**
2. **Sélectionner le mode** : 🔤 Lettres ou 💬 Mots
3. **Choisir la langue** : 🇫🇷 FR / 🇬🇧 EN / 🇹🇳 AR
4. **Faire des gestes** devant la caméra
5. **Voir la traduction** s'afficher en temps réel
6. **Écouter** la synthèse vocale

## 🏆 Impact Social

- **100 000 personnes sourdes** en Tunisie peuvent bénéficier de cette solution
- **Gratuit et accessible** : pas besoin d'interprète (50-100 DT/h)
- **Support de l'arabe** : innovation rare pour la communauté maghrébine
- **On-device** : fonctionne sans internet
- **Interface accessible** : emojis pour faciliter l'usage

## 🚀 Perspectives

### Court terme (3-6 mois)

- [ ] Extension vocabulaire (50 mots)
- [ ] Mode sombre/clair
- [ ] Déploiement Google Play Store
- [ ] **Mode inverse : Texte → Gestes**

### Moyen terme (6-12 mois)

- [ ] Reconnaissance expressions faciales
- [ ] Grammaire LSF
- [ ] Déploiement iOS

### Long terme (1-2 ans)

- [ ] Reconnaissance continue
- [ ] Réalité augmentée
- [ ] Support ASL, BSL, autres langues des signes

## 📄 Licence

MIT License

## 👨‍💻 Auteur

Projet réalisé dans le cadre d'un stage de perfectionnement  
**Pépinière d'Entreprises APII Mahdia** (Janvier 2026)  
**ISET Mahdia** - 2024-2025

## 🙏 Remerciements

- Pépinière d'Entreprises APII Mahdia
- Programme "startup APII" (Janvier 2026)
- ISET Mahdia
- Communauté sourde tunisienne
