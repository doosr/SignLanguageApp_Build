# 📱 Guide ADB Logcat - Debug Détection Gestes

## 🔌 Prérequis

1. **Connectez le téléphone** en USB
2. **Activez le mode développeur** sur Android
3. **Activez le débogage USB**

## 📊 Commandes ADB pour Voir les Logs

### 1. Vérifier que le téléphone est connecté

```bash
adb devices
```

Devrait afficher votre appareil.

---

### 2. Voir TOUS les logs (filtré par notre app)

```bash
adb logcat | findstr /C:"flutter" /C:"TFLite" /C:"Models" /C:"LETTERS" /C:"DETECTED"
```

---

### 3. Filtrer UNIQUEMENT nos logs de debug (RECOMMANDÉ)

```bash
adb logcat | findstr /C:"📦" /C:"✅" /C:"❌" /C:"🔍" /C:"⚡"
```

Cela affichera :

- 📦 Initialisation des modèles
- ✅ Modèles chargés
- 🔍 Prédictions d'inférence (toutes les 30 frames)
- ❌ Erreurs
- ⚡ Informations importantes

---

### 4. Logs spécifiques à l'inférence

```bash
adb logcat | findstr "LETTERS: Top"
```

Affiche les prédictions en temps réel.

---

### 5. Effacer les anciens logs et recommencer

```bash
adb logcat -c
adb logcat | findstr /C:"📦" /C:"✅" /C:"❌" /C:"🔍" /C:"LETTERS"
```

---

## 🎯 Ce qu'il faut vérifier

### Au démarrage de l'app

```
📦 Starting model initialization...
⚡ Using cached model: ... (ou First launch: Copying...)
✅ Models ready!
   Letters interpreter: OK
   Words interpreter: OK
   Letters labels: 26 classes
   Words labels: 57 classes
```

### Pendant l'utilisation (avec landmarks visibles)

```
🔍 LETTERS: Top=A Prob=0.85
🔍 LETTERS: Top=B Prob=0.45
🔍 LETTERS: Top=C Prob=0.92
✅ DETECTED LETTER: C (0.92)
```

---

## ❓ Diagnostics

### Problème 1 : Pas de logs d'inférence

**Symptôme** : Aucun message `🔍 LETTERS` n'apparaît

**Cause** : Les modèles ne s'exécutent pas ou interpreter est null

**Solution** : Vérifiez que `Letters interpreter: OK` apparaît

---

### Problème 2 : Probabilités trop faibles

**Symptôme** : `🔍 LETTERS: Top=X Prob=0.12` (toujours < 0.3)

**Cause** :

- Mauvaise normalisation des landmarks
- Modèle incompatible
- Problème de rotation/mirroring

**Solution** : Vérifier la rotation de la caméra et le preprocessing

---

### Problème 3 : Erreurs TFLite

**Symptôme** : `❌ Inference error: ...`

**Cause** : Problème avec le modèle ou les features

**Solution** : Vérifier le format des features (doit être 84 floats)

---

## 💡 Script PowerShell Automatique

Créez un fichier `watch_logs.ps1` :

```powershell
# Clear old logs
adb logcat -c

# Watch logs with colors
Write-Host "📱 Monitoring SignLanguage App Logs..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

adb logcat | Select-String -Pattern "📦|✅|❌|🔍|⚡|Models|LETTERS|DETECTED" | ForEach-Object {
    $line = $_.Line
    
    if ($line -match "❌") {
        Write-Host $line -ForegroundColor Red
    }
    elseif ($line -match "✅") {
        Write-Host $line -ForegroundColor Green
    }
    elseif ($line -match "🔍") {
        Write-Host $line -ForegroundColor Cyan
    }
    elseif ($line -match "DETECTED") {
        Write-Host $line -ForegroundColor Yellow
    }
    else {
        Write-Host $line
    }
}
```

**Usage** :

```bash
.\watch_logs.ps1
```

---

## 🎬 Procédure de Test Complète

1. **Connecter le téléphone**

   ```bash
   adb devices
   ```

2. **Effacer les logs**

   ```bash
   adb logcat -c
   ```

3. **Lancer le monitoring**

   ```bash
   adb logcat | findstr /C:"📦" /C:"✅" /C:"🔍" /C:"LETTERS"
   ```

4. **Ouvrir l'app** sur le téléphone

5. **Vérifier le chargement des modèles**
   - Doit voir : `✅ Models ready!`
   - Doit voir : `Letters interpreter: OK`

6. **Faire un geste** (ex: lettre A)

7. **Vérifier les prédictions**
   - Doit voir : `🔍 LETTERS: Top=A Prob=0.XX`
   - Si Prob > 0.3 et stable : `✅ DETECTED LETTER: A`

---

## 📝 Copier les logs dans un fichier

```bash
adb logcat | findstr /C:"📦" /C:"✅" /C:"🔍" /C:"LETTERS" > logs_detection.txt
```

Puis envoyez-moi le fichier `logs_detection.txt` pour analyser.
