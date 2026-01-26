# Script PowerShell : Installation automatique WSL + Buildozer
# Exécuter en tant qu'Administrateur

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Installation WSL pour compilation APK" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Étape 1 : Installer WSL
Write-Host "[1/5] Installation de WSL2..." -ForegroundColor Yellow
wsl --install -d Ubuntu
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur lors de l'installation de WSL. Vérifiez que vous êtes administrateur." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "WSL2 installé avec succès!" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: Votre PC doit redémarrer pour terminer l'installation." -ForegroundColor Yellow
Write-Host "Après le redémarrage:" -ForegroundColor Yellow
Write-Host "  1. Ubuntu se lancera automatiquement" -ForegroundColor White
Write-Host "  2. Créez un nom d'utilisateur et mot de passe" -ForegroundColor White
Write-Host "  3. Exécutez le script 02_setup_buildozer.sh" -ForegroundColor White
Write-Host ""

$reboot = Read-Host "Voulez-vous redémarrer maintenant? (O/N)"
if ($reboot -eq "O" -or $reboot -eq "o") {
    Write-Host "Redémarrage dans 10 secondes..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer
} else {
    Write-Host "N'oubliez pas de redémarrer avant de continuer!" -ForegroundColor Red
}
