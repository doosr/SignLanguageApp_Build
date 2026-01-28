# Guide de Débogage Flutter avec ADB

## 🔧 Installation et Configuration ADB

### 1. Installer ADB

**Windows:**

- Télécharger [Android Platform Tools](https://developer.android.com/studio/releases/platform-tools)
- Extraire le ZIP
- Ajouter le dossier au PATH ou utiliser depuis le dossier

**Ou via Flutter:**

```bash
# ADB est inclus avec Flutter SDK
flutter doctor -v  # Affiche le chemin vers ADB
```

### 2. Activer le Débogage USB sur le Téléphone

1. **Paramètres** → **À propos du téléphone**
2. Taper 7 fois sur **Numéro de build** (active Mode Développeur)
3. Retour → **Options pour développeurs**
4. Activer **Débogage USB**
5. Brancher le téléphone via USB
6. Accepter l'autorisation de débogage USB

### 3. Vérifier la Connexion

```bash
adb devices
```

Devrait afficher:

```
List of devices attached
ABC123XYZ    device
```

---

## 📱 Commandes ADB Essentielles

### Lancer l'App en Mode Debug

```bash
cd c:\Users\dawse\Desktop\pfa\flutter_app
flutter run --verbose
```

### Voir les Logs en Temps Réel

```bash
# Tous les logs
adb logcat

# Filtrer uniquement Flutter
adb logcat -s flutter

# Filtrer par tag personnalisé
adb logcat | findstr "Camera\\|Vision\\|TFLite\\|HandLandmarker"

# Effacer les anciens logs puis suivre
adb logcat -c && adb logcat -s flutter
```

### Logs Spécifiques à votre App

```bash
# Logs avec timestamps
adb logcat -v time | findstr "flutter"

# Sauvegarder les logs dans un fichier
adb logcat -d > logs.txt
```

---

## 🐛 Diagnostiquer les Problèmes de Détection

### Problème 1: Caméra ne s'initialise pas

**Commande:**

```bash
adb logcat | findstr "Camera\\|camera"
```

**Messages d'erreur possibles:**

```
CameraException: Camera not available
permission_handler: PERMISSION_DENIED
```

**Solutions:**

1. Vérifier les permissions dans `AndroidManifest.xml`:

```bash
adb shell dumpsys package com.example.flutter_app | findstr permission
```

1. Réinstaller l'app avec permissions:

```bash
flutter clean
flutter run
# Accepter permissions caméra quand demandé
```

---

### Problème 2: Hand Landmarker ne détecte rien

**Ajouter des logs de débogage dans `main.dart`:**

```dart
void _processCameraImage(CameraImage image) async {
  if (_isDetecting || _plugin == null) return;
  _isDetecting = true;
  
  print("📷 Processing image: ${image.width}x${image.height}"); // LOG
  
  try {
    final hands = _plugin!.detect(image, _controller!.description.sensorOrientation);
    
    print("✋ Hands detected: ${hands.length}"); // LOG
    
    if (hands.isNotEmpty) {
      print("🎯 First hand landmarks: ${hands[0].landmarks.length}"); // LOG
    }
    
    // ... reste du code
  } catch (e) {
    print("❌ Vision error: $e"); // LOG
  } finally {
    _isDetecting = false;
  }
}
```

**Voir les logs:**

```bash
adb logcat | findstr "Processing\\|Hands detected\\|Vision error"
```

**Messages attendus:**

```
I/flutter: 📷 Processing image: 640x480
I/flutter: ✋ Hands detected: 2
I/flutter: 🎯 First hand landmarks: 21
```

---

### Problème 3: TFLite Inference ne fonctionne pas

**Ajouter logs dans `_runInferenceLetters`:**

```dart
void _runInferenceLetters(List<double> features) {
  if (_interpreterLetters == null) {
    print("❌ Interpreter is null!"); // LOG
    return;
  }
  
  print("🔢 Input features length: ${features.length}"); // LOG
  print("🔢 First 10 features: ${features.take(10).toList()}"); // LOG
  
  var input = [features];
  var output = List.filled(1, List.filled(_labelsLetters.length, 0.0));
  
  try {
    _interpreterLetters!.run(input, output);
    print("✅ Inference completed"); // LOG
  } catch (e) {
    print("❌ Inference error: $e"); // LOG
    return;
  }

  int maxIdx = 0;
  double maxProb = -1.0;
  for (int i = 0; i < output[0].length; i++) {
    if (output[0][i] > maxProb) {
      maxProb = output[0][i];
      maxIdx = i;
    }
  }

  print("🎯 Best prediction: ${_labelsLetters[maxIdx]} (${(maxProb * 100).toFixed(2)}%)"); // LOG
  
  if (maxProb > 0.60) {
    String label = _labelsLetters[maxIdx];
    if (detectedText != label) {
      _onGestureDetected(label);
    }
  } else {
    print("⚠️ Confidence too low: ${(maxProb * 100).toFixed(2)}%"); // LOG
  }
}
```

**Voir les logs:**

```bash
adb logcat | findstr "Interpreter\\|features\\|Inference\\|prediction\\|Confidence"
```

---

### Problème 4: Modèle TFLite non chargé

**Vérifier les assets:**

```bash
# Lister les fichiers dans l'APK
adb shell run-as com.example.flutter_app ls -la app_flutter/flutter_assets/

# Ou depuis Windows
flutter build apk
# Extraire et vérifier manuellement
```

**Ajouter logs dans `_loadModels`:**

```dart
Future<void> _loadModels() async {
  try {
    print("📦 Loading model_letters.tflite..."); // LOG
    _interpreterLetters = await Interpreter.fromAsset('model_letters.tflite');
    print("✅ model_letters loaded"); // LOG
    
    print("📦 Loading model_words.tflite..."); // LOG
    _interpreterWords = await Interpreter.fromAsset('model_words.tflite');
    print("✅ model_words loaded"); // LOG

    String labelsLettersRaw = await rootBundle.loadString('assets/model_letters_labels.txt');
    _labelsLetters = labelsLettersRaw.split('\n').where((s) => s.isNotEmpty).toList();
    print("✅ Loaded ${_labelsLetters.length} letter labels"); // LOG
    
    String labelsWordsRaw = await rootBundle.loadString('assets/model_words_labels.txt');
    _labelsWords = labelsWordsRaw.split('\n').where((s) => s.isNotEmpty).toList();
    print("✅ Loaded ${_labelsWords.length} word labels"); // LOG
    
  } catch (e) {
    print("❌ Error loading models: $e"); // LOG
  }
}
```

---

## 🔍 Checklist de Débogage Complète

### 1. Vérifier Permissions

```bash
adb shell dumpsys package com.example.flutter_app | findstr "CAMERA\\|granted"
```

### 2. Vérifier Caméra Disponible

```bash
adb shell dumpsys camera
```

### 3. Monitorer Performance

```bash
# CPU/Mémoire usage
adb shell top | findstr flutter_app

# Température
adb shell dumpsys battery
```

### 4. Capturer Screenshot

```bash
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png
```

### 5. Enregistrer Vidéo

```bash
adb shell screenrecord /sdcard/demo.mp4
# Arrêter avec Ctrl+C après quelques secondes
adb pull /sdcard/demo.mp4
```

---

## 🧪 Script de Test Complet

Créer `debug_detection.bat`:

```batch
@echo off
echo ====================================
echo Flutter Gesture Detection Debugger
echo ====================================
echo.

echo [1] Checking device connection...
adb devices
echo.

echo [2] Clearing old logs...
adb logcat -c
echo.

echo [3] Starting Flutter app...
start "Flutter Run" cmd /k "cd /d c:\Users\dawse\Desktop\pfa\flutter_app && flutter run --verbose"
echo.

echo [4] Monitoring logs (Press Ctrl+C to stop)...
timeout /t 5
adb logcat | findstr "flutter\\|Camera\\|Vision\\|TFLite\\|Inference\\|Hands detected"
```

**Utilisation:**

```bash
cd c:\Users\dawse\Desktop\pfa
debug_detection.bat
```

---

## 📊 Analyser les Logs

### Scénario Normal (Tout fonctionne)

```
I/flutter: ✅ Models and Labels loaded.
I/flutter: 📷 Processing image: 640x480
I/flutter: ✋ Hands detected: 1
I/flutter: 🎯 First hand landmarks: 21
I/flutter: 🔢 Input features length: 84
I/flutter: ✅ Inference completed
I/flutter: 🎯 Best prediction: A (85.32%)
```

### Scénario 1: Caméra bloquée

```
E/CameraDevice: Camera error: Camera is in use
E/flutter: ❌ Camera initialization failed
```

**Solution:** Redémarrer le téléphone ou fermer autres apps caméra

### Scénario 2: Pas de mains détectées

```
I/flutter: 📷 Processing image: 640x480
I/flutter: ✋ Hands detected: 0
```

**Solution:** Améliorer l'éclairage, rapprocher main de la caméra

### Scénario 3: Landmarks incorrects

```
I/flutter: ✋ Hands detected: 1
I/flutter: 🎯 First hand landmarks: 0  ❌
```

**Solution:** Problème avec hand_landmarker plugin, vérifier version

### Scénario 4: Confidence faible

```
I/flutter: 🎯 Best prediction: A (45.32%)
I/flutter: ⚠️ Confidence too low: 45.32%
```

**Solution:**

- Améliorer éclairage
- Geste plus net
- Réentraîner le modèle
- Baisser le seuil (0.60 → 0.50)

---

## 🚀 Commandes Rapides

```bash
# Combo pour debug complet
adb logcat -c && adb logcat -v time | findstr "flutter\\|ERROR\\|FATAL"

# Installer APK manuellement
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk

# Nettoyer et rebuild
flutter clean && flutter pub get && flutter run

# Voir crashs système
adb logcat *:E

# Forcer arrêt de l'app
adb shell am force-stop com.example.flutter_app
```

---

## 💡 Tips Avancés

### 1. Remote Debugging Chrome DevTools

```bash
flutter run
# Ouvrir l'URL affichée dans Chrome
# Utiliser DevTools pour profiling
```

### 2. Hot Reload pendant le debug

- Modifier le code
- Appuyer sur `r` dans le terminal Flutter
- Voir les changements instantanément

### 3. Extraire les logs vers fichier

```bash
adb logcat -d > "c:\Users\dawse\Desktop\logs_$(date +%Y%m%d_%H%M%S).txt"
```

### 4. Monitorer en continu

```bash
# PowerShell
while($true) { adb logcat -v time | Select-String "flutter"; Start-Sleep -Seconds 1; Clear-Host }
```

---

## 📋 Résumé

1. **Installer ADB** et activer débogage USB
2. **Ajouter des `print()` partout** dans votre code
3. **Lancer**: `adb logcat | findstr flutter`
4. **Tester** l'app et observer les logs en temps réel
5. **Identifier** où ça bloque (caméra, détection, inference, etc.)
6. **Corriger** et hot reload avec `r`

Bonne chance! 🎯
