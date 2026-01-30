# Guide d'Installation - Package MSIX Windows

## 📦 C'est Quoi MSIX ?

MSIX est le format d'installation moderne de Windows (comme .exe mais en mieux) :

- ✅ Installation en un clic
- ✅ Icône dans le menu Démarrer
- ✅ Désinstallation propre
- ✅ Mises à jour automatiques
- ✅ Sécurisé et certifié

## ⚠️ Pourquoi Ça Ne Marche Pas Localement ?

L'erreur que vous avez vue :

```
Unable to find suitable Visual Studio toolchain
```

**Cause** : Pour créer un MSIX localement, il faut :

- Visual Studio 2022 (10+ GB)
- Workload "Desktop development with C++"
- Windows 10 SDK

**Solution Simple** : Utilisez GitHub Actions ! ✅

## 🚀 Créer le MSIX avec GitHub Actions

### Méthode Automatique (Recommandé)

1. **Pushez votre code** (déjà fait !)
2. **GitHub Actions crée le MSIX** automatiquement
3. **Téléchargez-le** depuis GitHub

### Accéder au MSIX

#### Option A : Artifacts (Chaque Push)

1. Allez sur GitHub → **Actions**
2. Cliquez sur le workflow **"Build Windows MSIX Installer"**
3. Scrollez vers **"Artifacts"**
4. Téléchargez **SignLanguageApp-MSIX-Installer.msix**

#### Option B : Release (Tags Git)

1. Créez un tag : `git tag v1.0.0`
2. Poussez le tag : `git push origin v1.0.0`
3. GitHub Actions crée automatiquement une **Release**
4. Le MSIX est attaché à la release

## 📥 Installation du MSIX

### Pour les Utilisateurs Windows

1. **Téléchargez** le fichier `.msix`
2. **Double-cliquez** dessus
3. Windows demande la confirmation
4. Cliquez **"Installer"**
5. L'application apparaît dans le menu Démarrer

### ⚠️ Certificat Non Vérifié

Au premier lancement, Windows affichera un avertissement car le MSIX n'est pas signé par un certificat de confiance.

**Pour utiliser quand même** :

1. Clic droit sur le `.msix`
2. **Propriétés**
3. **Débloquer** (si présent)
4. **Installer** l'application
5. Windows demandera d'autoriser l'installation depuis une source inconnue

**Pour signer le MSIX** (optionnel, avancé) :

- Il faut un certificat de signature de code ($200-500/an)
- Ou publier sur le Microsoft Store (gratuit mais long)

## 🔧 Build Local (Si Vous Voulez Quand Même)

### Installer Visual Studio

1. **Téléchargez** [Visual Studio 2022 Community](https://visualstudio.microsoft.com/)
2. Pendant l'installation, sélectionnez :
   - ✅ **Desktop development with C++**
   - ✅ **Windows 10 SDK** (dernière version)
3. **Installez** (~10 GB)
4. **Redémarrez** votre PC

### Créer le MSIX

Après avoir installé Visual Studio :

```bash
cd flutter_app
flutter pub get
dart run msix:create
```

Le fichier `.msix` sera dans :

```
flutter_app/build/windows/x64/runner/Release/sign_language_app.msix
```

## 📊 Comparaison des Méthodes

| Méthode | Avantages | Inconvénients |
|---------|-----------|---------------|
| **GitHub Actions** | ✅ Aucune dépendance locale<br>✅ Toujours à jour<br>✅ Gratuit | ❌ Attendre 5-10 min |
| **Build Local** | ✅ Instantané | ❌ Nécessite Visual Studio (10GB)<br>❌ Configuration complexe |

## 🎯 Recommandation

**Utilisez GitHub Actions** pour créer le MSIX :

1. Aucune installation lourde
2. Build reproductible
3. Disponible pour tout le monde
4. Distribution facile

**Build local** seulement si :

- Vous développez beaucoup sur Windows
- Vous avez déjà Visual Studio installé
- Vous testez fréquemment le MSIX

## 🚀 Distribuer l'Application

### Via GitHub Release (Recommandé)

```bash
# Créer une version
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions créera automatiquement :
# - Une Release GitHub
# - Le MSIX attaché à la release
```

Les utilisateurs peuvent alors télécharger depuis :
`https://github.com/doosr/SignLanguageApp_Build/releases`

### Via Site Web

1. Téléchargez le MSIX depuis GitHub Actions
2. Hébergez-le sur votre site
3. Créez un lien de téléchargement :

```html
<a href="SignLanguageApp.msix" download>
  📦 Télécharger l'Installateur Windows (MSIX)
</a>
```

## 📝 Notes Importantes

### Permissions

Le MSIX configuré demande automatiquement :

- 📷 **Webcam** - pour la reconnaissance des signes
- 🎤 **Microphone** - pour le mode inverse

### Langues Supportées

L'installateur supporte :

- 🇫🇷 Français
- 🇬🇧 English
- 🇸🇦 العربية (Arabe)

### Version

La version actuelle est **1.0.0**

Pour incrémenter :

1. Modifiez `version` dans `pubspec.yaml`
2. Modifiez `msix_version` dans `msix_config`
3. Créez un nouveau tag git

## 🐛 Dépannage

### "Cette application n'a pas pu démarrer"

Vérifiez que le MSIX a bien été construit pour votre architecture (x64).

### "Installateur non vérifié"

Normal ! Le MSIX n'est pas signé. Voir section "Certificat Non Vérifié".

### "Erreur lors de l'installation"

Assurez-vous d'avoir Windows 10 (version 1809) ou plus récent.

## ✅ Résumé

1. ✅ **MSIX configuré** dans `pubspec.yaml`
2. ✅ **GitHub Actions** crée le MSIX automatiquement
3. ✅ **Téléchargez** depuis Artifacts ou Releases
4. ✅ **Installez** en double-cliquant
5. ✅ **Lancez** depuis le menu Démarrer

**Pas besoin de Visual Studio** si vous utilisez GitHub Actions ! 🎉
