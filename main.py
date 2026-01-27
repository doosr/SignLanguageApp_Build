import sys
from types import ModuleType

# Mock matplotlib to avoid MediaPipe crash on Android
class MockModule(ModuleType):
    def __getattr__(self, name):
        return MockModule(name)
    def __call__(self, *args, **kwargs):
        return MockModule()

if 'matplotlib' not in sys.modules:
    for m in ['matplotlib', 'matplotlib.pyplot', 'matplotlib.collections', 'matplotlib.font_manager']:
        sys.modules[m] = MockModule(m)


try:
    import cv2
except ImportError as e:
    print(f"[CRITICAL] Failed to import cv2: {e}")
    cv2 = None

try:
    import mediapipe as mp
except ImportError as e:
    print(f"[CRITICAL] Failed to import mediapipe: {e}")
    mp = None

try:
    import numpy as np
except ImportError as e:
    print(f"[CRITICAL] Failed to import numpy: {e}")
    np = None

import pickle
import time
import os

from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.image import Image
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.anchorlayout import AnchorLayout
from kivy.clock import Clock
from kivy.graphics.texture import Texture
from kivy.core.window import Window
from plyer import tts
from kivy.animation import Animation
from kivy.graphics import Color, RoundedRectangle, Line
from kivy.metrics import dp

from kivy.utils import platform
import json
from kivy.uix.textinput import TextInput
from kivy.config import Config

# Fix crash on Windows exit related to pen input
Config.set('input', 'mouse', 'mouse,multitouch_on_demand')
# Désactiver wm_touch et wm_pen qui causent des crashs à la fermeture
Config.set('input', 'wm_touch', '')
Config.set('input', 'wm_pen', '')

import threading
from kivy.clock import mainthread
from speech_to_gesture import create_speech_recognizer
from gesture_display_utils import get_gesture_image
from gesture_display_utils import get_gesture_image
from speech_to_image_model import SpeechToImageModel # Module IA/Web

# Optional imports for Arabic text support (may fail on some Android builds)
try:
    import arabic_reshaper
    from bidi.algorithm import get_display
    ARABIC_SUPPORT = True
except ImportError:
    ARABIC_SUPPORT = False
    print("[WARNING] Arabic text rendering libraries not available")


# Helper function pour obtenir le chemin des fichiers sur Android
def get_file_path(filename):
    """Retourne le chemin absolu d'un fichier, compatible Android et PC"""
    # Sur Android et PC, le répertoire de l'application est le répertoire de main.py
    base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, filename)

def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")

    return os.path.join(base_path, relative_path)

