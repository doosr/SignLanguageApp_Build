import cv2
import numpy as np
import pickle
import time
import json
import os
from collections import Counter

# Kivy imports - same as main.py
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.image import Image
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.clock import Clock
from kivy.graphics.texture import Texture
from kivy.core.window import Window
from kivy.animation import Animation
from kivy.graphics import Color, RoundedRectangle
from kivy.metrics import dp

# MediaPipe and other imports
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import mediapipe as mp

# TTS
try:
    from plyer import tts
    TTS_AVAILABLE = True
except:
    TTS_AVAILABLE = False

class InferenceApp(App):
    def build(self):
        # Modern gradient background - same as main.py
        Window.clearcolor = (0.05, 0.05, 0.1, 1)
        
        # Main Layout
        self.main_layout = BoxLayout(orientation='vertical', padding=dp(15), spacing=dp(12))
        
        # Camera Feed Container
        self.camera_container = FloatLayout(size_hint=(1, 0.55))
        self.image = Image(size_hint=(1, 1))
        self.camera_container.add_widget(self.image)
        
        # Detection overlay
        self.detection_label = Label(
            text="",
            font_size='48sp',
            bold=True,
            color=(0.2, 0.8, 1, 0),
            size_hint=(None, None),
            pos_hint={'center_x': 0.5, 'center_y': 0.5}
        )
        self.camera_container.add_widget(self.detection_label)
        self.main_layout.add_widget(self.camera_container)
        
        # Info Card
        self.info_card = BoxLayout(
            orientation='vertical',
            size_hint=(1, 0.18),
            spacing=dp(8),
            padding=dp(15)
        )
        
        with self.info_card.canvas.before:
            Color(0.12, 0.15, 0.22, 1)
            self.info_card_bg = RoundedRectangle(
                size=self.info_card.size,
                pos=self.info_card.pos,
                radius=[dp(15)]
            )
        self.info_card.bind(size=self._update_card_bg, pos=self._update_card_bg)
        
        # Mode label
        self.mode_label = Label(
            text="Mode: MOTS 🔤",
            font_size='16sp',
            color=(0.95, 0.61, 0.27, 1),
            bold=True,
            halign='left',
            valign='middle'
        )
        self.mode_label.bind(size=self.mode_label.setter('text_size'))
        self.info_card.add_widget(self.mode_label)
        
        # Phrase Label
        self.phrase_label = Label(
            text="Phrase: ",
            font_size='22sp',
            color=(1, 1, 1, 1),
            bold=True,
            halign='center',
            valign='middle'
        )
        self.phrase_label.bind(size=self.phrase_label.setter('text_size'))
        self.info_card.add_widget(self.phrase_label)
        
        self.main_layout.add_widget(self.info_card)
        
        # Action Buttons
        self.buttons_layout = BoxLayout(
            orientation='horizontal',
            size_hint=(1, 0.12),
            spacing=dp(10)
        )
        
        self.mode_btn = self._create_modern_button(
            "🔄 Mode",
            (0.95, 0.27, 0.33, 1),
            self.toggle_mode
        )
        self.buttons_layout.add_widget(self.mode_btn)
        
        self.clear_btn = self._create_modern_button(
            "🗑️ Effacer",
            (0.95, 0.27, 0.33, 1),
            self.clear_phrase
        )
        self.buttons_layout.add_widget(self.clear_btn)
        
        self.speak_btn = self._create_modern_button(
            "🔊 Parler",
            (0.26, 0.67, 0.45, 1),
            self.speak_phrase
        )
        self.buttons_layout.add_widget(self.speak_btn)
        
        self.delete_btn = self._create_modern_button(
            "⬅️ Retour",
            (0.95, 0.61, 0.27, 1),
            self.delete_last_letter
        )
        self.buttons_layout.add_widget(self.delete_btn)
        
        self.space_btn = self._create_modern_button(
            "␣ Espace",
            (0.27, 0.54, 0.95, 1),
            self.add_space
        )
        self.buttons_layout.add_widget(self.space_btn)
        
        self.main_layout.add_widget(self.buttons_layout)
        
        # Language Selector
        self.lang_layout = BoxLayout(
            orientation='horizontal',
            size_hint=(1, 0.08),
            spacing=dp(10)
        )
        
        self.btn_ar = self._create_lang_button(
            "🇦🇪 AR",
            (0.5, 0.4, 0.85, 1),
            lambda x: self.change_language('ar')
        )
        self.lang_layout.add_widget(self.btn_ar)
        
        self.btn_fr = self._create_lang_button(
            "🇫🇷 FR",
            (0.4, 0.6, 0.95, 1),
            lambda x: self.change_language('fr')
        )
        self.lang_layout.add_widget(self.btn_fr)
        
        self.btn_en = self._create_lang_button(
            "🇬🇧 EN",
            (0.95, 0.5, 0.5, 1),
            lambda x: self.change_language('en')
        )
        self.lang_layout.add_widget(self.btn_en)
        
        self.main_layout.add_widget(self.lang_layout)
        
        # Initialize Logic
        self.init_logic()
        
        return self.main_layout
    
    def _update_card_bg(self, instance, value):
        self.info_card_bg.size = instance.size
        self.info_card_bg.pos = instance.pos
    
    def _create_modern_button(self, text, color, callback, size_hint=(0.2, 1)):
        btn = Button(
            text=text,
            size_hint=size_hint,
            background_color=(0, 0, 0, 0),
            font_size='15sp',
            bold=True,
            color=(1, 1, 1, 1)
        )
        
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
        return self._create_modern_button(text, color, callback, size_hint=(0.33, 1))
    
    def init_logic(self):
        print("[INFO] Initialisation...")
        
        # Load models
        try:
            with open('model.p', 'rb') as f:
                self.model_static = pickle.load(f)['model']
            print("[OK] Modèle statique chargé")
        except:
            print("[ERROR] model.p introuvable")
            self.model_static = None
        
        try:
            with open('model_sequence.p', 'rb') as f:
                self.model_sequence = pickle.load(f)['model']
            print("[OK] Modèle séquence chargé")
        except:
            print("[ERROR] model_sequence.p introuvable")
            self.model_sequence = None
        
        # MediaPipe
        try:
            base_options = python.BaseOptions(model_asset_path='hand_landmarker.task')
            options = vision.HandLandmarkerOptions(
                base_options=base_options,
                running_mode=vision.RunningMode.IMAGE,
                num_hands=2,
                min_hand_detection_confidence=0.3,
                min_hand_presence_confidence=0.3,
                min_tracking_confidence=0.3
            )
            self.detector = vision.HandLandmarker.create_from_options(options)
            print("[OK] MediaPipe initialisé")
        except Exception as e:
            print(f"[ERROR] MediaPipe: {e}")
            self.detector = None
        
        # State
        self.detection_mode = "MOTS"
        self.phrase_text = ""
        self.phrase_keys = []
        self.last_time_added = time.time()
        self.frame_buffer = []
        self.SEQUENCE_LENGTH = 15
        self.candidate_history = []
        
        # Translations
        self.load_translations()
        self.current_lang = 'fr'
        
        # Camera
        print("[INFO] Initialisation caméra...")
        self.capture = self._init_camera()
        if self.capture and self.capture.isOpened():
            print("[OK] Caméra prête")
            Clock.schedule_interval(self.update, 1.0 / 30.0)
        else:
            print("[WARNING] Caméra non disponible")
    
    def _init_camera(self):
        backends = [
            ("MSMF", cv2.CAP_MSMF),
            ("DSHOW", cv2.CAP_DSHOW),
            ("ANY", cv2.CAP_ANY)
        ]
        
        for name, backend in backends:
            for index in range(3):
                try:
                    cap = cv2.VideoCapture(index, backend)
                    if cap.isOpened():
                        time.sleep(0.3)
                        ret, frame = cap.read()
                        if ret and frame is not None:
                            print(f"[OK] Caméra {index} - {name}")
                            return cap
                        cap.release()
                except:
                    continue
        return None
    
    def update(self, dt):
        if not self.capture or not self.detector:
            return
        
        ret, frame = self.capture.read()
        if not ret or frame is None:
            return
        
        H, W, _ = frame.shape
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
        
        results = self.detector.detect(mp_image)
        
        detected_character = None
        prediction_source = None
        
        if results.hand_landmarks:
            sorted_hands = sorted(results.hand_landmarks, key=lambda h: h[0].x)
            
            data_aux = []
            x_ = []
            y_ = []
            
            for hand_landmarks in sorted_hands:
                for landmark in hand_landmarks:
                    x_.append(landmark.x)
                    y_.append(landmark.y)
            
            if x_ and y_:
                min_x, min_y = min(x_), min(y_)
                for hand_landmarks in sorted_hands:
                    for landmark in hand_landmarks:
                        data_aux.append(landmark.x - min_x)
                        data_aux.append(landmark.y - min_y)
                
                # Pad to 84 features
                if len(data_aux) == 42:
                    data_aux.extend([0.0] * 42)
                
                if len(data_aux) == 84:
                    # Sequence prediction (MOTS)
                    if self.detection_mode == "MOTS" and self.model_sequence:
                        self.frame_buffer.append(data_aux)
                        if len(self.frame_buffer) > self.SEQUENCE_LENGTH:
                            self.frame_buffer.pop(0)
                        
                        if len(self.frame_buffer) == self.SEQUENCE_LENGTH:
                            seq_input = np.array(self.frame_buffer).flatten()
                            seq_probs = self.model_sequence.predict_proba([seq_input])[0]
                            max_prob = np.max(seq_probs)
                            idx = np.argmax(seq_probs)
                            candidate = self.model_sequence.classes_[idx]
                            
                            self.candidate_history.append(candidate)
                            if len(self.candidate_history) > 10:
                                self.candidate_history.pop(0)
                            
                            counts = Counter(self.candidate_history)
                            most_common, frequency = counts.most_common(1)[0]
                            
                            if most_common == candidate and frequency >= 5 and max_prob > 0.15:
                                if not (self.phrase_keys and self.phrase_keys[-1] == candidate and (time.time() - self.last_time_added < 2.0)):
                                    detected_character = candidate
                                    prediction_source = "WORD"
                                    self.candidate_history = []
                    
                    # Static prediction (LETTRES)
                    if self.detection_mode == "LETTRES" and self.model_static and not detected_character:
                        static_probs = self.model_static.predict_proba([np.asarray(data_aux)])[0]
                        if np.max(static_probs) > 0.4:
                            idx = np.argmax(static_probs)
                            detected_character = self.model_static.classes_[idx]
                            prediction_source = "LETTER"
                    
                    if detected_character:
                        self.animate_detected_letter(detected_character)
                        self.build_phrase(detected_character)
                        
                        # Draw box
                        x1, y1 = int(min(x_) * W) - 10, int(min(y_) * H) - 10
                        x2, y2 = int(max(x_) * W) + 10, int(max(y_) * H) + 10
                        color = (50, 200, 255) if prediction_source == "WORD" else (255, 255, 0)
                        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 3)
                        cv2.putText(frame, detected_character, (x1, y1 - 10),
                                    cv2.FONT_HERSHEY_SIMPLEX, 1.3, color, 3, cv2.LINE_AA)
        
        # Update texture
        buf1 = cv2.flip(frame, 0)
        buf = buf1.tobytes()
        texture = Texture.create(size=(frame.shape[1], frame.shape[0]), colorfmt='bgr')
        texture.blit_buffer(buf, colorfmt='bgr', bufferfmt='ubyte')
        self.image.texture = texture
    
    def animate_detected_letter(self, letter):
        self.detection_label.text = letter
        self.detection_label.size = self.detection_label.texture_size
        self.detection_label.opacity = 0
        self.detection_label.font_size = '36sp'
        
        anim1 = Animation(opacity=1, font_size='64sp', duration=0.3, t='out_cubic')
        anim2 = Animation(duration=0.8)
        anim3 = Animation(opacity=0, font_size='48sp', duration=0.4, t='in_cubic')
        
        (anim1 + anim2 + anim3).start(self.detection_label)
    
    def load_translations(self):
        try:
            with open('translations.json', 'r', encoding='utf-8') as f:
                self.translations = json.load(f)
        except:
            self.translations = {}
    
    def translate(self, key):
        if key in self.translations:
            return self.translations[key].get(self.current_lang, key)
        return key
    
    def get_emoji(self, key):
        if key in self.translations:
            return self.translations[key].get("emoji")
        return None
    
    def build_phrase(self, detected_item):
        now = time.time()
        if now - self.last_time_added < 1.5:
            return
        
        emoji = self.get_emoji(detected_item)
        
        # Filter based on mode
        if self.detection_mode == "MOTS" and not emoji:
            return
        if self.detection_mode == "LETTRES" and emoji:
            return
        
        self.phrase_keys.append(detected_item)
        self.last_time_added = now
        self.update_phrase_ui()
    
    def update_phrase_ui(self):
        self.phrase_text = " ".join([self.translate(k) for k in self.phrase_keys])
        self.phrase_label.text = "Phrase: " + self.phrase_text
    
    def toggle_mode(self, instance):
        if self.detection_mode == "MOTS":
            self.detection_mode = "LETTRES"
            self.mode_label.text = "Mode: LETTRES 🔤"
            self.mode_label.color = (0.26, 0.67, 0.45, 1)
        else:
            self.detection_mode = "MOTS"
            self.mode_label.text = "Mode: MOTS 📚"
            self.mode_label.color = (0.95, 0.61, 0.27, 1)
        self.frame_buffer = []
        self.candidate_history = []
    
    def change_language(self, lang):
        self.current_lang = lang
        self.update_phrase_ui()
    
    def clear_phrase(self, instance):
        self.phrase_keys = []
        self.update_phrase_ui()
    
    def delete_last_letter(self, instance):
        if self.phrase_keys:
            self.phrase_keys.pop()
            self.update_phrase_ui()
    
    def add_space(self, instance):
        self.phrase_keys.append(" ")
        self.update_phrase_ui()
    
    def speak_phrase(self, instance):
        if not self.phrase_text or not TTS_AVAILABLE:
            return
        try:
            tts.speak(self.phrase_text)
        except:
            print("TTS not available")
    
    def on_stop(self):
        if self.capture:
            self.capture.release()

if __name__ == '__main__':
    InferenceApp().run()
