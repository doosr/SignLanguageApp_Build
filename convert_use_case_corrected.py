"""
Script pour convertir le diagramme de cas d'utilisation corrigé en image PNG
"""

import requests
import base64
import os

def extract_mermaid_code(md_file):
    """Extrait le code Mermaid d'un fichier markdown"""
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
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
    
    graphbytes = mermaid_code.encode("utf8")
    base64_bytes = base64.b64encode(graphbytes)
    base64_string = base64_bytes.decode("ascii")
    
    url = f"https://mermaid.ink/img/{base64_string}"
    
    print(f"⏳ Génération de {output_file}...")
    
    try:
        response = requests.get(url, timeout=30)
        
        if response.status_code == 200:
            with open(output_file, 'wb') as f:
                f.write(response.content)
            size_kb = len(response.content) // 1024
            print(f"✅ {output_file} créé ({size_kb} KB)")
            return True
        else:
            print(f"❌ Erreur {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return False

# Convertir le diagramme corrigé
print("🎨 Conversion du diagramme de cas d'utilisation corrigé\n")

md_file = 'diagram_use_case_corrected.md'

if os.path.exists(md_file):
    mermaid_code = extract_mermaid_code(md_file)
    
    if mermaid_code:
        output_file = 'diagram_use_case_corrected.png'
        if convert_to_image(mermaid_code, output_file):
            print(f"\n✅ Diagramme corrigé créé avec succès!")
            print(f"📊 Fichier: {output_file}")
        else:
            print(f"\n⚠️ Échec de la conversion")
    else:
        print("❌ Aucun code Mermaid trouvé")
else:
    print(f"❌ Fichier {md_file} introuvable")
