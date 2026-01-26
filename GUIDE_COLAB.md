# 🚀 Guide Google Colab - Compilation APK

## Vue d'ensemble

**Google Colab** est un service gratuit de Google qui permet d'exécuter du code Python dans le cloud. Nous allons l'utiliser pour compiler votre application en APK Android.

**Avantages :**

- ✅ Gratuit et dans le cloud
- ✅ Aucune installation locale nécessaire
- ✅ Fonctionne depuis n'importe quel navigateur
- ✅ Pas besoin de WSL ou Linux

**Temps total :** 30-45 minutes

---

## 📋 Étape 1 : Préparer le projet (2 minutes)

### A. Créer le fichier ZIP

**Option 1 - Script automatique (recommandé) :**

```bash
# Dans PowerShell ou CMD
cd c:\Users\dawse\Desktop\pfa
python prepare_for_colab.py
```

Le script va créer `pfa_project.zip` avec tous les fichiers nécessaires.

**Option 2 - Manuellement :**

Créer un ZIP contenant :

- `main.py`
- `buildozer.spec`
- `model.p`
- `model_sequence.p`
- `translations.json`
- `hand_landmarker.task`

---

## 📋 Étape 2 : Ouvrir Google Colab (1 minute)

1. **Aller sur :** <https://colab.research.google.com/>

2. **Se connecter** avec votre compte Google

3. **Uploader le notebook :**
   - Cliquer sur `Fichier` → `Importer un notebook`
   - Cliquer sur `Upload`
   - Sélectionner `c:\Users\dawse\Desktop\pfa\compile_apk.ipynb`

---

## 📋 Étape 3 : Compiler l'APK (30-40 minutes)

### Exécuter les cellules dans l'ordre

#### Cellule 1 : Installation des dépendances (~5 min)

```python
# Cliquer sur le bouton ▶️ à gauche de la cellule
# Attendre que l'installation se termine
```

#### Cellule 2 : Upload du projet (~1-2 min)

```python
# Cliquer sur ▶️
# Cliquer sur "Choisir les fichiers"
# Sélectionner pfa_project.zip
# Attendre l'upload (selon la taille du fichier)
```

#### Cellule 3 : Extraction (~10 secondes)

```python
# Cliquer sur ▶️
# Vérifier que tous les fichiers sont présents
```

#### Cellule 4 : Compilation ⏰ (~20-40 min)

```python
# Cliquer sur ▶️
# ATTENDRE... cette étape prend du temps !
# Vous pouvez minimiser Colab et revenir plus tard
```

**💡 Astuce :** Gardez l'onglet ouvert ou Colab pourrait interrompre la compilation.

#### Cellule 5 : Téléchargement de l'APK (~1 min)

```python
# Cliquer sur ▶️
# L'APK sera automatiquement téléchargé
```

---

## 📋 Étape 4 : Installer l'APK sur Android (5 minutes)

### A. Transférer l'APK

**Option 1 - USB :**

- Connecter votre téléphone au PC
- Copier l'APK dans le dossier Téléchargements du téléphone

**Option 2 - Email/Drive :**

- Envoyer l'APK par email à vous-même
- Ou uploader sur Google Drive et télécharger depuis le téléphone

### B. Installer l'APK

1. **Activer "Sources inconnues" :**
   - Paramètres → Sécurité
   - Activer "Sources inconnues" ou "Installer des applications inconnues"

2. **Installer :**
   - Ouvrir le fichier APK sur le téléphone
   - Cliquer sur "Installer"
   - Attendre l'installation

3. **Accorder les permissions :**
   - La première fois, l'app va demander :
     - ✅ Caméra (obligatoire)
     - ✅ Microphone (pour le TTS)

---

## 📋 Étape 5 : Tester l'application (5 minutes)

### A. Connecter au même WiFi

**ESP32-CAM et Android doivent être sur le même réseau WiFi !**

```
WiFi : "Votre_WiFi"
  ├── ESP32-CAM (ex: 192.168.1.100)
  └── Android     (ex: 192.168.1.XXX)
```

### B. Obtenir l'IP de l'ESP32

1. ESP32-CAM doit être allumé et connecté au WiFi
2. Vérifier l'IP via le moniteur série Arduino
3. Ou tester dans navigateur : `http://192.168.1.100:81/stream`

### C. Connecter dans l'application

1. Lancer l'application sur Android
2. Dans le champ IP : entrer `192.168.1.100` (votre IP ESP32)
3. Cliquer sur "Connect ESP32"
4. ✅ Le flux vidéo devrait apparaître !

---

## 🐛 Dépannage

### ❌ Erreur lors de la compilation Colab

**Problème :** Buildozer échoue

**Solutions :**

1. Exécuter la cellule de dépannage pour voir les logs
2. Vérifier que tous les fichiers sont dans le ZIP
3. Essayer de relancer depuis le début

### ❌ APK ne s'installe pas sur Android

**Problème :** "Application non installée"

**Solutions :**

1. Vérifier que "Sources inconnues" est activé
2. Désinstaller l'ancienne version si présente
3. Vérifier que l'APK n'est pas corrompu (re-télécharger)

### ❌ Connexion ESP32 échoue

**Problème :** "Impossible de se connecter"

**Solutions :**

1. Vérifier que ESP32 et Android sont sur le **même WiFi**
2. Tester l'URL dans navigateur : `http://IP_ESP32:81/stream`
3. Vérifier que l'ESP32 fonctionne (LED allumée)
4. Désactiver firewall du routeur si nécessaire

### ❌ Pas de flux vidéo

**Problème :** Connexion OK mais pas d'image

**Solutions :**

1. Redémarrer l'ESP32 (bouton RESET)
2. Vérifier la caméra de l'ESP32 (bien connectée)
3. Tester avec résolution plus basse dans `esp32_cam_full.ino`

---

## 📊 Checklist Complète

### Avant de commencer

- [ ] Fichiers `main.py`, `buildozer.spec`, `model.p`, etc. présents
- [ ] Compte Google disponible
- [ ] Connexion Internet stable

### Compilation Colab

- [ ] Script `prepare_for_colab.py` exécuté
- [ ] Fichier `pfa_project.zip` créé
- [ ] Notebook uploadé sur Google Colab
- [ ] Toutes les cellules exécutées avec succès
- [ ] APK téléchargé

### Installation Android

- [ ] APK transféré sur téléphone
- [ ] Sources inconnues activées
- [ ] APK installé
- [ ] Permissions accordées

### Test final

- [ ] ESP32-CAM allumé et connecté au WiFi
- [ ] IP ESP32 récupérée
- [ ] Android et ESP32 sur même WiFi
- [ ] Application lancée
- [ ] IP ESP32 entrée dans l'app
- [ ] Connexion réussie
- [ ] Flux vidéo visible
- [ ] Reconnaissance de signes fonctionne

---

## 🎯 Résumé

```
1. Préparer ZIP    → python prepare_for_colab.py
2. Google Colab    → Upload notebook + ZIP
3. Compiler        → Exécuter cellules (30-40 min)
4. Télécharger APK → Automatique
5. Installer       → Sur Android
6. Tester          → Connecter ESP32
```

**Temps total estimé :** 45-60 minutes (dont 30-40 minutes de compilation automatique)
