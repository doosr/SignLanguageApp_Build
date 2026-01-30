# Guide: Build iOS App for iPhone

## 📱 Options pour Distribuer sur iOS

### Option 1: Build Non-Signé (Pour Développement)

✅ **Gratuit** - Pas besoin de compte Apple Developer
❌ **Limitation** - Ne peut être installé que sur simulateur ou via Xcode

- Le workflow GitHub Actions crée automatiquement un IPA non-signé
- Téléchargez l'artifact depuis GitHub Actions

### Option 2: Build Signé (Pour Distribution)

✅ **Installation sur iPhone physique**
✅ **Distribution TestFlight**
✅ **Publication sur App Store**
❌ **Coût** - Nécessite Apple Developer Program ($99/an)

---

## 🔧 Configuration pour Build Signé

### Étape 1: Inscription Apple Developer

1. Créez un compte sur [developer.apple.com](https://developer.apple.com)
2. Payez $99/an pour le Developer Program
3. Créez un App ID: `com.example.signLanguageApp`

### Étape 2: Créer les Certificats

1. **Xcode** → Preferences → Accounts → Add Apple ID
2. **Manage Certificates** → Create "Apple Distribution"
3. Exporter le certificat au format `.p12`

### Étape 3: Créer Provisioning Profile

1. Sur [developer.apple.com](https://developer.apple.com/account)
2. **Certificates, IDs & Profiles** → **Profiles**
3. Créez un "App Store Distribution" profile
4. Téléchargez le `.mobileprovision`

### Étape 4: Configurer GitHub Secrets

Dans votre repo GitHub → **Settings** → **Secrets and variables** → **Actions**

Ajoutez ces secrets:

```
IOS_BUILD_CERTIFICATE_BASE64  # Certificat .p12 encodé en base64
IOS_P12_PASSWORD              # Mot de passe du certificat
APPSTORE_ISSUER_ID            # App Store Connect API Issuer ID
APPSTORE_KEY_ID               # App Store Connect API Key ID
APPSTORE_PRIVATE_KEY          # App Store Connect API Private Key
```

**Pour encoder le certificat en base64:**

```bash
base64 -i Certificates.p12 | pbcopy  # macOS
certutil -encode Certificates.p12 cert.txt  # Windows
```

### Étape 5: Activer le Build Signé

Dans `.github/workflows/ios-build.yml`, décommentez les sections:

- Import Code-Signing Certificates
- Install Provisioning Profile
- Build IPA (commentez le build no-codesign)
- Upload to TestFlight

---

## 📥 Télécharger l'IPA

### Via GitHub Actions (Non-Signé)

1. **GitHub** → **Actions** → **Build iOS IPA**
2. Téléchargez l'artifact `SignLanguageApp-iOS-Unsigned`
3. Installez via Xcode ou simulateur

### Via TestFlight (Signé)

Une fois le build signé configuré:

1. Le workflow upload automatiquement sur TestFlight
2. Invitez des testeurs via App Store Connect
3. Les testeurs installent via l'app TestFlight

### Publication App Store

1. Créez une app sur [App Store Connect](https://appstoreconnect.apple.com)
2. Configurez les métadonnées, screenshots, description
3. Soumettez pour review
4. Une fois approuvé, l'app est publique sur l'App Store

---

## 🎨 L'Application iOS

L'app iOS aura le même design moderne que Android et Windows:

- ✨ Écran d'accueil avec 4 cartes gradient
- 🎥 Mode reconnaissance avec landmarks cyan
- 🎤 Mode inverse avec ondes sonores animées
- 🌍 Support multilingue (Français, Anglais, Arabe)
- 📱 Interface optimisée pour iPhone

---

## ⚠️ Notes Importantes

1. **Caméra**: Assurez-vous d'ajouter ces permissions dans `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Cette app a besoin de la caméra pour détecter les signes</string>
<key>NSMicrophoneUsageDescription</key>
<string>Cette app a besoin du micro pour le mode inverse</string>
```

1. **Bundle ID**: Changez `com.example.signLanguageApp` par votre propre ID unique

2. **Version**: Incrémentez la version dans `pubspec.yaml` avant chaque release

---

## 🚀 Build Local (avec Mac)

Si vous avez un Mac:

```bash
cd flutter_app
flutter build ios --release
# ou pour créer un IPA
flutter build ipa --release
```

L'IPA sera dans `build/ios/ipa/`
