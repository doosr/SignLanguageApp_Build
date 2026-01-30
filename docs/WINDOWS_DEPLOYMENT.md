# Guide de Déploiement Windows - IMPORTANT

## ⚠️ Pourquoi l'EXE ne démarre pas ?

### Problème

L'application Flutter Windows **NE PEUT PAS** fonctionner avec juste le fichier `.exe`. Elle nécessite **TOUS les fichiers** du dossier Release.

### Structure Requise

Quand vous buildez une app Flutter Windows, elle crée ce dossier :

```
flutter_app/build/windows/x64/runner/Release/
├── sign_language_app.exe          ← L'exécutable principal
├── flutter_windows.dll             ← DLL Flutter (REQUIS)
├── flutter_windows.dll.lib
├── data/                           ← Dossier assets (REQUIS)
│   ├── flutter_assets/
│   │   ├── assets/                 ← Vos images, modèles ML
│   │   ├── fonts/
│   │   └── packages/
│   └── icudtl.dat                  ← Données Unicode (REQUIS)
└── autres DLLs des plugins
```

### ✅ Solution : Distribuer le Dossier Complet

**Option 1 : ZIP Complet (Recommandé)**

```bash
# Le workflow GitHub crée déjà un ZIP avec TOUS les fichiers
# Téléchargez SignLanguageApp-Windows.zip
# Décompressez-le
# Lancez sign_language_app.exe depuis le dossier décompressé
```

**Option 2 : Installateur MSIX (Professionnel)**
Créer un package MSIX qui installe proprement l'app :

```yaml
# Ajouter à pubspec.yaml
msix_config:
  display_name: SignLanguage App
  publisher_display_name: Your Name
  identity_name: com.yourcompany.signlanguage
  logo_path: assets/icon.png
```

Puis builder :

```bash
flutter pub run msix:create
```

## 📦 Distribution Correcte

### Pour les Utilisateurs Finaux

**Méthode 1 : GitHub Release**

1. Créez un tag git : `git tag v1.0.0`
2. Poussez le tag : `git push origin v1.0.0`
3. Le workflow créera automatiquement une Release avec le ZIP
4. Les utilisateurs téléchargent le ZIP, décompressent et lancent

**Méthode 2 : Site Web**

1. Hébergez le ZIP complet sur votre site
2. Fournissez des instructions claires :

```text
1. Téléchargez SignLanguageApp-Windows.zip
2. Décompressez dans un dossier
3. Double-cliquez sur sign_language_app.exe
```

**Méthode 3 : Installateur (Avancé)**
Utilisez MSIX ou Inno Setup pour créer un vrai installateur

## 🔧 Fix Immédiat

Si vous avez déjà partagé juste le .exe :

1. **Récupérez le ZIP complet** depuis GitHub Actions artifact
2. **Envoyez-le** à vos utilisateurs
3. **Instructions** :
   - Télécharger le ZIP
   - Créer un dossier "SignLanguage App" sur le bureau
   - Extraire TOUT le contenu du ZIP dans ce dossier
   - Lancer sign_language_app.exe depuis ce dossier

## 📝 Note pour le Site Web

Mettez à jour vos instructions de téléchargement :

```html
<div class="download-instructions">
  <h3>📥 Installation Windows</h3>
  <ol>
    <li>Téléchargez <strong>SignLanguageApp-Windows.zip</strong></li>
    <li>Créez un dossier sur votre Bureau</li>
    <li>Décompressez <strong>TOUT le contenu</strong> du ZIP</li>
    <li>Double-cliquez sur <code>sign_language_app.exe</code></li>
  </ol>
  <p><em>⚠️ Ne lancez pas juste le .exe sans les autres fichiers !</em></p>
</div>
```

## 🚀 Solution Professionnelle : MSIX

Pour une vraie app Windows, créez un package MSIX :

```bash
# Installer l'outil MSIX
flutter pub add msix

# Créer le package
flutter pub run msix:create
```

Le MSIX :

- ✅ S'installe comme une vraie app Windows
- ✅ Crée un raccourci dans le menu Démarrer
- ✅ Gère les dépendances automatiquement
- ✅ Se désinstalle proprement
- ✅ Peut être publié sur le Microsoft Store

## 📊 Résumé

| Méthode | Avantages | Inconvénients |
|---------|-----------|---------------|
| ZIP Complet | Simple, fonctionne immédiatement | Utilisateur doit décompresser |
| MSIX Package | Installation propre, professionnel | Plus complexe à créer |
| Portable EXE | ❌ **NE FONCTIONNE PAS** | Manque les DLLs et assets |

**Recommandation** : Utilisez le ZIP complet généré par GitHub Actions pour l'instant, puis passez à MSIX pour une distribution professionnelle.
