# Script de diagnostic pour l'application Windows
Write-Host "=== Diagnostic de l'Application SignLanguage ===" -ForegroundColor Cyan
Write-Host ""

# Chercher l'exe
$exePath = Get-ChildItem "C:\Users\dawse\Desktop" -Filter "sign_language_app.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $exePath) {
    Write-Host "Erreur: sign_language_app.exe introuvable sur le Bureau" -ForegroundColor Red
    Write-Host "Avez-vous bien extrait le ZIP ?" -ForegroundColor Yellow
    exit 1
}

Write-Host "Exe trouvé: $($exePath.FullName)" -ForegroundColor Green
$appDir = Split-Path $exePath.FullName

Write-Host ""
Write-Host "Vérification des fichiers requis..." -ForegroundColor Yellow

# Vérifier les fichiers requis
$requiredFiles = @(
    "flutter_windows.dll",
    "data"
)

$missing = @()
foreach ($file in $requiredFiles) {
    $path = Join-Path $appDir $file
    if (Test-Path $path) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ $file MANQUANT" -ForegroundColor Red
        $missing += $file
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "PROBLÈME: Fichiers manquants!" -ForegroundColor Red
    Write-Host "L'application a besoin de TOUS les fichiers du ZIP." -ForegroundColor Yellow
    Write-Host "Assurez-vous d'avoir extrait TOUT le contenu du ZIP." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Tentative de lancement de l'application..." -ForegroundColor Yellow
Write-Host "Si une erreur apparaît, notez-la pour le diagnostic." -ForegroundColor Gray
Write-Host ""

# Lancer l'application et capturer les erreurs
try {
    Set-Location $appDir
    Start-Process -FilePath $exePath.FullName -Wait -NoNewWindow
}
catch {
    Write-Host ""
    Write-Host "Erreur lors du lancement: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Appuyez sur une touche pour fermer..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