def get_gesture_image(key):
    """Cherche une image illustrative pour le geste dans le dossier data"""
    # Chemin vers dossier data
    base_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')
    if not os.path.exists(base_dir):
        # Fallback pour VSCode cwd
        base_dir = os.path.join(os.getcwd(), 'data')
    
    target_dir = None
    
    # 1. Chercher direct (data/key)
    candidate = os.path.join(base_dir, key)
    if os.path.exists(candidate):
        target_dir = candidate
    
    # 2. Si pas trouvé, chercher récursivement dans les sous-dossiers (Categories)
    if not target_dir:
        for root, dirs, files in os.walk(base_dir):
            if key in dirs:
                target_dir = os.path.join(root, key)
                break
                
    if target_dir and os.path.exists(target_dir):
        # Prendre la première image jpg/png trouvée
        # Essayer de prendre une image au milieu ou représentative si possible (ex: index 10)
        images = [f for f in os.listdir(target_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
        if images:
            # Trier pour être déterministe
            images.sort()
            # Prendre la 5ème image si dispo (souvent meilleure que la 1ère qui peut être floue)
            idx = min(5, len(images) - 1)
            return os.path.join(target_dir, images[idx])
            
    print(f"[WARNING] Aucune image trouvée pour le geste: {key}")
    return None

class HandGestureApp(App):
    SEQUENCE_LENGTH = 30
    
    # Mapping Mots -> Emojis pour l'affichage (Dialecte Tunisien / Français)
    WORD_TO_EMOJI = {
        # Salutations / Base
        '3aslema': '👋', 'mar7ba': '🤗', 'labes': '👍', 'lyoum': '📅', 
        'oui': '✅', 'non': '❌', 'enti': '👉', 'demande': '❓', 
        'n3awnek': '🤝', 'nekteblk': '✍️',
        
        # Lieux (Destinations)
        'dar': '🏠', 'sbitar': '🏥', 'mostawsaf': '⚕️', 'banka': '🏦', 
        'bousta': '🏣', 'ma7kma': '⚖️', 'wzara': '🏛️', 'baladya': '🏢', 
        'radio': '📻', 'telvza': '📺',
        
        # Transport
        'karhba': '🚗', 'car': '🚌', 'train': '🚂', 'metro': '🚋', 'métro': '🚋',
        'taxi': '🚕', 'louage': '🚐',
        
        # Famille
        '3ayla': '👨‍👩‍👧‍👦', 'bou': '👨', 'om': '👩', 'o5t': '👧', '5ou': '👦',
        'bent': '👧', 'eben': '👦', 'jad': '👴', 'jadda': '👵', 
        'mar2a': '👩', 'tfol': '👶', '5al-3am': '🧔',
        
        # Jours
        'thnin': '1️⃣', 'thleth': '2️⃣', 'erb3a': '3️⃣', '5mis': '4️⃣', 
        'jom3a': '🕌', 'sebt': '🛒', 'a7ad': '☀️',
        
        # Autres
        'se7a': '💊', 'siye7a': '🏖️', 'ta3lim': '🎓', 'tha9afa': '🎭', 
        'ta9ra': '📚', 'ta3raf': '🧠', 'cv': '📄', 'chabeb': '🧑',
        'barnamjk': '📋', '5adamet': '⚙️', 'assam': '🔇',
        
        # Lettres
        'a': '🅰️', 'b': '🅱️', 'c': '©️',
    }

    def build(self):
        self.title = "HandGesture"
        self.last_candidate = None
        self.validation_start_time = 0
        self.VALIDATION_DELAY = 1.0 # Secondes pour valider un mot
        if platform == 'android':
            from android.permissions import request_permissions, Permission
            request_permissions([Permission.CAMERA, Permission.RECORD_AUDIO])

        # Modern gradient background
        Window.clearcolor = (0.05, 0.05, 0.1, 1)  # Dark blue-black

        # Main Layout with modern spacing
        self.main_layout = BoxLayout(orientation='vertical', padding=dp(10), spacing=dp(5))
        
        # === PREPARATION DES WIDGETS (Sans les ajouter au layout encore) ===
        
        # 8. Visual Display (Camera + Geste) - SIDE BY SIDE (Centré au milieu)
        self.visual_anchor = AnchorLayout(anchor_x='center', anchor_y='center', size_hint=(1, 1))
        self.split_display = BoxLayout(orientation='horizontal', size_hint=(0.9, 1), spacing=dp(10))
        
        self.camera_container = FloatLayout(size_hint=(0.65, 1))
        # Image caméra
        self.image = Image(size_hint=(1, 1), allow_stretch=True, keep_ratio=True)
        self.camera_container.add_widget(self.image)
        
        self.detection_label = Label(text="", font_size='48sp', bold=True, color=(0.2, 0.8, 1, 0),
                                   size_hint=(None, None), pos_hint={'center_x': 0.5, 'center_y': 0.5})
        self.camera_container.add_widget(self.detection_label)
        
        # Zone de visualisation des gestes
        self.gesture_container = FloatLayout(size_hint=(0.35, 1))
        
        # Camera Feed
        self.gesture_image = Image(allow_stretch=True, keep_ratio=False, anim_delay=0.05)
        self.gesture_container.add_widget(self.gesture_image)
        
        # Letters/Status Overlay "Visualisation des Signes" supprimé
        
        
        
        # 1. Camera (maintenant à GAUCHE et plus grande)
        self.split_display.add_widget(self.camera_container)
        
        # 2. Zone Geste (maintenant à DROITE)
        self.split_display.add_widget(self.gesture_container)
        
        # Ajouter le split_display dans l'ancre pour le centrage
        self.visual_anchor.add_widget(self.split_display)
        
        # 1. Info Card
        self.info_card = BoxLayout(orientation='vertical', size_hint=(1, None), height=dp(90), spacing=dp(2), padding=dp(10))
        with self.info_card.canvas.before:
            Color(0.12, 0.15, 0.22, 1)
            self.info_card_bg = RoundedRectangle(size=self.info_card.size, pos=self.info_card.pos, radius=[dp(12)])
        self.info_card.bind(size=self._update_card_bg, pos=self._update_card_bg)
        
        self.letters_label = Label(text="Détecté: ", font_size='16sp', color=(0.6, 0.8, 1, 1), bold=True, halign='left')
        self.letters_label.bind(size=self.letters_label.setter('text_size'))
        self.info_card.add_widget(self.letters_label)
        
        self.phrase_label = Label(text="Phrase: ", font_size='18sp', color=(1, 1, 1, 1), bold=True, halign='left')
        self.phrase_label.bind(size=self.phrase_label.setter('text_size'))
        self.info_card.add_widget(self.phrase_label)

        # 2. Modern Action Buttons
        self.buttons_layout = BoxLayout(orientation='horizontal', size_hint=(1, None), height=dp(50), spacing=dp(10))
        self.clear_btn = self._create_modern_button("Effacer", (0.95, 0.27, 0.33, 1), self.clear_phrase)
        self.buttons_layout.add_widget(self.clear_btn)
        self.speak_btn = self._create_modern_button("Parler", (0.26, 0.67, 0.45, 1), self.speak_phrase)
        self.buttons_layout.add_widget(self.speak_btn)
        self.delete_btn = self._create_modern_button("Retour", (0.95, 0.61, 0.27, 1), self.delete_last_letter)
        self.buttons_layout.add_widget(self.delete_btn)
        self.space_btn = self._create_modern_button("Espace", (0.27, 0.54, 0.95, 1), self.add_space)
        self.buttons_layout.add_widget(self.space_btn)

        # 3. Mode Selector
        self.mode_selector = BoxLayout(orientation='horizontal', size_hint=(1, None), height=dp(45), spacing=dp(10))
        self.letters_mode_btn = self._create_modern_button("LETTRES", (0.5, 0.5, 0.5, 1), self.set_letters_mode, size_hint=(0.5, 1))
        self.mode_selector.add_widget(self.letters_mode_btn)
        self.words_mode_btn = self._create_modern_button("MOTS", (0.26, 0.67, 0.45, 1), self.set_words_mode, size_hint=(0.5, 1))
        self.mode_selector.add_widget(self.words_mode_btn)

        # 4. Simulation
        self.sim_layout = BoxLayout(orientation='horizontal', size_hint=(1, None), height=dp(45), spacing=dp(10))
        self.sim_input = TextInput(hint_text='Ecrire phrase...', multiline=False, size_hint=(0.7, 1), font_size='16sp',
                                 background_color=(0.15, 0.18, 0.25, 1), foreground_color=(1, 1, 1, 1), padding=[dp(12), dp(8)])
        self.sim_layout.add_widget(self.sim_input)
        self.sim_btn = self._create_modern_button("JOUER", (0.95, 0.61, 0.27, 1), self.simulate_from_text, size_hint=(0.3, 1))
        self.sim_layout.add_widget(self.sim_btn)

        # 5. Langues
        self.lang_layout = BoxLayout(orientation='horizontal', size_hint=(1, None), height=dp(45), spacing=dp(10))
        # Utiliser Arial pour le bouton Arabe aussi
        btn_ar = self._create_lang_button("العربية", (0.5, 0.4, 0.85, 1), lambda x: self.change_language('ar'))
        btn_ar.font_name = 'Arial'
        btn_ar.text = self.fix_text("العربية")
        self.lang_layout.add_widget(btn_ar)
        self.lang_layout.add_widget(self._create_lang_button("FR", (0.4, 0.6, 0.95, 1), lambda x: self.change_language('fr')))
        self.lang_layout.add_widget(self._create_lang_button("EN", (0.95, 0.5, 0.5, 1), lambda x: self.change_language('en')))

        # 6. Micro
        self.voice_layout = BoxLayout(orientation='horizontal', size_hint=(1, None), height=dp(50), spacing=dp(10))
        self.micro_btn = self._create_modern_button("MICRO", (0.6, 0.3, 0.9, 1), self.start_voice_recognition, size_hint=(1, 1))
        self.voice_layout.add_widget(self.micro_btn)

        # 7. ESP32
        self.esp_layout = BoxLayout(orientation='horizontal', size_hint=(1, None), height=dp(40), spacing=dp(8))
        self.ip_input = TextInput(text='192.168.1.100', multiline=False, size_hint=(0.4, 1), font_size='16sp',
                                background_color=(0.15, 0.18, 0.25, 1), foreground_color=(1, 1, 1, 1), padding=[dp(12), dp(8)])
        self.esp_layout.add_widget(self.ip_input)
        self.esp_layout.add_widget(self._create_modern_button("Camera", (0.26, 0.67, 0.45, 1), self.use_phone_camera, size_hint=(0.3, 1)))
        self.esp_layout.add_widget(self._create_modern_button("ESP32", (0.2, 0.7, 0.9, 1), self.connect_esp32, size_hint=(0.3, 1)))

        # === ASSEMBLAGE FINAL - TOUS LES BOUTONS EN HAUT ===
        self.main_layout.add_widget(self.buttons_layout)  # 1. Contrôles action
        self.main_layout.add_widget(self.mode_selector)   # 2. Mode
        self.main_layout.add_widget(self.sim_layout)      # 3. Simulation
        self.main_layout.add_widget(self.lang_layout)     # 4. Langues
        self.main_layout.add_widget(self.voice_layout)    # 5. Micro
        self.main_layout.add_widget(self.esp_layout)      # 6. ESP32
        self.main_layout.add_widget(self.info_card)       # 7. Info
        self.main_layout.add_widget(self.visual_anchor)   # 8. Zone Visuelle (Centrée)

        self.init_logic()
        return self.main_layout
    
    def _update_card_bg(self, instance, value):
        """Update card background position and size"""
        self.info_card_bg.size = instance.size
        self.info_card_bg.pos = instance.pos

    # Méthode _update_gesture_bg supprimée (plus de fond)
    
    def _create_modern_button(self, text, color, callback, size_hint=(0.25, 1)):
        """Create a modern styled button with rounded corners"""
        btn = Button(
            text=text,
            size_hint=size_hint,
            background_color=(0, 0, 0, 0),  # Transparent for custom bg
            font_size='15sp',
            bold=True,
            color=(1, 1, 1, 1)
        )
        
        # Custom rounded background
        with btn.canvas.before:
            Color(*color)
            btn.rect = RoundedRectangle(
                size=btn.size,
                pos=btn.pos,
                radius=[dp(12)]
            )
        
        btn.bind(size=lambda i, v: setattr(btn.rect, 'size', v))
        btn.bind(pos=lambda i, v: setattr(btn.rect, 'pos', v))
        btn.bind(on_press=callback)
        
        return btn
    
    def _create_lang_button(self, text, color, callback):
        """Create language selector button"""
        return self._create_modern_button(text, color, callback, size_hint=(0.33, 1))

    def init_logic(self):
        """Initialisation avec gestion d'erreurs robuste pour Android"""
        try:
            # Model
            print("[INFO] Chargement du modèle...")
            self.model_static = None
            self.model = None
            
            model_path = get_file_path('model.p')
            print(f"[INFO] Chemin du modèle: {model_path}")
            
            if not os.path.exists(model_path):
                print(f"[ERROR] Fichier model.p introuvable: {model_path}")
            else:
                with open(model_path, 'rb') as f:
                    model_dict = pickle.load(f)
                    self.model_static = model_dict['model'] 
                    self.model = self.model_static # Compatibilité totale
                print("[OK] Modèle statique chargé")
        except Exception as e:
            print(f"[ERROR] Erreur chargement modèle statique: {e}")
            self.model_static = None
            self.model = None
                
        try:
            seq_path = get_file_path('model_sequence.p')
            with open(seq_path, 'rb') as f:
                self.model_sequence = pickle.load(f)['model']
            print("[OK] Modèle séquence chargé")
        except:
            self.model_sequence = None
            print("[WARNING] Modèle séquence non trouvé (Mode MOTS désactivé)")

        # MediaPipe
        print("[INFO] Initialisation MediaPipe...")
        try:
            self.mp_hands = mp.solutions.hands
            self.mp_drawing = mp.solutions.drawing_utils
            self.mp_drawing_styles = mp.solutions.drawing_styles
            self.hands = self.mp_hands.Hands(static_image_mode=True, min_detection_confidence=0.3)
            print("[OK] MediaPipe initialisé")
        except Exception as e:
            print(f"[ERROR] Erreur MediaPipe: {e}")
            self.hands = None

        # Labels
        self.labels_dict = {
            0: 'A', 1: 'B', 2: 'C', 3: 'D', 4: 'Demandes', 5: 'Destinations',
            6: 'E', 7: 'F', 8: 'Famille', 9: 'G', 10: 'H', 11: 'I', 12: 'J',
            13: 'Jours', 14: 'K', 15: 'L', 16: 'M', 17: 'N', 18: 'O', 19: 'P',
            20: 'Q', 21: 'R', 22: 'S', 23: 'T', 24: 'Transport', 25: 'U',
            26: 'V', 27: 'W', 28: 'X', 29: 'Y', 30: 'Z'
        }

        # State variables
        self.detected_letters = []
        self.phrase_text = ""
        self.phrase_keys = []  # Pour traduction
        self.last_time_letter_added = time.time()
        self.correction_dict = {'H': ['B', 'G'], 'J': ['I']}
        self.using_esp32 = False
        self.esp32_url = ""

        # Gestion des modes
        self.detection_mode = "LETTRES" # Default
        self.frame_buffer = []
        self.SEQUENCE_LENGTH = 15
        self.candidate_history = []

        # Charger traductions
        print("[INFO] Chargement des traductions...")
        self.current_lang = 'fr'
        self.load_translations()

        # Init Reconnaissance Vocale
        try:
            print("[INFO] Init Reconnaissance Vocale...")
            self.speech_recognizer = create_speech_recognizer(self.current_lang)
            print("[OK] Reconnaissance vocale initialisée")
        except Exception as e:
            print(f"[WARNING] Reconnaissance vocale non disponible: {e}")
            self.speech_recognizer = None



        # Init Module IA/Web
        try:
            print("[INFO] Init SpeechToImageModel (Web/AI)...")
            self.speech_to_image_model = SpeechToImageModel()
            self.speech_to_image_model.load_resource_index() # Important
            print("[OK] Module IA/Web chargé")
        except Exception as e:
            print(f"[WARNING] Module IA non chargé: {e}")
            self.speech_to_image_model = None

        # Plus besoin overlay image dans camera container
        # self.gesture_overlay... (supprimé car on a self.gesture_image dédié)

        # Camera initialization

        # Camera initialization
        print("[INFO] Initialisation de la caméra...")
        try:
            self.capture = self._init_camera()
            if self.capture and self.capture.isOpened():
                print("[OK] Caméra initialisée avec succès")
                Clock.schedule_interval(self.update, 1.0 / 30.0) # 30 FPS
            else:
                print("[WARNING] Caméra non disponible, mode ESP32 seulement")
                self.capture = None
        except Exception as e:
            print(f"[ERROR] Erreur initialisation caméra: {e}")
            self.capture = None
            
        print("[OK] Initialisation terminée")

    def _init_camera(self):
        """Initialise la caméra avec backends adaptés à la plateforme"""
        print(f"[INFO] Plateforme détectée: {platform}")
        
        try:
            if platform == 'android':
                # Sur Android, utiliser l'index simple sans backend spécifique
                print("[INFO] Initialisation caméra Android...")
                
                # Essayer les deux caméras (0 = arrière, 1 = avant)
                for index in [0, 1]:
                    print(f"[INFO] Test caméra index {index}...")
                    cap = cv2.VideoCapture(index)
                    
                    if cap.isOpened():
                        # Test rapide
                        ret, frame = cap.read()
                        if ret and frame is not None:
                            print(f"[OK] Caméra {index} fonctionne")
                            return cap
                        cap.release()
                
                print("[WARNING] Aucune caméra Android trouvée")
                return None
                
            else:
                # Sur PC (Windows/Linux/Mac)
                print("[INFO] Initialisation caméra PC...")
                backends = [
                    ("MSMF", cv2.CAP_MSMF),    # Windows 10/11
                    ("DSHOW", cv2.CAP_DSHOW),   # Windows alternatif
                    ("V4L2", cv2.CAP_V4L2),     # Linux
                    ("ANY", cv2.CAP_ANY)        # Fallback
                ]
                
                for name, backend in backends:
                    for index in range(2):
                        try:
                            print(f"[INFO] Test camera index={index}, backend={name}...")
                            cap = cv2.VideoCapture(index, backend)
                            
                            if cap.isOpened():
                                time.sleep(0.3)
                                ret, frame = cap.read()
                                if ret and frame is not None:
                                    print(f"[OK] Caméra trouvée: {name} index {index}")
                                    return cap
                                cap.release()
                        except Exception as e:
                            print(f"[WARNING] Backend {name} échoué: {e}")
                            continue
                
                print("[WARNING] Aucune caméra PC trouvée")
                return None
                
        except Exception as e:
            print(f"[ERROR] Exception dans _init_camera: {e}")
            import traceback
            traceback.print_exc()
            return None

    def connect_esp32(self, instance):
        ip = self.ip_input.text.strip()
        if not ip:
            return
        
        # Format typical for ESP32-CAM stream server provided
        url = f"http://{ip}:81/stream"
        print(f"Tentative de connexion à l'ESP32: {url}")
        
        # Tester la connexion
        new_cap = cv2.VideoCapture(url)
        if new_cap.isOpened():
            ret, frame = new_cap.read()
            if ret:
                if self.capture:
                    self.capture.release()
                self.capture = new_cap
                self.using_esp32 = True
                # cam_btn supprimé - pas de feedback visuel sur bouton
                print("✓ Connexion ESP32 réussie!")
            else:
                print("❌ Impossible de lire le flux ESP32")
                new_cap.release()
        else:
            print("❌ Impossible d'ouvrir l'URL ESP32")

    def use_phone_camera(self, instance):
        """Basculer vers caméra PC/Tél (quitter mode Micro/ESP)"""
        print("[INFO] Activation caméra locale...")
        
        # Reset visuel des boutons
        self.micro_btn.text = "MICRO"
        self.micro_btn.canvas.before.children[0].rgba = (0.6, 0.3, 0.9, 1)
        
        # Rendre l'image de geste invisible (pas de fond blanc)
        self.gesture_image.source = ""
        self.gesture_image.reload()
        self.gesture_image.opacity = 0  # Invisible
        
        # Gestion de la caméra
        if self.capture:
            self.capture.release()
            
        self.using_esp32 = False
        # cam_btn supprimé - pas de feedback visuel sur bouton
        
        # Init caméra locale
        self.capture = self._init_camera()

    def set_letters_mode(self, instance):
        """Basculer en mode LETTRES"""
        self.detection_mode = "LETTRES"
        # UI Update
        self.letters_mode_btn.canvas.before.children[0].rgba = (0.26, 0.67, 0.45, 1)  # Green
        self.words_mode_btn.canvas.before.children[0].rgba = (0.5, 0.5, 0.5, 1)  # Gray
        # Reset buffers
        self.frame_buffer = []
        self.candidate_history = []
        # Feedback
        self.letters_label.text = "Mode: LETTRES"

    def set_words_mode(self, instance):
        """Basculer en mode MOTS"""
        self.detection_mode = "MOTS"
        # UI Update
        self.letters_mode_btn.canvas.before.children[0].rgba = (0.5, 0.5, 0.5, 1)  # Gray
        self.words_mode_btn.canvas.before.children[0].rgba = (0.26, 0.67, 0.45, 1)  # Green
        # Reset buffers
        self.frame_buffer = []
        self.candidate_history = []
        # Feedback
        self.letters_label.text = "Mode: MOTS (Séquence)"


    def update(self, dt):
        """Mise à jour du flux vidéo avec gestion d'erreurs robuste"""
        try:
            # Vérifier que la caméra existe
            if not self.capture:
                return
                
            # Anti-blocage: compteur d'erreurs
            if not hasattr(self, '_consecutive_errors'):
                self._consecutive_errors = 0
                
            ret, frame = self.capture.read()
            if not ret or frame is None:
                self._consecutive_errors += 1
                if self._consecutive_errors >= 30:  # ~1 seconde d'erreurs
                    print("[WARNING] Trop d'erreurs caméra, tentative reconnexion...")
                    try:
                        self.capture.release()
                        time.sleep(1)
                        self.capture = self._init_camera()
                        self._consecutive_errors = 0
                    except:
                        pass
                return
            
            # Réinitialiser le compteur si lecture réussie
            self._consecutive_errors = 0
        except Exception as e:
            print(f"[ERROR] Exception dans update: {e}")
            return

        H, W, _ = frame.shape
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # MediaPipe Processing
        data_aux = []
        x_ = []
        y_ = []
        self.detected_letters = [] # Reset for this frame
        
        if self.hands:
            results = self.hands.process(frame_rgb)
            
            if results.multi_hand_landmarks:
                # FIX: SORT HANDS Left-to-Right match training data logic from inference_classifier.py
                # Trie les mains par position X (landmark 0 = poignet) pour ordre constant Gauche -> Droite
                sorted_hands = sorted(results.multi_hand_landmarks, key=lambda h: h.landmark[0].x)
                
                for hand_landmarks in sorted_hands:
                    # Dessiner les points seulement (pas de lignes squelette)
                    for landmark in hand_landmarks.landmark:
                        x_px = int(landmark.x * W)
                        y_px = int(landmark.y * H)
                        # Points verts comme dans inference_classifier
                        cv2.circle(frame, (x_px, y_px), 5, (0, 255, 0), -1) 
                    
                    # Collecter X et Y pour la bounding box globale
                    for landmark in hand_landmarks.landmark:
                        x_.append(landmark.x)
                        y_.append(landmark.y)

                # Calculer data_aux (features normalisées)
                if x_ and y_:
                    min_x = min(x_)
                    min_y = min(y_)
                    for hand_landmarks in sorted_hands:
                        for landmark in hand_landmarks.landmark:
                            data_aux.append(landmark.x - min_x)
                            data_aux.append(landmark.y - min_y)
                
                # FIX: Pad data to 84 features if model expects it (2 hands)
            # Model expects 84 features (2 hands) but we have 42 (1 hand)
            if len(data_aux) == 42:
                # Pad with zeros for the second hand
                data_aux_padded = data_aux + [0] * 42  # Total = 84 features
            elif len(data_aux) == 84:
                data_aux_padded = data_aux  # Already 2 hands
            else:
                # Unexpected size, skip
                data_aux_padded = None
            
            if data_aux_padded:
                prediction_source = None
                predicted_character = None
                
                # 1. MODE MOTS (SEQUENCE)
                if self.detection_mode == "MOTS" and self.model_sequence:
                    self.frame_buffer.append(data_aux_padded)
                    if len(self.frame_buffer) > self.SEQUENCE_LENGTH:
                        self.frame_buffer.pop(0)
                        
                    if len(self.frame_buffer) == self.SEQUENCE_LENGTH:
                        seq_input = np.array(self.frame_buffer).flatten()
                        try:
                            seq_probs = self.model_sequence.predict_proba([seq_input])[0]
                            max_prob = np.max(seq_probs)
                            idx = np.argmax(seq_probs)
                            candidate = self.model_sequence.classes_[idx]
                            
                            # Log terminal pour debug
                            if max_prob > 0.1: # Ne pas spammer si très faible confiance
                                print(f"[DEBUG] Candidat: {candidate} ({max_prob:.2f})")
                            
                            if max_prob > 0.3: # Seuil confiance abaissé
                                # Filtrage simple
                                self.candidate_history.append(candidate)
                                if len(self.candidate_history) > 10:
                                    self.candidate_history.pop(0)
                                    
                                from collections import Counter
                                counts = Counter(self.candidate_history)
                                most_common, frequency = counts.most_common(1)[0]
                                
                                # Détection plus rapide (3 frames)
                                if most_common == candidate and frequency >= 3:
                                    # Gestion de la validation temporelle
                                    current_time = time.time()
                                    
                                    # Si c'est un nouveau candidat stable
                                    if self.last_candidate != candidate:
                                        self.last_candidate = candidate
                                        self.validation_start_time = current_time
                                        
                                    # Si le candidat est maintenu assez longtemps (1.0 sec)
                                    elif (current_time - self.validation_start_time) > self.VALIDATION_DELAY:
                                        # Ajouter seulement si différent du dernier validé
                                        if not (self.detected_letters and self.detected_letters[-1] == candidate):
                                            self.detected_letters.append(candidate)
                                            # Reset pour ne pas spammer tout de suite (petite pause)
                                            self.validation_start_time = current_time + 1.0 
                                            
                                    # Pour l'affichage (Bleu pour mot détecté)
                                    prediction_source = "WORD"
                                    predicted_character = candidate 
                        except Exception as e:
                            pass # Silencieux en sequence

                # 2. MODE LETTRES (STATIC)
                else:
                    try:
                        # Priorité à model_static, fallback sur model
                        model_to_use = getattr(self, 'model_static', None) or getattr(self, 'model', None)
                            
                        if model_to_use:
                            prediction = model_to_use.predict([np.asarray(data_aux_padded)])
                            
                            # FIX: Le modèle peut retourner soit un index (int) soit une lettre (str)
                            predicted_value = prediction[0]
                            if isinstance(predicted_value, (int, np.integer)):
                                # C'est un index, utiliser labels_dict
                                predicted_character = self.labels_dict[int(predicted_value)]
                            else:
                                # C'est déjà une lettre (str)
                                predicted_character = str(predicted_value)
                            
                            self.detected_letters.append(predicted_character)
                        else:
                            if not hasattr(self, '_model_warned'):
                                print("[WARNING] Aucun modèle de détection chargé.")
                                self._model_warned = True
                    except Exception as e:
                        print(f"Prediction error: {e}")

            # Modern UI with gradient box and animated text
            if x_:  # Vérifier que des points ont été détectés
                x1 = int(min(x_) * W) - 10
                y1 = int(min(y_) * H) - 10
                x2 = int(max(x_) * W) - 10
                y2 = int(max(y_) * H) - 10

                # Draw modern detection box with glow effect
                # Outer glow
                cv2.rectangle(frame, (x1-3, y1-3), (x2+3, y2+3), (50, 200, 255), 2)
                # Main rectangle with cyan color
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 255), 3)
                
                x1, y1 = int(min(x_) * W) - 10, int(min(y_) * H) - 10
                x2, y2 = int(max(x_) * W) + 10, int(max(y_) * H) + 10
                
                # Couleur BLEUE (BGR) pour mot détecté, comme inference_classifier.py
                color = (255, 0, 0) if prediction_source == "WORD" else (0, 0, 0) 
                
                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 4)
                
                # Afficher le label au-dessus (Texte uniquement sans EMOJI car OpenCV ne supporte pas)
                if predicted_character:
                    label_text = str(predicted_character)
                    
                    cv2.putText(frame, label_text, (x1, y1 - 10), 
                            cv2.FONT_HERSHEY_SIMPLEX, 1.3, color, 3, cv2.LINE_AA)

                # --- Barre de progression de validation (RELAURÉ) ---
                if self.last_candidate and prediction_source == "WORD":
                    elapsed = time.time() - self.validation_start_time
                    progress = min(elapsed / self.VALIDATION_DELAY, 1.0)
                    
                    if elapsed < 2.0: # Ne pas garder éternellement si on bouge
                        # Barre de fond noire
                        bx1, by1 = x1, y2 + 10
                        bx2, by2 = x2, y2 + 22
                        cv2.rectangle(frame, (bx1, by1), (bx2, by2), (0, 0, 0), -1)
                        
                        # Remplissage vert/cyan
                        fw = int((bx2 - bx1) * progress)
                        fcol = (0, 255, 0) if progress >= 1.0 else (0, 255, 255)
                        if fw > 0:
                            cv2.rectangle(frame, (bx1, by1), (bx1 + fw, by2), fcol, -1)
                        
                        # Texte OK!
                        if progress >= 1.0:
                            cv2.putText(frame, "OK!", (bx2 + 5, by2), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

            # Build Phrase
            self.build_phrase(self.detected_letters)


        # Update Kivy Image
        buf1 = cv2.flip(frame, 0)
        buf = buf1.tobytes()
        image_texture = Texture.create(size=(frame.shape[1], frame.shape[0]), colorfmt='bgr')
        image_texture.blit_buffer(buf, colorfmt='bgr', bufferfmt='ubyte')
        self.image.texture = image_texture
        
        # Update Labels with modern format and animation
        if self.detected_letters:
            # Animate letters label update
            detected_text = "✨ Détecté: " + " → ".join(self.detected_letters[-3:])  # Show last 3
            if self.letters_label.text != detected_text:
                self.letters_label.text = detected_text
                # Quick pulse animation - Utiliser dp() au lieu de 'sp'
                anim = Animation(font_size=dp(20), duration=0.1) + Animation(font_size=dp(18), duration=0.1)
                anim.start(self.letters_label)
        else:
            self.letters_label.text = "✨ Détecté: (en attente...)"


    def animate_detected_letter(self, letter):
        """Animate the detected letter overlay with smooth effects"""
        # Chercher un emoji correspondant
        emoji = self.WORD_TO_EMOJI.get(letter.lower(), "")
        display_text = f"{emoji} {letter}" if emoji else letter
        
        # Update text
        self.detection_label.text = display_text
        self.detection_label.size = self.detection_label.texture_size
        
        # Reset and create smooth animation sequence - Utiliser dp() au lieu de 'sp'
        self.detection_label.opacity = 0
        self.detection_label.font_size = dp(36)
        
        # Fade in + scale up
        anim1 = Animation(
            opacity=1,
            font_size=dp(64),
            duration=0.3,
            t='out_cubic'
        )
        
        # Hold
        anim2 = Animation(duration=0.8)
        
        # Fade out + scale down
        anim3 = Animation(
            opacity=0,
            font_size=dp(48),
            duration=0.4,
            t='in_cubic'
        )
        
        # Chain animations
        anim_sequence = anim1 + anim2 + anim3
        anim_sequence.start(self.detection_label)
    
    def load_translations(self):
        try:
            trans_path = get_file_path('translations.json')
            print(f"[INFO] Chargement traductions: {trans_path}")
            
            if not os.path.exists(trans_path):
                print(f"[WARNING] Fichier translations.json introuvable")
                self.translations = {}
                return
                
            with open(trans_path, 'r', encoding='utf-8') as f:
                self.translations = json.load(f)
            print(f"[OK] {len(self.translations)} traductions chargées")
        except Exception as e:
            print(f"[ERROR] Erreur chargement traductions: {e}")
            import traceback
            traceback.print_exc()
            self.translations = {}
    
    def translate(self, key):
        if key in self.translations:
            return self.translations[key].get(self.current_lang, key)
        return key
    
    def fix_text(self, text):
        """Corrige l'affichage du texte arabe (ligatures + RTL)"""
        if not text:
            return ""
        if not ARABIC_SUPPORT:
            return text  # Return as-is if libraries unavailable
        try:
            reshaped_text = arabic_reshaper.reshape(text)
            bidi_text = get_display(reshaped_text)
            return bidi_text
        except:
            return text

    def change_language(self, lang):
        self.current_lang = lang
        
        # Afficher la langue active
        lang_names = {'ar': 'العربية', 'fr': 'Français', 'en': 'English'}
        # Correction pour l'affichage du nom de la langue arabe
        lang_name_display = lang_names.get(lang, lang.upper())
        if lang == 'ar':
            lang_name_display = self.fix_text(lang_names['ar'])
            
        print(f"[INFO] Langue changée: {lang}")
        
        # Retraduire la phrase
        try:
            translated_text = ' '.join([self.translate(key) for key in self.phrase_keys])
            self.phrase_text = translated_text
            
            # Mettre à jour l'affichage avec indicateur de langue
            if lang == 'ar':
                # Pour l'arabe, utiliser Arial avec chemin absolu pour être sûr
                font_path = 'C:/Windows/Fonts/arial.ttf'
                if os.path.exists(font_path):
                    self.phrase_label.font_name = font_path
                else:
                    self.phrase_label.font_name = 'Arial' 
                    
                self.phrase_label.text = self.fix_text(f"الجملة: {self.phrase_text}")
                self.phrase_label.halign = 'right'
            else:
                # Revenir à la font par défaut Kivy
                # 'Roboto' est le nom interne de la font par défaut de Kivy
                self.phrase_label.font_name = 'Roboto' 
                self.phrase_label.text = f"Phrase ({lang_name_display}): {self.phrase_text}"
                self.phrase_label.halign = 'left'
        except Exception as e:
            print(f"[ERROR] Erreur change_language: {e}")
            # Fallback en cas d'erreur
            self.phrase_label.text = f"Phrase: {self.phrase_text}"

    def build_phrase(self, detected_letters):
        current_time = time.time()
        if not detected_letters:
            return

        if current_time - self.last_time_letter_added >= 2:
            for i, letter in enumerate(detected_letters):
                corrected_letter = self.autocorrect_letter(letter)
                self.phrase_keys.append(corrected_letter)
                self.phrase_text += self.translate(corrected_letter) + ' '
            self.last_time_letter_added = current_time
            self.phrase_label.text = "Phrase: " + self.phrase_text

    def autocorrect_letter(self, letter):
        if letter in self.correction_dict:
            possible_corrections = self.correction_dict[letter]
            most_common_correction = max(set(possible_corrections), key=possible_corrections.count)
            return most_common_correction
        else:
            return letter

    def clear_phrase(self, instance):
        self.phrase_text = ""
        self.phrase_keys = []
        self.phrase_label.text = "Phrase: "
    
    def delete_last_letter(self, instance):
        if self.phrase_keys:
            self.phrase_keys.pop()
            translated_text = ' '.join([self.translate(key) for key in self.phrase_keys])
            self.phrase_text = translated_text
            self.phrase_label.text = "Phrase: " + self.phrase_text

    def add_space(self, instance):
        self.phrase_text += " "
        self.phrase_label.text = "Phrase: " + self.phrase_text

    def speak_phrase(self, instance):
        if not self.phrase_text or self.phrase_text.strip() == "":
            print("No phrase to speak")
            return
            
        try:
            # Utiliser gTTS pour TOUTES les langues (plus fiable et meilleure qualité)
            from gtts import gTTS
            import tempfile
            from kivy.core.audio import SoundLoader
            
            # Déterminer la langue pour gTTS
            lang_map = {'ar': 'ar', 'fr': 'fr', 'en': 'en'}
            tts_lang = lang_map.get(self.current_lang, 'en')
            
            # Ralentir un peu pour l'arabe pour que ce soit plus clair
            is_slow = (tts_lang == 'ar')
            
            print(f"[INFO] Synthèse vocale ({tts_lang}) via gTTS (Lent={is_slow})...")
            tts = gTTS(text=self.phrase_text, lang=tts_lang, slow=is_slow)
            
            # Créer un fichier temporaire
            temp_file = os.path.join(tempfile.gettempdir(), 'speech.mp3')
            # Supprimer l'ancien fichier s'il existe pour éviter les conflits
            if os.path.exists(temp_file):
                try:
                    os.remove(temp_file)
                except:
                    pass
                    
            tts.save(temp_file)
            
            # Jouer le son en interne (Kivy SoundLoader)
            # Stopper le son précédent s'il tourne encore
            if hasattr(self, 'current_sound') and self.current_sound:
                self.current_sound.stop()
                
            self.current_sound = SoundLoader.load(temp_file)
            if self.current_sound:
                self.current_sound.play()
            else:
                print(f"[ERROR] Impossible de charger le son: {temp_file}")
                    
        except Exception as e:
            print(f"[ERROR] Erreur TTS: {e}")
            # Ultime secours: pyttsx3 (offline)
            try:
                import pyttsx3
                engine = pyttsx3.init()
                engine.say(self.phrase_text)
                engine.runAndWait()
            except:
                print("TTS offline aussi échoué")





    # === RECONNAISSANCE VOCALE (Restored) ===
    
    def start_voice_recognition(self, instance):
        """Démarrer la reconnaissance vocale"""
        if not self.speech_recognizer:
            print("[ERROR] Reconnaissance vocale non disponible")
            self.micro_btn.text = "NON DISPO"
            return
        
        print("[INFO] Démarrage reconnaissance vocale...")
        self.micro_btn.text = "Ecoute..."
        self.micro_btn.canvas.before.children[0].rgba = (0.95, 0.61, 0.27, 1)  # Orange
        

        
        # NOTE: On ne coupe PLUS la caméra. On peut laisser les deux tourner.
        # Ou on la coupe pour perf, mais on garde le container.
        # Le fond blanc est maintenant permanent dans self.gesture_container
        
        # Démarre l'écoute en background
        self.speech_recognizer.start_listening(self.on_speech_recognized)
    
    @mainthread
    def on_speech_recognized(self, text):
        """Callback quand un mot est reconnu (Exécuté dans Main Thread)"""
        print(f"[OK] Texte reconnu: '{text}'")
        
        # Restaurer bouton
        self.micro_btn.text = "🎤 MICRO"
        self.micro_btn.canvas.before.children[0].rgba = (0.6, 0.3, 0.9, 1)  # Violet
        
        # Nettoyer le texte
        text = text.strip().lower()
        self.phrase_label.text = f"Entendu: {text}"
        
        # 1. Chercher Geste Entier
        gesture_key = self.find_gesture_key(text)
        success = False
        
        if gesture_key:
            print(f"[INFO] Geste trouvé: {gesture_key}")
            success = self.show_gesture_image(gesture_key)
            
        if not success:
            print(f"[WARNING] Pas d'image pour: '{text}' -> Épellation...")
            # 2. Fallback: Épellation (Lettre par Lettre)
            self.show_letter_sequence(text.upper())

    def simulate_from_text(self, instance):
        """Prend le texte du champ input et joue la séquence d'images"""
        text = self.sim_input.text.strip()
        if not text:
            return
            

            
        print(f"[INFO] Simulation: {text}")
        
        # On ne touche pas à la caméra
        # On joue juste la séquence dans la zone du bas
        self.show_letter_sequence(text.upper())

    def show_letter_sequence(self, text, index=0):
        """Affiche les images lettre par lettre de manière asynchrone (Animation)"""
        if index >= len(text):
            # Fin de sequence
            return
            
        char = text[index]
        delay = 0
        
        # Si c'est une lettre valide (A-Z)
        # On suppose que labels_dict contient les lettres ou on check just isalpha
        if char.isalpha():
            # Trouver l'image pour ce char
            self.show_gesture_image(char)
            delay = 2.0 # Temps d'affichage par lettre
        elif char == ' ':
            delay = 1.0 # Pause pour espace
            
        # Programmer la prochaine lettre
        Clock.schedule_once(lambda dt: self.show_letter_sequence(text, index + 1), delay)

    def find_gesture_key(self, text):
        """Trouver la clé du geste dans translations"""
        for key, data in self.translations.items():
            if isinstance(data, dict):
                for lang, translation in data.items():
                    if translation and translation.lower() == text:
                        return key
        return None
    
    def show_gesture_image(self, key):
        """Afficher une image dans la Zone Geste dédiée"""
        try:
            image_path = get_gesture_image(key)
            if image_path:
                abs_path = os.path.abspath(image_path)
                print(f"[UI] Zone Geste: {key}")
                
                self.gesture_image.source = abs_path
                self.gesture_image.reload()
                self.gesture_image.opacity = 0
                anim = Animation(opacity=1, duration=0.2)
                anim.start(self.gesture_image)
                
                # Pas besoin d'afficher le texte - gesture_info_label supprimé
                return True
                return False
        except Exception as e:
            print(f"[ERROR] Show Image: {e}")
            return False

    def on_stop(self):
        if hasattr(self, 'capture') and self.capture:
            self.capture.release()

if __name__ == '__main__':
    HandGestureApp().run()
