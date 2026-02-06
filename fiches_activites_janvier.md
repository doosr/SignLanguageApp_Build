# Fiches d'Activités Journalières du Stagiaire - Janvier 2026

Voici 4 fiches d'activités hebdomadaires couvrant tout le mois de Janvier 2026 pour le projet **SignLanguage**.

---

## 📅 SEMAINE N° 1 : DU 01/01/2026 AU 05/01/2026

| Jour       | Service | Activités réalisées | Moyens mobilisés (Equipements, outillage, logiciels, documentations) |
| :--- | :--- | :--- | :--- |
| **Lundi**    | R&D / Analyse | • Prise de contact avec l'encadrant et présentation du sujet PFE.<br>• Analyse du cahier des charges et des besoins fonctionnels.<br>• Recherche bibliographique sur la LSF et la reconnaissance de gestes. | • Ordinateur portable<br>• Connexion Internet<br>• Documentation MediaPipe/TensorFlow |
| **Mardi**    | Conception | • Étude de l'état de l'art des solutions existantes (HandTalk, SignAll).<br>• Choix des technologies (Flutter, ESP32-CAM, TensorFlow Lite).<br>• Installation de l'environnement de développement (VS Code, Flutter SDK). | • VS Code, Android Studio<br>• Flutter SDK, Dart<br>• GitHub (création repo) |
| **Mercredi** | Conception | • Élaboration des diagrammes de cas d'utilisation (UML).<br>• Définition de l'architecture logicielle globale (MVVM).<br>• Planification du projet (diagramme de Gantt). | • StarUML / Lucidchart<br>• Trello / Jira<br>• Document de spécification |
| **Jeudi**    | Prototypage | • Création des premières maquettes UI/UX (wireframes).<br>• Conception de l'identité visuelle (Logo, Palette de couleurs).<br>• Test de HelloWorld sur émulateur Android. | • Figma / Adobe XD<br>• Adobe Illustrator<br>• Émulateur Pixel 6 |
| **Vendredi** | Développement | • Initialisation du projet Flutter `sign_language_app`.<br>• Configuration des packages de base (camera, tflite, provider).<br>• Réunion de validation de la semaine 1 avec l'encadrant. | • PC Développement<br>• Git / GitHub<br>• Smartphone Android de test |
| **Samedi**   | Auto-formation | • Formation approfondie sur le framework MediaPipe Hands.<br>• Tutoriels sur l'intégration de modèles TFLite dans Flutter. | • Documentation Google AI<br>• Cours en ligne (Udemy/Youtube) |

---

## 📅 SEMAINE N° 2 : DU 06/01/2026 AU 12/01/2026

| Jour       | Service | Activités réalisées | Moyens mobilisés (Equipements, outillage, logiciels, documentations) |
| :--- | :--- | :--- | :--- |
| **Lundi**    | Développement UI | • Développement de la page d'accueil (Home Screen) avec animations.<br>• Intégration de la navigation et du thème (Mode Sombre/Clair).<br>• Création des composants réutilisables (Boutons, Cards). | • Flutter/Dart<br>• Librairie `animations`<br>• Figma (référence) |
| **Mardi**    | Développement UI | • Mise en place de l'interface `RecognitionScreen`.<br>• Intégration du composant Caméra (`camera` plugin).<br>• Gestion des permissions (Caméra, Micro) sur Android. | • Android Manifest<br>• Plugin `permission_handler`<br>• Appareil physique Android |
| **Mercredi** | IA / Data | • Collecte de dataset d'images de mains pour l'alphabet (A-Z).<br>• Nettoyage et annotation des données (Labellisation).<br>• Préparation de l'environnement Python pour l'entraînement. | • Webcam / Smartphone<br>• LabelImg / Roboflow<br>• Python, OpenCV |
| **Jeudi**    | IA / Training | • Création du script d'entraînement IA (Python/Keras).<br>• Entraînement du modèle de détection de lettres (CNN).<br>• Évaluation des performances du modèle (précision > 90%). | • Google Colab (GPU)<br>• TensorFlow / Keras<br>• Jupyter Notebook |
| **Vendredi** | Intégration IA | • Conversion du modèle Keras (.h5) en format TFLite (.tflite).<br>• Intégration du modèle TFLite dans l'application Flutter.<br>• Premiers tests de détection en temps réel. | • TFLite Converter<br>• Plugin `tflite_flutter`<br>• App Android de test |
| **Samedi**   | Debugging | • Optimisation de la fluidité de la caméra (FPS).<br>• Correction des bugs de détection (latence).<br>• Rédaction du rapport d'avancement S2. | • Flutter DevTools<br>• Profiler Performance |

---

## 📅 SEMAINE N° 3 : DU 13/01/2026 AU 19/01/2026

