import os
import glob
import random
try:
    import speech_recognition as sr
    SPEECH_REC_AVAILABLE = True
except ImportError:
    SPEECH_REC_AVAILABLE = False

import threading
import time

try:
    import cv2
except ImportError:
    cv2 = None
    print("[WARNING] cv2 non disponible dans speech_to_image_model")

try:
    import mediapipe as mp
except ImportError:
    mp = None
    print("[WARNING] mediapipe non disponible dans speech_to_image_model")

class SpeechToImageModel:

    """
    Modèle unifié pour convertir la Parole -> Image de Geste
    """
    
    def __init__(self, data_path='Data', language='fr-FR'):
        self.data_path = data_path
        self.language = language
        if SPEECH_REC_AVAILABLE:
            self.recognizer = sr.Recognizer()
            self.microphone = sr.Microphone()
        else:
            self.recognizer = None
            self.microphone = None
        
        # Initialisation MediaPipe Hands pour validation
        self.mp_hands = mp.solutions.hands
        # Mode statique, min confidence 0.3
        self.hands_validator = self.mp_hands.Hands(
            static_image_mode=True,
            max_num_hands=2,
            min_detection_confidence=0.3
        )
        
        # Cache des images pour accès rapide
        self.image_cache = {}
        self._build_cache()
        
        # Status
        self.is_listening = False
        
    def _build_cache(self):
        """Indexe toutes les images au démarrage pour une recherche instantanée"""
        print("[MODEL] Indexation des images...")
        count = 0
        
        if not os.path.exists(self.data_path):
            print(f"[WARNING] Dossier {self.data_path} introuvable")
            return

        # Parcourir récursivement avec os.walk pour trouver TOUTES les images
        # Structure attendue: Data/Label/*.jpg OU Data/Label/SubDir/*.jpg
        for root, dirs, files in os.walk(self.data_path):
            # Ignorer le dossier racine Data lui-même
            if root == self.data_path:
                continue
                
            # Le label est le nom du dossier directement dans Data
            # Ex: Data/Famille/bou -> Label = Famille
            # Ex: Data/A -> Label = A
            relative_path = os.path.relpath(root, self.data_path)
            # Prendre le premier composant du chemin (ex: Famille)
            label = relative_path.split(os.sep)[0]
            label_key = label.lower()
            
            # Trouver les images
            jpg_files = [os.path.join(root, f) for f in files if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
            
            if jpg_files:
                if label_key not in self.image_cache:
                    self.image_cache[label_key] = []
                self.image_cache[label_key].extend(jpg_files)
                count += len(jpg_files)
        
        print(f"[MODEL] Index terminé: {len(self.image_cache)} classes, {count} images.")

    def predict_from_audio(self, timeout=5):
        """
        Écoute le microphone et retourne le chemin de l'image correspondante.
        """
        try:
            with self.microphone as source:
                print("[MODEL] Ajustement du bruit ambiant...")
                self.recognizer.adjust_for_ambient_noise(source, duration=0.5)
                
                print("[MODEL] Écoute en cours... Parlez !")
                try:
                    audio = self.recognizer.listen(source, timeout=timeout)
                except sr.WaitTimeoutError:
                    return None, None
            
            print("[MODEL] Traitement audio...")
            text = self.recognizer.recognize_google(audio, language=self.language)
            print(f"[MODEL] Texte brut: {text}")
            
            # Prédiction image
            image_path = self._get_image_for_text(text)
            
            # Si pas d'image locale, proposer recherche Google
            if not image_path:
                self._search_google(text)
                return text, "GOOGLE_SEARCH"
            
            return text, image_path
            
        except sr.UnknownValueError:
            print("[MODEL] Parole non comprise")
            return None, None
        except Exception as e:
            print(f"[MODEL] Erreur: {e}")
            return None, None

    def _get_image_for_text(self, text):
        """Logique de correspondance Texte -> Image"""
        if not text: return None
        text = text.lower().strip()
        
        # 1. Correspondance exacte
        if text in self.image_cache:
            return random.choice(self.image_cache[text])
        
        # 2. Correspondance lettre unique
        if len(text) == 1 and text in self.image_cache:
            return random.choice(self.image_cache[text])
        
        print(f"[MODEL] Aucune image locale pour: '{text}'")
        return None

    def _has_hands(self, image_path):
        """Vérifie si l'image contient des mains via MediaPipe"""
        try:
            # Lire image
            img = cv2.imread(image_path)
            if img is None: return False
            
            # Convertir RGB
            img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            
            # Détection
            results = self.hands_validator.process(img_rgb)
            
            if results.multi_hand_landmarks:
                print(f"[VALIDATION] ✅ Mains détectées dans {os.path.basename(image_path)}")
                return True
            else:
                print(f"[VALIDATION] ❌ Pas de main dans {os.path.basename(image_path)}")
                return False
        except Exception as e:
            print(f"[VALIDATION] Erreur: {e}")
            return False

    def _search_google(self, query):
        """
        Tente de télécharger une image (Google/Bing) et VALIDE qu'elle contient une main.
        """
        try:
            import requests
            import re
            
            print(f"[WEB] Recherche image (MAIN) pour: '{query}'...")
            session = requests.Session()
            session.headers.update({
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
            })

            image_urls = []
            
            # --- STRATÉGIE 1: Google Images (Ciblage "Mains") ---
            try:
                # Ajout de "geste main" et "dessin" pour cibler des illustrations claires
                search_term = f"Langue des signes {query} geste main"
                url = f"https://www.google.com/search?q={search_term}&tbm=isch&gbv=1"
                
                resp = session.get(url, timeout=5)
                # Trouver TOUS les liens possibles
                found = re.findall(r'src=["\'](https?://[^"\']+\.(?:jpg|jpeg|png|gif))["\']', resp.text, re.IGNORECASE)
                if not found:
                     found = re.findall(r'<img[^>]+src=["\'](https?://[^"\']+)["\']', resp.text)
                
                for link in found:
                    if 'google' not in link and 'gstatic' not in link:
                        image_urls.append(link)
                    elif 'encrypted-tbn0' in link:
                         image_urls.append(link)
            except Exception: pass

            # --- STRATÉGIE 2: Bing Images ---
            if len(image_urls) < 3: # Si peu de résultats, compléter avec Bing
                try:
                    url_bing = f"https://www.bing.com/images/search?q=sign+language+{query}+hand+sign"
                    resp_bing = session.get(url_bing, timeout=5)
                    bing_found = re.findall(r'murl&quot;:&quot;(https?://[^&]+)&quot;', resp_bing.text)
                    if not bing_found:
                         bing_found = re.findall(r'src=["\'](https?://[^"\']+\.jpg)["\']', resp_bing.text)
                    image_urls.extend(bing_found)
                except Exception: pass

            # --- TÉLÉCHARGEMENT & VALIDATION (Loop) ---
            temp_dir = "Temp"
            if not os.path.exists(temp_dir): os.makedirs(temp_dir)
            
            # Tester les 5 premières URLs
            candidates = [u for u in image_urls if u.startswith('http')][:5]
            
            for i, img_url in enumerate(candidates):
                print(f"[WEB] Test candidat {i+1}/{len(candidates)}...")
                try:
                    safe_query = "".join([c for c in query if c.isalpha() or c.isdigit()]).rstrip()
                    temp_path = os.path.join(temp_dir, f"web_{safe_query}_{i}.jpg")
                    
                    img_data = session.get(img_url, timeout=5).content
                    with open(temp_path, 'wb') as f:
                        f.write(img_data)
                    
                    # VALIDATION MAIN
                    if self._has_hands(temp_path):
                        print(f"[WEB] Image validée ! Sauvegardée: {temp_path}")
                        return temp_path
                    else:
                        # Supprimer si invalide
                        try: os.remove(temp_path)
                        except: pass
                        
                except Exception as e:
                    print(f"[WEB] Erreur candidat {i}: {e}")
            
            print("[WEB] Aucune image valide (avec mains) trouvée.")
            
        except Exception as e:
            print(f"[WEB] Erreur globale: {e}")
        
        return None

    def _generate_ai_image(self, query):
        """
        Génère une image via IA (Pollinations.ai).
        Augmentation de la robustesse (Timeout + Seed).
        """
        try:
            import requests
            print(f"[IA] Génération image artificielle pour: '{query}'...")
            
            # Prompt optimisé
            prompt = f"Hand gesture sign language for word {query}, drawing style, educational, clear hand, white background"
            
            # Ajout d'un seed aléatoire pour éviter le cache et varier
            seed = random.randint(0, 100000)
            ai_url = f"https://image.pollinations.ai/prompt/{prompt}?width=640&height=480&nologo=true&seed={seed}&model=flux"
            
            temp_dir = "Temp"
            if not os.path.exists(temp_dir): os.makedirs(temp_dir)
            
            safe_query = "".join([c for c in query if c.isalpha() or c.isdigit()]).rstrip()
            temp_path = os.path.join(temp_dir, f"ai_{safe_query}.jpg")
            
            # Télécharger avec grand timeout (les modèles sont parfois lents)
            try:
                response = requests.get(ai_url, timeout=60)
            except requests.exceptions.Timeout:
                print("[IA] Timeout (60s), nouvelle tentative...")
                # Retry une fois
                seed = random.randint(0, 100000)
                ai_url = f"https://image.pollinations.ai/prompt/{prompt}?width=640&height=480&nologo=true&seed={seed}"
                response = requests.get(ai_url, timeout=60)

            if response.status_code == 200:
                with open(temp_path, 'wb') as f:
                    f.write(response.content)
                
                # VALIDATION MAIN
                if self._has_hands(temp_path):
                    print(f"[IA] ✅ Image Générée et Validée: {temp_path}")
                    return temp_path
                else:
                    print(f"[IA] ❌ Image générée rejetée (Main malformée ou non détectée)")
                    return None
            else:
                print(f"[IA] Erreur API: {response.status_code}")
                
        except Exception as e:
            print(f"[IA] Erreur génération: {e}")
        except Exception as e:
            print(f"[IA] Erreur génération: {e}")
        
        return None

    def get_full_image_path(self, text):
        """
        MÉTHODE API: Retourne le chemin d'une image pour un texte donné.
        Pipeline Complet: Cache Local -> Web Search -> AI Generation
        """
        # 1. Local
        image_path = self._get_image_for_text(text)
        
        # 2. Web Search (Réel)
        if not image_path:
            image_path = self._search_google(text)
        
        # 3. AI Generation (Création)
        if not image_path:
            image_path = self._generate_ai_image(text)
            
        return image_path


    def predict_from_audio(self, timeout=5):
        try:
            with self.microphone as source:
                print("[MODEL] Ajustement du bruit ambiant...")
                self.recognizer.adjust_for_ambient_noise(source, duration=0.5)
                
                print("[MODEL] Écoute en cours... Parlez !")
                try:
                    audio = self.recognizer.listen(source, timeout=timeout)
                except sr.WaitTimeoutError:
                    return None, None
            
            print("[MODEL] Traitement audio...")
            text = self.recognizer.recognize_google(audio, language=self.language)
            print(f"[MODEL] Texte brut: {text}")
            
            # 1. Local
            image_path = self._get_image_for_text(text)
            
            # 2. Web Search (Réel)
            if not image_path:
                print("[MODEL] Pas d'image locale, tentative Web...")
                image_path = self._search_google(text)
            
            # 3. AI Generation (Création)
            if not image_path:
                print("[MODEL] Web échoué, tentative GÉNÉRATION IA...")
                image_path = self._generate_ai_image(text)

            return text, image_path
            
        except sr.UnknownValueError:
            print("[MODEL] Parole non comprise")
            return None, None
        except Exception as e:
            print(f"[MODEL] Erreur: {e}")
            return None, None


# --- Exemple d'utilisation ---
if __name__ == "__main__":
    print("--- Initialisation du Modèle SpeechToImage ---")
    model = SpeechToImageModel()
    
    while True:
        input("\nAppuyez sur Entrée pour enregistrer (ou Ctrl+C pour quitter)...")
        
        text, image = model.predict_from_audio()
        
        if text:
            print(f"📝 Résultat: {text}")
            if image:
                print(f"🖼️ Image: {image}")
                # Afficher l'image (optionnel, nécessite cv2 ou PIL)
                try:
                    os.startfile(image) # Ouvre l'image sur Windows
                except: pass
            else:
                print("❌ Pas d'image trouvée")
        else:
            print("❌ Rien entendu")
