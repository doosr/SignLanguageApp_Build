"""
Script pour capturer le diagramme HTML en PNG
Utilise selenium avec Chrome headless
"""
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
import time
import os

def capture_diagram():
    # Configuration Chrome headless
    chrome_options = Options()
    chrome_options.add_argument('--headless')
    chrome_options.add_argument('--no-sandbox')
    chrome_options.add_argument('--disable-dev-shm-usage')
    chrome_options.add_argument('--window-size=1920,1400')
    
    # Chemin du fichier HTML
    html_path = r'file:///c:/Users/dawse/Desktop/pfa/Untitled-1.html'
    output_path = r'c:\Users\dawse\Desktop\pfa\diagram_use_case_final.png'
    
    try:
        # Initialiser le driver
        driver = webdriver.Chrome(options=chrome_options)
        
        # Charger la page
        driver.get(html_path)
        
        # Attendre que le SVG soit chargé
        time.sleep(2)
        
        # Prendre la capture d'écran
        driver.save_screenshot(output_path)
        
        print(f"✅ Capture réussie : {output_path}")
        print(f"📏 Taille de l'image : {os.path.getsize(output_path)} bytes")
        
        driver.quit()
        return True
        
    except Exception as e:
        print(f"❌ Erreur : {e}")
        print("\n💡 Alternative : Ouvrez Untitled-1.html dans votre navigateur")
        print("   et utilisez l'outil de capture d'écran de Windows (Win + Shift + S)")
        return False

if __name__ == "__main__":
    capture_diagram()
