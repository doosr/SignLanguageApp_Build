# 📦 Installation

## Android

### Prérequis

- Android 5.0 (API 21) ou supérieur
- 50 MB d'espace libre
- Caméra et microphone

### Étapes d'installation

1. **Télécharger l'APK**
   - Allez sur [GitHub Actions](https://github.com/doosr/SignLanguageApp_Build/actions)
   - Cliquez sur le dernier workflow "Android APK Build" ✅
   - Téléchargez l'artifact "SignLanguageApp-Android-APK"

2. **Installer l'APK**
   - Transférez l'APK sur votre téléphone
   - Ouvrez le fichier APK
   - Autorisez "Sources inconnues" si demandé
   - Cliquez sur "Installer"

3. **Permissions**
   - Au premier lancement, autorisez :
     - 📷 Caméra
     - 🎤 Microphone

## Windows

### Option 1 : Version portable (Recommandé)

1. **Télécharger**
   - Allez sur [GitHub Actions](https://github.com/doosr/SignLanguageApp_Build/actions)
   - Téléchargez "Windows-Portable"

2. **Installer**
   - Extrayez le ZIP
   - Lancez `sign_language_app.exe`
   - ✅ Aucune installation requise !

### Option 2 : Package MSIX

#### Prérequis

- Windows 10/11
- Mode Développeur activé OU certificat installé

#### Installation du certificat

```powershell
# PowerShell en Administrateur
$pfxPath = "chemin\vers\SignLanguageApp.pfx"
$password = ConvertTo-SecureString -String "GitHubActions123!" -Force -AsPlainText

Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\LocalMachine\Root -Password $password
Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\LocalMachine\TrustedPeople -Password $password
```

#### Installer le MSIX

1. Double-cliquez sur le fichier `.msix`
2. Cliquez sur "Installer"
3. Lancez l'application depuis le menu Démarrer

## ESP32-CAM (Optionnel)

### Matériel requis

- Module ESP32-CAM
- Programmateur FTDI USB-TTL
- Câbles Dupont
- Breadboard

### Installation firmware

1. **Télécharger le firmware**
   - Disponible dans `esp32_cam_platformio/`

2. **Flasher l'ESP32-CAM**

   ```bash
   cd esp32_cam_platformio
   pio run --target upload
   ```

3. **Configuration WiFi**
   - Modifier `include/config.h`
   - Définir SSID et mot de passe WiFi

4. **Connexion dans l'app**
   - Ouvrir l'application
   - Aller dans Paramètres ESP32-CAM
   - Entrer l'adresse IP de l'ESP32
   - Tester la connexion

## Vérification

### Android

- ✅ L'application se lance
- ✅ La caméra s'affiche en mode reconnaissance
- ✅ La synthèse vocale fonctionne

### Windows

- ✅ La fenêtre s'affiche au lancement
- ✅ Pas d'erreur de certificat
- ✅ L'application répond correctement

## Dépannage

### "Caméra non disponible" (Android)

- Vérifiez les permissions dans Paramètres → Applications → SignLanguage
- Redémarrez l'application

### Fenêtre invisible (Windows)

- Assurez-vous d'avoir la dernière version
- Vérifiez que le processus ne tourne pas en arrière-plan (Gestionnaire des tâches)

### Erreur certificat MSIX

- Activez le Mode Développeur : Paramètres → Pour les développeurs
- OU installez le certificat (voir ci-dessus)

## Support

Pour toute question, ouvrez une [issue sur GitHub](https://github.com/doosr/SignLanguageApp_Build/issues).