| Jour       | Service | Activités réalisées | Moyens mobilisés (Equipements, outillage, logiciels, documentations) |
| :--- | :--- | :--- | :--- |
| **Lundi**    | IoT / Embarqué | • Étude de la carte ESP32-CAM pour la capture externe.<br>• Installation de l'IDE Arduino et configuration ESP32.<br>• Test du module Caméra OV2640. | • Module ESP32-CAM<br>• Module FTDI (USB-Serial)<br>• Arduino IDE |
| **Mardi**    | IoT / Réseau | • Développement du serveur Web de streaming vidéo sur l'ESP32.<br>• Configuration du mode Point d'Accès (AP) et Station (STA).<br>• Test du flux MJPEG sur navigateur. | • C++ / Arduino<br>• Librairie `esp32-camera`<br>• Réseau Wi-Fi local |
| **Mercredi** | Intégration App | • Développement du service de connexion Wi-Fi dans Flutter.<br>• Récupération et affichage du flux ESP32 sur l'application.<br>• Gestion des erreurs de connexion et timeouts. | • Plugin `http`<br>• Widget MJPEG<br>• Wireshark (analyse réseau) |
| **Jeudi**    | Fonctionnalité | • Implémentation du "Mode Reconnaissance" complet.<br>• Ajout de l'algorithme de lissage des landmarks (filtre).<br>• Affichage du squelette de la main en superposition (Overlay). | • `CustomPainter` Flutter<br>• Algorithme Moyenne Mobile<br>• Maths Vectorielles |
| **Vendredi** | Traduction | • Intégration de l'API Google Translate pour la traduction.<br>• Développement de la logique de traduction FR ↔ EN ↔ AR.<br>• Système de mise en cache des traductions fréquentes. | • API Google Translate<br>• `shared_preferences`<br>• JSON |
| **Samedi**   | Validation | • Tests d'intégration App Mobile + ESP32 Webserver.<br>• Validation de la détection à distance via ESP32.<br>• Mise à jour de la documentation technique. | • Banc de test complet<br>• Multimètre (vérif tensions)<br>• Word / Markdown |

---

## 📅 SEMAINE N° 4 : DU 20/01/2026 AU 31/01/2026

| Jour       | Service | Activités réalisées | Moyens mobilisés (Equipements, outillage, logiciels, documentations) |
| :--- | :--- | :--- | :--- |
| **Lundi**    | Développement | • Finalisation de l'interface "Mode Inverse" (Speech-to-Sign).<br>• Intégration de la reconnaissance vocale (Speech-to-Text).<br>• Affichage des images de signes correspondantes aux mots. | • Plugin `speech_to_text`<br>• Assets Images (Dataset)<br>• UI Animation |
| **Mardi**    | CI/CD & Tests | • Configuration de GitHub Actions pour le build automatique (APK).<br>• Résolution des erreurs de build Gradle et dépendances.<br>• Création de la première Release APK stable. | • GitHub Actions (YAML)<br>• Gradle<br>• Keystore (signature app) |
| **Mercredi** | Site Web | • Conception de la Landing Page de présentation du projet.<br>• Développement HTML/CSS/JS avec animations AOS.<br>• Intégration du lien de téléchargement automatique. | • HTML5, CSS3, React<br>• VS Code<br>• GitHub Pages |
| **Jeudi**    | Optimisation | • Optimisation de la taille de l'APK (Tree Shaking).<br>• Amélioration de l'accessibilité (Contrastes, Text-to-Speech).<br>• Tests utilisateurs avec des collègues pour feedbacks. | • Flutter Analyzer<br>• Plugin `flutter_tts`<br>• Grille d'évaluation UX |
| **Vendredi** | Rapport | • Rédaction du chapitre "Réalisation" du rapport de stage.<br>• Création des diagrammes finaux (Architecture, Classes) pour le rapport.<br>• Capture d'écran et enregistrement de démos vidéo. | • Microsoft Word<br>• OBS Studio<br>• Draw.io |
| **Samedi**   | Clôture Mois | • Réunion de fin de mois avec l'encadrant.<br>• Bilan des tâches réalisées vs prévues.<br>• Planification des tâches pour Février (Améliorations IA). | • PowerPoint (Présentation)<br>• Excel (Suivi projet)<br>• Roadmap projet |

---

### 📝 Observations du mois

- **Points forts** : L'intégration du modèle TFLite et la communication avec l'ESP32 sont fonctionnelles. L'interface utilisateur est moderne et fluide.
- **Difficultés rencontrées** : Quelques problèmes de latence avec le flux vidéo ESP32 résolus par optimisation du buffer. La configuration du build Android a pris plus de temps que prévu.
- **Objectifs Février** : Améliorer la précision du modèle IA pour les phrases complexes et ajouter le support du mode hors-ligne complet.
