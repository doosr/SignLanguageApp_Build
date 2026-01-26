# 📱 Instructions - Créer APK Corrigé

## ✅ Le Bug a Été Corrigé

**Fichier:** `main.py` ligne 114  
**Problème:** `self.info_layout` n'existait pas → crash au démarrage  
**Solution:** Ligne commentée/supprimée

## 🚀 Recompiler l'APK (Méthode Automatique)

### Étape 1: Ouvrir WSL Ubuntu

```bash
# Dans WSL
cd ~
```

### Étape 2: Lancer le script de recompilation

```bash
# Copier le script
cp /mnt/c/Users/dawse/Desktop/pfa/rebuild_apk_fixed.sh ~/

# Lancer
bash ~/rebuild_apk_fixed.sh
```

**⏱️ Durée:** 2-5 minutes (les dépendances sont déjà compilées)

### Étape 3: Récupérer l'APK

L'APK sera automatiquement copié sur votre Desktop Windows:

```
C:\Users\dawse\Desktop\SignLanguageApp-fixed-YYYYMMDD-HHMMSS.apk
```

## 🔧 Recompiler Manuellement (Alternative)

Si le script automatique ne fonctionne pas:

```bash
# 1. Activer l'environnement virtuel
source ~/buildozer-env/bin/activate

# 2. Aller dans le dossier
cd ~/pfa_build

# 3. Copier les fichiers corrigés
cp -r /mnt/c/Users/dawse/Desktop/pfa/* ~/pfa_build/

# 4. Variables d'environnement
export GRADLE_OPTS="-Xmx4096m"
export _JAVA_OPTIONS="-Xmx4096m"

# 5. Compiler
buildozer -v android debug

# 6. Copier l'APK
cp bin/*.apk /mnt/c/Users/dawse/Desktop/SignLanguageApp-fixed.apk
```

## 📱 Installer sur Android

### 1. Désinstaller l'ancienne version

Sur votre téléphone:

- Paramètres → Applications
- Chercher "SignLanguageApp"
- Désinstaller

### 2. Transférer le nouvel APK

- Via câble USB
- Ou via email/cloud

### 3. Installer

- Ouvrir le fichier APK
- Autoriser "Installation depuis sources inconnues" si demandé
- Installer

### 4. Tester

L'application devrait maintenant:

- ✅ Démarrer sans crash
- ✅ Afficher l'interface complète
- ✅ Demander les permissions caméra/micro

## ❓ Si Problèmes Persistent

### Obtenir les logs Android (avec ADB)

```bash
# Connecter téléphone en USB
# Activer "Débogage USB" sur le téléphone

# Capturer les logs
adb logcat | grep -i "python\|error\|signlanguage"
```

### Logs attendus (si tout va bien)

```
[INFO] Chargement du modèle...
[OK] Modèle chargé avec succès
[INFO] Initialisation MediaPipe...
[OK] MediaPipe initialisé
[INFO] Initialisation de la caméra...
[OK] Caméra initialisée avec succès
[OK] Initialisation terminée
```

## 🎯 Résumé Rapide

```bash
# Commande unique pour tout faire:
cd ~ && cp /mnt/c/Users/dawse/Desktop/pfa/rebuild_apk_fixed.sh ~/ && bash ~/rebuild_apk_fixed.sh
```

Ensuite:

1. Prenez l'APK sur votre Desktop Windows
2. Transférez sur Android
3. Installez et testez! 🎉
