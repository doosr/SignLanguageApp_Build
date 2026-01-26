# 🔍 Capturer les Logs de Crash Android

## 📱 Étapes pour Obtenir les Logs

### 1. Préparer le Téléphone

1. **Activer Options Développeur:**
   - Paramètres → À propos du téléphone
   - Tapez 7 fois sur "Numéro de build"
   - Message: "Vous êtes développeur"

2. **Activer Débogage USB:**
   - Paramètres → Options pour développeurs
   - Activez "Débogage USB"

3. **Connecter en USB:**
   - Branchez le téléphone au PC
   - Autorisez "Débogage USB" (popup sur téléphone)

### 2. Vérifier la Connexion

```powershell
# Dans PowerShell
adb devices
```

**Résultat attendu:**

```
List of devices attached
ABC123XYZ    device
```

Si vide, vérifiez USB/permissions.

### 3. Capturer les Logs de Crash

```powershell
# Effacer anciens logs
adb logcat -c

# Lancer l'app sur le téléphone
# Attendez qu'elle crash

# Capturer les logs
adb logcat > crash_log.txt
```

Ou directement filtré:

```powershell
adb logcat | Select-String "python|Error|Exception|FATAL"
```

### 4. Chercher l'Erreur

Ouvrez `crash_log.txt` et cherchez:

- `AttributeError`
- `NameError`
- `FATAL EXCEPTION`
- `python`
- Ligne avec `main.py`

## 🎯 Scénarios Possibles

### Scénario 1: Ancien APK

**Erreur:** `NameError: name 'info_layout' is not defined`
**Solution:** Compiler le nouvel APK avec `bash ~/rebuild_apk_fixed.sh`

### Scénario 2: Problème Caméra

**Erreur:** `Camera not available` ou `Permission denied`
**Solution:** Vérifier permissions CAMERA dans l'app

### Scénario 3: Fichiers Manquants

**Erreur:** `FileNotFoundError: model.p`
**Solution:** Les fichiers .p ne sont pas inclus dans l'APK

### Scénario 4: OpenCV/MediaPipe

**Erreur:** `ImportError: cannot import opencv`
**Solution:** Créer APK sans opencv/mediapipe

## 📋 Commandes Rapides

```powershell
# Tout-en-un pour capturer le crash
adb devices
adb logcat -c
# Lancez l'app et laissez crasher
adb logcat | Select-String "python|FATAL" > crash.txt
```

## 🚀 Alternative: Nouvel APK d'Abord

**Avant de débugger, assurez-vous d'avoir le NOUVEL APK!**

```bash
# Dans WSL - Compiler le nouvel APK
source ~/buildozer-env/bin/activate
bash ~/rebuild_apk_fixed.sh
```

Puis:

1. Désinstallez l'ancienne app
2. Installez le nouvel APK
3. Testez
4. Si crash encore → Capturez logs

## ✅ Ce Que Je Dois Voir

Partagez-moi:

1. Est-ce le nouvel APK ou l'ancien?
2. Les logs ADB avec l'erreur
3. Le message exact du crash
