import cv2
import mediapipe as mp
import numpy as np
import pickle
import time
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.image import Image
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.clock import Clock
from kivy.graphics.texture import Texture
from kivy.core.window import Window
from plyer import tts

from kivy.utils import platform
import json
from kivy.uix.textinput import TextInput

class HandGestureApp(App):
    def build(self):
        if platform == 'android':
            from android.permissions import request_permissions, Permission
            request_permissions([Permission.CAMERA, Permission.RECORD_AUDIO])

        Window.clearcolor = (0.2, 0.2, 0.2, 1)  # Dark background similar to customtkinter

        # Main Layout
        self.main_layout = BoxLayout(orientation='vertical', padding=10, spacing=10)

        # Camera Feed
        self.image = Image(size_hint=(1, 0.6))
        self.main_layout.add_widget(self.image)

        # Info Layout (Letters and Phrase)
        self.info_layout = BoxLayout(orientation='vertical', size_hint=(1, 0.2), spacing=5)
        
        self.letters_label = Label(text="Letters: ", font_size='20sp', color=(1, 1, 1, 1))
        self.info_layout.add_widget(self.letters_label)
        
        self.phrase_label = Label(text="Phrase: ", font_size='20sp', color=(1, 1, 1, 1), halign='center', valign='middle')
        self.phrase_label.bind(size=self.phrase_label.setter('text_size')) # For wrapping
        self.info_layout.add_widget(self.phrase_label)
        
        self.main_layout.add_widget(self.info_layout)

        # Buttons Layout
        self.buttons_layout = BoxLayout(orientation='horizontal', size_hint=(1, 0.2), spacing=10)
        
        self.clear_btn = Button(text="Clear", background_color=(0.8, 0.2, 0.2, 1))
        self.clear_btn.bind(on_press=self.clear_phrase)
        self.buttons_layout.add_widget(self.clear_btn)

        self.speak_btn = Button(text="Speak", background_color=(0.2, 0.8, 0.2, 1))
        self.speak_btn.bind(on_press=self.speak_phrase)
        self.buttons_layout.add_widget(self.speak_btn)

        self.delete_btn = Button(text="Delete", background_color=(0.8, 0.5, 0.2, 1))
        self.delete_btn.bind(on_press=self.delete_last_letter)
        self.buttons_layout.add_widget(self.delete_btn)

        self.space_btn = Button(text="Espace", background_color=(0.2, 0.5, 0.8, 1))
        self.space_btn.bind(on_press=self.add_space)
        self.buttons_layout.add_widget(self.space_btn)

        # Boutons de langue
        self.lang_layout = BoxLayout(orientation='horizontal', size_hint=(1, 0.1), spacing=10)
        
        self.btn_ar = Button(text="العربية", background_color=(0.3, 0.3, 0.7, 1))
        self.btn_ar.bind(on_press=lambda x: self.change_language('ar'))
        self.lang_layout.add_widget(self.btn_ar)
        
        self.btn_fr = Button(text="FR", background_color=(0.3, 0.7, 0.3, 1))
        self.btn_fr.bind(on_press=lambda x: self.change_language('fr'))
        self.lang_layout.add_widget(self.btn_fr)
        
        self.btn_en = Button(text="EN", background_color=(0.7, 0.3, 0.3, 1))
        self.btn_en.bind(on_press=lambda x: self.change_language('en'))
        self.lang_layout.add_widget(self.btn_en)
        
        self.main_layout.add_widget(self.lang_layout)
        
        # ESP32 Camera Control
        self.esp_layout = BoxLayout(orientation='horizontal', size_hint=(1, 0.1), spacing=5)
        self.ip_input = TextInput(text='192.168.1.100', multiline=False, size_hint=(0.6, 1))
        self.esp_layout.add_widget(self.ip_input)
        self.cam_btn = Button(text="Connect ESP32", size_hint=(0.4, 1), background_color=(0.2, 0.6, 0.8, 1))
        self.cam_btn.bind(on_press=self.connect_esp32)
        self.esp_layout.add_widget(self.cam_btn)
        self.main_layout.add_widget(self.esp_layout)

        self.main_layout.add_widget(self.buttons_layout)

        # Initialize Logic
        self.init_logic()

        return self.main_layout

    def init_logic(self):
        # Model
        try:
            model_dict = pickle.load(open('./model.p', 'rb'))
            self.model = model_dict['model']
        except FileNotFoundError:
            print("Error: model.p not found. Please run train_classifier.py first.")
            return

        # MediaPipe
        self.mp_hands = mp.solutions.hands
        self.mp_drawing = mp.solutions.drawing_utils
        self.mp_drawing_styles = mp.solutions.drawing_styles
        self.hands = self.mp_hands.Hands(static_image_mode=True, min_detection_confidence=0.3)

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
        
        # Charger traductions
        self.current_lang = 'fr'
        self.load_translations()

        # Camera - Utiliser DSHOW backend pour Windows (plus fiable)
        self.capture = self._init_camera()
        if not self.capture.isOpened():
            print("ERREUR: Impossible d'ouvrir la caméra!")
            return
        Clock.schedule_interval(self.update, 1.0 / 30.0) # 30 FPS
    
    def _init_camera(self):
        """Initialise la caméra avec différents backends jusqu'à trouver un qui fonctionne"""
        import time
        
        backends = [
            ("MSMF", cv2.CAP_MSMF),    # Plus stable sur Windows 10/11
            ("DSHOW", cv2.CAP_DSHOW),   # Alternative pour Windows
            ("ANY", cv2.CAP_ANY)        # Fallback
        ]
        
        for name, backend in backends:
            for index in range(2):  # Essayer index 0 et 1
                print(f"Tentative camera index={index}, backend={name}...")
                cap = cv2.VideoCapture(index, backend)
                
                if cap.isOpened():
                    # Attendre que la caméra s'initialise
                    time.sleep(0.5)
                    
                    # Tester plusieurs lectures pour s'assurer que ça fonctionne
                    success_count = 0
                    for _ in range(3):
                        ret, frame = cap.read()
                        if ret and frame is not None:
                            success_count += 1
                        time.sleep(0.1)
                    
                    if success_count >= 2:  # Au moins 2/3 réussies
                        print(f"✓ Caméra trouvée: index={index}, backend={name} ({success_count}/3 lectures réussies)")
                        return cap
                    
                cap.release()
        
        # Fallback: essayer sans backend spécifique
        print("Tentative avec configuration par défaut...")
        return cv2.VideoCapture(0)

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
                self.cam_btn.text = "ESP32 Connecté"
                self.cam_btn.background_color = (0.2, 0.8, 0.2, 1)
                print("✓ Connexion ESP32 réussie!")
            else:
                print("❌ Impossible de lire le flux ESP32")
                new_cap.release()
        else:
            print("❌ Impossible d'ouvrir l'URL ESP32")


    def update(self, dt):
        # Anti-blocage: compteur d'erreurs
        if not hasattr(self, '_consecutive_errors'):
            self._consecutive_errors = 0
            
        ret, frame = self.capture.read()
        if not ret or frame is None:
            self._consecutive_errors += 1
            if self._consecutive_errors >= 30:  # ~1 seconde d'erreurs
                print("❌ Trop d'erreurs consécutives. Tentative de reconnexion...")
                self.capture.release()
                import time
                time.sleep(1)
                self.capture = self._init_camera()
                self._consecutive_errors = 0
            return
        
        # Réinitialiser le compteur si lecture réussie
        self._consecutive_errors = 0

        H, W, _ = frame.shape
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # MediaPipe Processing
        data_aux = []
        x_ = []
        y_ = []
        self.detected_letters = [] # Reset for this frame
        
        results = self.hands.process(frame_rgb)
        
        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                self.mp_drawing.draw_landmarks(
                    frame, hand_landmarks, self.mp_hands.HAND_CONNECTIONS,
                    self.mp_drawing_styles.get_default_hand_landmarks_style(),
                    self.mp_drawing_styles.get_default_hand_connections_style())

            # Prediction Logic (Same as original)
            for hand_landmarks in results.multi_hand_landmarks:
                for i in range(len(hand_landmarks.landmark)):
                    x = hand_landmarks.landmark[i].x
                    y = hand_landmarks.landmark[i].y
                    x_.append(x)
                    y_.append(y)

                for i in range(len(hand_landmarks.landmark)):
                    x = hand_landmarks.landmark[i].x
                    y = hand_landmarks.landmark[i].y
                    data_aux.append(x - min(x_))
                    data_aux.append(y - min(y_))
            
            # Pad or truncate data_aux to expected 42 features
            # NOTE: Simple fix to match inference shape expectations if user hasn't fully fixed dataset yet
            # But relying on correct dataset is better.
            if len(data_aux) == 42:
                try:
                    prediction = self.model.predict([np.asarray(data_aux)])
                    predicted_character = self.labels_dict[int(prediction[0])]
                    self.detected_letters.append(predicted_character)
                except Exception as e:
                    print(f"Prediction error: {e}")

            # Draw UI
            x1 = int(min(x_) * W) - 10
            y1 = int(min(y_) * H) - 10
            x2 = int(max(x_) * W) - 10
            y2 = int(max(y_) * H) - 10

            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 0, 0), 4)
            if self.detected_letters:
                 cv2.putText(frame, self.detected_letters[0], (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 1.3, (0, 0, 0), 3, cv2.LINE_AA)

            # Build Phrase
            self.build_phrase(self.detected_letters)


        # Update Kivy Image
        buf1 = cv2.flip(frame, 0)
        buf = buf1.tostring()
        image_texture = Texture.create(size=(frame.shape[1], frame.shape[0]), colorfmt='bgr')
        image_texture.blit_buffer(buf, colorfmt='bgr', bufferfmt='ubyte')
        self.image.texture = image_texture
        
        # Update Labels
        self.letters_label.text = "Letters: " + " ".join(self.detected_letters)


    def load_translations(self):
        try:
            with open('./translations.json', 'r', encoding='utf-8') as f:
                self.translations = json.load(f)
        except Exception as e:
            print(f"Translation load error: {e}")
            self.translations = {}
    
    def translate(self, key):
        if key in self.translations:
            return self.translations[key].get(self.current_lang, key)
        return key
    
    def change_language(self, lang):
        self.current_lang = lang
        # Retraduire la phrase
        translated_text = ' '.join([self.translate(key) for key in self.phrase_keys])
        self.phrase_text = translated_text
        self.phrase_label.text = "Phrase: " + self.phrase_text

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
            tts.speak(self.phrase_text)
        except NotImplementedError:
            # Fallback purely for PC testing if plyer tts fails
            try:
                import pyttsx3
                engine = pyttsx3.init()
                engine.say(self.phrase_text)
                engine.runAndWait()
            except:
                print("TTS not supported")

    def on_stop(self):
        self.capture.release()

if __name__ == '__main__':
    HandGestureApp().run()
