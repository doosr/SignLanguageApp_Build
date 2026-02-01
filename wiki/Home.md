# 🤟 SignLanguage App - Wiki

Bienvenue sur le Wiki de **SignLanguage**, une application mobile de traduction bidirectionnelle de la langue des signes en temps réel.

## 📱 Vue d'ensemble

SignLanguage utilise l'intelligence artificielle (MediaPipe + TensorFlow Lite) pour offrir une communication bidirectionnelle entre personnes sourdes et entendantes.

### Fonctionnalités principales

- **🔤 Mode Reconnaissance** : Traduit les gestes en texte et parole (FR/EN/AR)
- **💬 Mode Inverse** : Convertit la voix/texte en gestes de langue des signes
- **🌍 Multilingue** : Support français, anglais, arabe
- **📡 ESP32-CAM** : Capture vidéo distante via WiFi
- **🔒 On-device** : Traitement local sans serveur (vie privée)

### Performances

| Métrique | Valeur |
|----------|--------|
| Précision lettres | 90.3% |
| Précision mots | 78.5% |
| Latence | 75ms |
| FPS | 20-30 |

## 📚 Documentation

### Pour les utilisateurs

- [Installation](Installation) - Guide d'installation Android et Windows
- [Guide utilisateur](User-Guide) - Comment utiliser l'application
- [FAQ](FAQ) - Questions fréquentes

### Pour les développeurs

- [Architecture](Architecture) - Architecture technique du système
- [Build Guide](Build-Guide) - Compiler l'application
- [API Documentation](API-Documentation) - Documentation des APIs
- [Contributing](Contributing) - Contribuer au projet

## 🚀 Démarrage rapide

### Android

1. Téléchargez l'APK depuis [GitHub Actions](https://github.com/doosr/SignLanguageApp_Build/actions)
2. Installez sur votre téléphone
3. Autorisez les permissions caméra et micro
4. Lancez l'application !

### Windows

1. Téléchargez le ZIP portable depuis [GitHub Actions](https://github.com/doosr/SignLanguageApp_Build/actions)
2. Extrayez le ZIP
3. Lancez `sign_language_app.exe`

## 🛠️ Technologies

- **Frontend** : Flutter 3.16
- **IA** : TensorFlow Lite, MediaPipe
- **IoT** : ESP32-CAM
- **Langages** : Dart, Python, C++

## 📊 Statistiques du projet

- **Lignes de code** : ~15,000
- **Modèles IA** : 2 (CNN + LSTM)
- **Dataset** : 3,200+ échantillons
- **Langues supportées** : 3

## 🤝 Contribution

Les contributions sont les bienvenues ! Consultez le [guide de contribution](Contributing).

## 📄 Licence

Ce projet est sous licence MIT.

## 📞 Contact

- **Auteur** : Belgacem Dawser
- **Email** : [votre-email]
- **GitHub** : [@doosr](https://github.com/doosr)
