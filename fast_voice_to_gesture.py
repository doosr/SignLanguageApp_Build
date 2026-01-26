# Mapping direct Son → Image pour reconnaissance ultra-rapide
# Pas besoin de modèle ML, juste un dictionnaire pré-calculé

import os
import json
import glob
import random

class FastVoiceToGesture:
    """Conversion ultra-rapide son → image avec mapping direct"""
    
    def __init__(self, data_folder='Data'):
        self.data_folder = data_folder
        self.gesture_cache = {}
        self.word_mapping = {}
        
        print("[INFO] Initialisation FastVoiceToGesture...")
        self._build_cache()
        self._load_word_mapping()
        print(f"[OK] {len(self.gesture_cache)} gestes cachés")
    
    def _build_cache(self):
        """Pré-charger toutes les images dans un cache"""
        # Pour chaque lettre/mot dans Data/
        for folder in os.listdir(self.data_folder):
            folder_path = os.path.join(self.data_folder, folder)
            
            if os.path.isdir(folder_path):
                # Lister toutes les images
                images = []
                
                # Chercher dans sous-dossiers (pour mots)
                for root, dirs, files in os.walk(folder_path):
                    for file in files:
                        if file.endswith('.jpg'):
                            images.append(os.path.join(root, file))
                
                if images:
                    self.gesture_cache[folder] = images
                    print(f"  ✓ {folder}: {len(images)} images")
    
    def _load_word_mapping(self):
        """Charger mapping mot français → clé geste"""
        # Essayer de charger depuis translations.json
        try:
            with open('translations.json', 'r', encoding='utf-8') as f:
                translations = json.load(f)
            
            # Créer mapping inverse: mot → clé
            for key, data in translations.items():
                if isinstance(data, dict):
                    for lang, word in data.items():
                        if word and lang in ['fr', 'en', 'ar']:
                            # Normaliser le mot
                            normalized = word.lower().strip()
                            self.word_mapping[normalized] = key
            
            print(f"[OK] {len(self.word_mapping)} mots mappés")
            
        except Exception as e:
            print(f"[WARNING] Impossible de charger translations.json: {e}")
    
    def get_gesture_instant(self, word):
        """
        Obtenir instantanément une image de geste
        
        Args:
            word: Mot prononcé (ex: "famille", "bonjour")
        
        Returns:
            Chemin vers l'image (ou None)
        """
        # Normaliser
        word = word.lower().strip()
        
        # 1. Chercher dans le mapping
        gesture_key = self.word_mapping.get(word)
        
        # 2. Si pas trouvé, essayer directement comme clé
        if not gesture_key:
            # Essayer en majuscule pour lettres (A, B, C...)
            if len(word) == 1 and word.isalpha():
                gesture_key = word.upper()
            else:
                # Essayer tel quel
                gesture_key = word.capitalize()
        
        # 3. Récupérer image du cache
        if gesture_key in self.gesture_cache:
            images = self.gesture_cache[gesture_key]
            return random.choice(images)
        
        print(f"[WARNING] Pas de geste pour: {word}")
        return None
    
    def benchmark(self, word='famille', iterations=100):
        """Test de performance"""
        import time
        
        print(f"\n⚡ BENCHMARK: {iterations} requêtes pour '{word}'")
        
        start = time.time()
        for _ in range(iterations):
            img = self.get_gesture_instant(word)
        end = time.time()
        
        total_time = (end - start) * 1000  # ms
        avg_time = total_time / iterations
        
        print(f"  Temps total: {total_time:.2f} ms")
        print(f"  Temps moyen: {avg_time:.4f} ms par requête")
        print(f"  Vitesse: {iterations / (total_time / 1000):.0f} req/sec")
        print(f"  Résultat: {os.path.basename(img) if img else 'Aucun'}")


# TEST
if __name__ == "__main__":
    print("=" * 60)
    print("⚡ TEST FAST VOICE TO GESTURE")
    print("=" * 60)
    print()
    
    # Créer l'instance
    fast = FastVoiceToGesture()
    
    print("\n" + "=" * 60)
    print("🧪 TESTS")
    print("=" * 60)
    
    # Test mots
    test_words = ['famille', 'bonjour', 'transport', 'a', 'merci']
    
    for word in test_words:
        img = fast.get_gesture_instant(word)
        if img:
            print(f"✓ '{word}' → {os.path.basename(img)}")
        else:
            print(f"✗ '{word}' → Pas trouvé")
    
    # Benchmark
    fast.benchmark('famille', 1000)
    
    print("\n" + "=" * 60)
    print("✅ Tests terminés!")
    print("=" * 60)
