# ❓ FAQ - Questions fréquentes

## Général

### Qu'est-ce que SignLanguage ?

SignLanguage est une application mobile de traduction bidirectionnelle de la langue des signes en temps réel. Elle utilise l'IA (MediaPipe + TensorFlow Lite) pour traduire les gestes en texte/parole et vice-versa.

### L'application est-elle gratuite ?

Oui, SignLanguage est entièrement gratuite et open-source.

### Quelles langues sont supportées ?

- 🇫🇷 Français
- 🇬🇧 English
- 🇹🇳 العربية (Arabe)

### L'application fonctionne-t-elle hors ligne ?

Oui ! Tout le traitement est fait **on-device** (sur votre appareil). Aucune connexion internet n'est requise, sauf pour l'ESP32-CAM qui nécessite le WiFi local.

## Installation

### Où télécharger l'application ?

Sur [GitHub Actions](https://github.com/doosr/SignLanguageApp_Build/actions) :

- **Android** : Artifact "SignLanguageApp-Android-APK"
- **Windows** : Artifact "Windows-Portable"

### "Sources inconnues" sur Android ?

C'est normal. L'APK n'est pas sur le Play Store. Autorisez l'installation depuis les paramètres de sécurité de votre téléphone.

### Erreur certificat sur Windows ?

Deux solutions :

1. **Mode Développeur** : Paramètres → Pour les développeurs → Activer
2. **Version portable** : Utilisez le ZIP (pas besoin de certificat)

### L'application ne s'installe pas ?

- **Android** : Vérifiez l'espace libre (50 MB minimum)
- **Windows** : Vérifiez que vous avez Windows 10/11

## Utilisation

### La caméra ne fonctionne pas ?

1. Vérifiez les permissions (Paramètres → Applications → SignLanguage)
2. Redémarrez l'application
3. Essayez de basculer entre caméra avant/arrière

### Les gestes ne sont pas reconnus ?

Astuces :

- ✅ Bon éclairage
- ✅ Fond uni
- ✅ Distance 30-50 cm
- ✅ Gestes clairs et maintenus 1-2 secondes

### Quelle est la précision ?

- **Lettres** : 90.3%
- **Mots** : 78.5%

### Combien de mots sont reconnus ?

15 mots courants : Bonjour, Merci, S'il vous plaît, Oui, Non, Aidez-moi, Famille, Travail, Manger, Boire, École, Maison, Ami, Téléphone, Médecin.

### La synthèse vocale ne fonctionne pas ?

1. Vérifiez le volume de votre appareil
2. Vérifiez les permissions microphone
3. Essayez de changer de langue

## ESP32-CAM

### Qu'est-ce que l'ESP32-CAM ?

Un module caméra WiFi optionnel qui permet de capturer les gestes à distance sans tenir le téléphone.

### Est-ce obligatoire ?

Non, l'ESP32-CAM est totalement optionnel. L'application fonctionne parfaitement avec la caméra du téléphone.

### Comment configurer l'ESP32-CAM ?

1. Flasher le firmware (disponible dans `esp32_cam_platformio/`)
2. Configurer le WiFi dans `include/config.h`
3. Entrer l'IP dans l'application

### L'ESP32-CAM ne se connecte pas ?

- Vérifiez que l'ESP32 et le téléphone sont sur le même réseau WiFi
- Vérifiez l'adresse IP (doit être `192.168.X.X`)
- Testez avec un navigateur : `http://<IP>:81/stream`

## Performances

### L'application est lente ?

- Fermez les autres applications
- Réduisez la luminosité
- Désactivez l'ESP32-CAM si non utilisé

### La batterie se vide vite ?

C'est normal, la reconnaissance vidéo en temps réel consomme de l'énergie. Conseils :

- Utilisez en charge si possible
- Fermez l'app quand vous ne l'utilisez pas

### Quelle est la latence ?

75ms en moyenne (temps entre le geste et l'affichage du résultat).

## Technique

### Quelles technologies sont utilisées ?

- **Frontend** : Flutter
- **IA** : TensorFlow Lite, MediaPipe
- **IoT** : ESP32-CAM (C/C++)

### Puis-je contribuer au projet ?

Oui ! Consultez le [guide de contribution](Contributing).

### Où sont stockées mes données ?

Nulle part ! Tout est traité localement sur votre appareil. Aucune donnée n'est envoyée à des serveurs.

### L'application collecte-t-elle des données ?

Non. Aucune télémétrie, aucun tracking, aucune collecte de données.

## Problèmes courants

### "Caméra non disponible" (Android)

- Autorisez les permissions caméra
- Redémarrez l'application
- Vérifiez qu'aucune autre app n'utilise la caméra

### Fenêtre invisible (Windows)

- Téléchargez la dernière version
- Vérifiez le Gestionnaire des tâches (processus en arrière-plan ?)

### Crash au lancement

- Réinstallez l'application
- Vérifiez l'espace disque
- Ouvrez une [issue GitHub](https://github.com/doosr/SignLanguageApp_Build/issues)

## Support

### Comment obtenir de l'aide ?

1. Consultez cette FAQ
2. Lisez le [Guide utilisateur](User-Guide)
3. Ouvrez une [issue sur GitHub](https://github.com/doosr/SignLanguageApp_Build/issues)

### Comment signaler un bug ?

Ouvrez une [issue GitHub](https://github.com/doosr/SignLanguageApp_Build/issues) avec :

- Description du problème
- Étapes pour reproduire
- Version de l'application
- Système d'exploitation

### Puis-je suggérer une fonctionnalité ?

Oui ! Ouvrez une [issue GitHub](https://github.com/doosr/SignLanguageApp_Build/issues) avec le tag "enhancement".
