"""
Script pour convertir TOUS les diagrammes Mermaid en images PNG
"""

import requests
import base64
import os

# Liste COMPLÈTE des fichiers de diagrammes
diagram_files = [
    'diagram_use_case.md',
    'diagram_use_case_complete.md',
    'diagram_class.md',
    'diagram_architecture.md', 
    'diagram_flux_reconnaissance.md',
    'diagram_flux_inverse.md',
    'diagram_layers.md'
]

def extract_mermaid_code(md_file):
    """Extrait le code Mermaid d'un fichier markdown"""
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Trouver le code entre ```mermaid et ```
    start = content.find('```mermaid')
    if start == -1:
        return None
    
    start = content.find('\n', start) + 1
    end = content.find('```', start)
    
    if end == -1:
        return None
    
    return content[start:end].strip()

def convert_to_image(mermaid_code, output_file):
    """Convertit le code Mermaid en image PNG via mermaid.ink"""
    
    # Encoder en base64
    graphbytes = mermaid_code.encode("utf8")
    base64_bytes = base64.b64encode(graphbytes)
    base64_string = base64_bytes.decode("ascii")
    
    # URL de l'API Mermaid Ink
    url = f"https://mermaid.ink/img/{base64_string}"
    
    print(f"⏳ Téléchargement de {output_file}...")
    
    try:
        # Télécharger l'image
        response = requests.get(url, timeout=30)
        
        if response.status_code == 200:
            with open(output_file, 'wb') as f:
                f.write(response.content)
            print(f"✅ {output_file} créé ({len(response.content) // 1024} KB)")
            return True
        else:
            print(f"❌ Erreur {response.status_code} pour {output_file}")
            return False
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return False

# Traiter chaque fichier
print("🎨 Conversion COMPLÈTE des diagrammes Mermaid en images PNG\n")
print(f"{'='*60}")

success_count = 0
for md_file in diagram_files:
    if not os.path.exists(md_file):
        print(f"⚠️ Fichier {md_file} introuvable")
        continue
    
    print(f"\n📄 Traitement de {md_file}...")
    
    # Extraire le code Mermaid
    mermaid_code = extract_mermaid_code(md_file)
    
    if mermaid_code is None:
        print(f"❌ Aucun code Mermaid trouvé dans {md_file}")
        continue
    
    # Nom du fichier de sortie
    output_file = md_file.replace('.md', '.png')
    
    # Convertir en image
    if convert_to_image(mermaid_code, output_file):
        success_count += 1

print(f"\n{'='*60}")
print(f"✅ Conversion terminée: {success_count}/{len(diagram_files)} diagrammes créés\n")

print(f"📊 Images générées:")
for md_file in diagram_files:
    png_file = md_file.replace('.md', '.png')
    if os.path.exists(png_file):
        size_kb = os.path.getsize(png_file) // 1024
        print(f"   ✓ {png_file} ({size_kb} KB)")
    else:
        print(f"   ✗ {png_file} (échec)")
