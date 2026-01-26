"""
Script de préparation du projet pour Google Colab
Crée un fichier ZIP avec tous les fichiers nécessaires pour compiler l'APK
"""

import zipfile
import os
from pathlib import Path

def create_colab_zip():
    print("=" * 60)
    print("📦 Préparation du projet pour Google Colab")
    print("=" * 60)
    
    # Dossier du projet
    project_dir = Path(__file__).parent
    zip_filename = project_dir / "pfa_project.zip"
    
    # Fichiers à inclure
    files_to_include = [
        "main.py",
        "buildozer.spec",
        "model.p",
        "model_sequence.p",
        "translations.json",
        "hand_landmarker.task",
    ]
    
    # Fichiers optionnels (inclus s'ils existent)
    optional_files = [
        "data.pickle",
        "sequence_data.pickle",
    ]
    
    print(f"\n📂 Dossier du projet : {project_dir}")
    print(f"📁 Fichier ZIP : {zip_filename.name}\n")
    
    # Créer le ZIP
    with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # Fichiers obligatoires
        print("✅ Fichiers obligatoires :")
        for filename in files_to_include:
            filepath = project_dir / filename
            if filepath.exists():
                zipf.write(filepath, filename)
                size_mb = filepath.stat().st_size / (1024 * 1024)
                print(f"   ✓ {filename:30s} ({size_mb:6.1f} MB)")
            else:
                print(f"   ⚠️ {filename:30s} [MANQUANT]")
        
        # Fichiers optionnels
        print("\n📦 Fichiers optionnels :")
        for filename in optional_files:
            filepath = project_dir / filename
            if filepath.exists():
                size_mb = filepath.stat().st_size / (1024 * 1024)
                
                # Avertir si fichier très lourd (>50 MB)
                if size_mb > 50:
                    print(f"   ⚠️ {filename:30s} ({size_mb:6.1f} MB) - TRÈS LOURD, considérez l'exclure")
                    response = input(f"      Inclure {filename} ? (o/N) : ").strip().lower()
                    if response == 'o':
                        zipf.write(filepath, filename)
                        print(f"   ✓ Inclus")
                    else:
                        print(f"   ✗ Exclu")
                else:
                    zipf.write(filepath, filename)
                    print(f"   ✓ {filename:30s} ({size_mb:6.1f} MB)")
            else:
                print(f"   - {filename:30s} [Non trouvé, ignoré]")
    
    # Résultat final
    zip_size = zip_filename.stat().st_size / (1024 * 1024)
    print("\n" + "=" * 60)
    print(f"✅ ZIP créé avec succès !")
    print("=" * 60)
    print(f"📁 Fichier : {zip_filename}")
    print(f"💾 Taille : {zip_size:.1f} MB")
    
    if zip_size > 100:
        print("\n⚠️ ATTENTION : Fichier très lourd (>100 MB)")
        print("   Google Colab peut avoir du mal à uploader de gros fichiers.")
        print("   Considérez exclure data.pickle et sequence_data.pickle")
    
    print("\n📋 Prochaines étapes :")
    print("   1. Ouvrir Google Colab : https://colab.research.google.com/")
    print("   2. Uploader le notebook : compile_apk.ipynb")
    print("   3. Exécuter les cellules dans l'ordre")
    print("   4. Uploader pfa_project.zip quand demandé")
    print("   5. Attendre la compilation (~30-40 minutes)")
    print("   6. Télécharger l'APK généré")
    print("=" * 60)

if __name__ == "__main__":
    try:
        create_colab_zip()
    except Exception as e:
        print(f"\n❌ Erreur : {e}")
        import traceback
        traceback.print_exc()
    
    input("\n⏎ Appuyez sur Entrée pour quitter...")
