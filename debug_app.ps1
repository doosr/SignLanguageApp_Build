# Script de debug automatique pour Sign Language App
# Utilisation: .\debug_app.ps1

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "🔍 DEBUG SIGN LANGUAGE APP" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

# 1. Vérifier connexion ADB
Write-Host "[1/5] Vérification connexion ADB..." -ForegroundColor Yellow
$devices = adb devices | Select-String "device$"
if ($devices) {
    Write-Host "✓ Téléphone connecté" -ForegroundColor Green
}
else {
    Write-Host "✗ Aucun téléphone détecté!" -ForegroundColor Red
    Write-Host "  Vérifiez:" -ForegroundColor Yellow
    Write-Host "  - Câble USB branché" -ForegroundColor Yellow
    Write-Host "  - Débogage USB activé" -ForegroundColor Yellow
    Write-Host "  - Autorisation accordée sur téléphone" -ForegroundColor Yellow
    exit 1
}

# 2. Désinstaller ancienne version
Write-Host "`n[2/5] Désinstallation ancienne version..." -ForegroundColor Yellow
adb uninstall org.test.signlanguageapp 2>$null | Out-Null
Write-Host "✓ Nettoyage effectué" -ForegroundColor Green

# 3. Installer nouveau APK
Write-Host "`n[3/5] Installation APK..." -ForegroundColor Yellow
$apk = Get-ChildItem "SignLanguageApp*.apk" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($apk) {
    Write-Host "  Fichier: $($apk.Name)" -ForegroundColor Cyan
    $result = adb install -r $apk.FullName 2>&1
    if ($result -match "Success") {
        Write-Host "✓ APK installé avec succès" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Échec installation" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "✗ Aucun APK SignLanguageApp*.apk trouvé" -ForegroundColor Red
    exit 1
}

# 4. Nettoyer logs
Write-Host "`n[4/5] Nettoyage des anciens logs..." -ForegroundColor Yellow
adb logcat -c
Write-Host "✓ Logs nettoyés" -ForegroundColor Green

# 5. Capturer logs
Write-Host "`n[5/5] Début capture des logs..." -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "📱 LANCEZ L'APPLICATION MAINTENANT!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 Filtres actifs:" -ForegroundColor Cyan
Write-Host "  - Erreurs Python" -ForegroundColor White
Write-Host "  - Exceptions" -ForegroundColor White
Write-Host "  - Kivy errors" -ForegroundColor White
Write-Host ""
Write-Host "Appuyez sur Ctrl+C pour arrêter`n" -ForegroundColor Yellow

# Capturer et filtrer les logs
adb logcat | Select-String -Pattern "python|kivy|error|exception|fatal" -CaseSensitive:$false
