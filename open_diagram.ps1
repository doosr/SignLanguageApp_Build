# Script PowerShell pour ouvrir le diagramme dans le navigateur
# L'utilisateur pourra ensuite faire une capture d'écran

$htmlPath = "C:\Users\dawse\Desktop\pfa\Untitled-1.html"

Write-Host "🌐 Ouverture du diagramme dans le navigateur..." -ForegroundColor Cyan
Write-Host ""

# Ouvrir le fichier HTML dans le navigateur par défaut
Start-Process $htmlPath

Write-Host "✅ Diagramme ouvert dans votre navigateur!" -ForegroundColor Green
Write-Host ""
Write-Host "📸 Pour capturer le diagramme en PNG:" -ForegroundColor Yellow
Write-Host "   1. Attendez que le diagramme soit complètement chargé" -ForegroundColor White
Write-Host "   2. Appuyez sur Win + Shift + S (Outil Capture d'écran Windows)" -ForegroundColor White
Write-Host "   3. Sélectionnez la zone du diagramme" -ForegroundColor White
Write-Host "   4. La capture sera copiée dans le presse-papiers" -ForegroundColor White
Write-Host "   5. Ouvrez Paint et collez (Ctrl+V)" -ForegroundColor White
Write-Host "   6. Enregistrez sous 'diagram_use_case_final.png'" -ForegroundColor White
Write-Host ""
Write-Host "💡 Alternative: Clic droit sur la page → 'Imprimer' → 'Enregistrer en PDF'" -ForegroundColor Cyan
