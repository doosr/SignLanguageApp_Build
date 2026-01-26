import cv2
import numpy as np
import customtkinter
from customtkinter import *
from tkinter import *
from tkinter import ttk
from PIL import Image, ImageTk
import threading
import pickle
import pyttsx3
import time
import json
import os
import queue
from collections import Counter

# Use MediaPipe Tasks API (compatible with 0.10.x)
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import mediapipe as mp

# Audio additions
from gtts import gTTS
from pygame import mixer
import tempfile

# Voice to Gesture imports
from speech_to_gesture import create_speech_recognizer
from gesture_display_utils import get_gesture_image


class TTSThread(threading.Thread):
    def __init__(self):
        super().__init__(daemon=True)
        self.queue = queue.Queue()
        self.running = True
        self.start()

    def run(self):
        while self.running:
            try:
                # Attendre une phrase à dire
                text, lang = self.queue.get()
                if text is None: break # Signal d'arrêt

                # --- 1. Tentative avec gTTS pour l'Arabe (Qualité Supérieure) ---
                if lang == 'ar':
                    try:
                        print(f"🎙️ Generating gTTS Arabic Audio for: {text}")
                        tts = gTTS(text=text, lang='ar')
                        with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as f:
                            temp_filename = f.name
                        
                        tts.save(temp_filename)
                        
                        # Utiliser pygame pour jouer le MP3
                        mixer.init()
                        mixer.music.load(temp_filename)
                        mixer.music.play()
                        while mixer.music.get_busy() and self.running:
                            time.sleep(0.1)
                        mixer.music.stop()
                        mixer.quit()
                        
                        # Nettoyage
                        if os.path.exists(temp_filename):
                            os.remove(temp_filename)
                        
                        self.queue.task_done()
                        continue # Passer à la suite (don't use pyttsx3)
                    except Exception as ge:
                        print(f"⚠️ gTTS Error: {ge}, switching to pyttsx3 fallback")

                # --- 2. Fallback pyttsx3 (Français, Anglais, ou Arabe local si dispo) ---
                try:
                    engine = pyttsx3.init()
                    voices = engine.getProperty('voices')
                    found_voice = False
                    for voice in voices:
                        lang_target = "french"
                        if lang == 'en': lang_target = "english"
                        if lang == 'ar': lang_target = "arabic"
                        
                        if lang_target in voice.name.lower():
                            engine.setProperty('voice', voice.id)
                            found_voice = True
                            break
                    
                    # Si aucune voix arabe n'est trouvée et qu'on est en AR, on tente une voix par défaut
                    # mais gTTS aurait dû fonctionner normalement.
                    
                    engine.setProperty('rate', 140)
                    engine.say(text)
                    engine.runAndWait()
                    engine.stop()
                    del engine
                except Exception as e:
                    print(f"⚠️ TTS Inner Error: {e}")
                
                self.queue.task_done()
            except Exception as e:
                print(f"⚠️ Thread Error: {e}")

    def say(self, text, lang='fr'):
        self.queue.put((text, lang))

    def stop(self):
        self.queue.put((None, None))


class Camera:
    def __init__(self, label, letters_label, interface):
        self.camera_open = True
        self.label = label
        self.letters_label = letters_label
        self.interface = interface
        self.paused = False # Flag pour mettre en pause la caméra (ex: mode vocal)
        
        # Initialize hand landmarker using Tasks API
        base_options = python.BaseOptions(model_asset_path='hand_landmarker.task')
        options = vision.HandLandmarkerOptions(
            base_options=base_options,
            running_mode=vision.RunningMode.IMAGE,
            num_hands=2,
            min_hand_detection_confidence=0.3, # Match create_dataset (was 0.5)
            min_hand_presence_confidence=0.3, # Match create_dataset (was 0.5)
            min_tracking_confidence=0.3       # Match create_dataset (was 0.5)
        )
        self.detector = vision.HandLandmarker.create_from_options(options)
        
        # Buffers for synchronization and prediction
        self.detected_letters = []
        self.frame_buffer = [] # Buffer for sequence recognition
        self.SEQUENCE_LENGTH = 15 # Match create_dataset.py
        
        # Initialiser la caméra avec fallback automatique
        self.cap = self._init_camera()
        if not self.cap.isOpened():
            print("⚠️  WARNING: Caméra non disponible. L'application démarrera sans caméra.")
            self.camera_available = False
        else:
            self.camera_available = True
            print("✅ Caméra initialisée avec succès")
    
    def _init_camera(self):
        """Initialise la caméra avec différents backends jusqu'à trouver un qui fonctionne"""
        import time
        backends = [("MSMF", cv2.CAP_MSMF), ("DSHOW", cv2.CAP_DSHOW), ("ANY", cv2.CAP_ANY)]
        
        for name, backend in backends:
            for index in [0, 1, 2]: # Try 0, 1, and 2
                cap = cv2.VideoCapture(index, backend)
                if cap.isOpened():
                    time.sleep(0.3)
                    ret, frame = cap.read()
                    if ret and frame is not None:
                        print(f"✅ Caméra trouvée: Index {index} avec Backend {name}")
                        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                        return cap
                    cap.release()
        return cv2.VideoCapture(0) # Ultimate fallback

    def open_camera_thread(self):
        import time
        while self.camera_open:
            try:
                # Si en pause (ex: affichage image vocale), on attend
                if self.paused:
                    time.sleep(0.1)
                    continue
                    
                data_aux = []
                x_ = []
                y_ = []
                self.detected_letters = []
                
                ret, frame = self.cap.read()
                if not ret or frame is None:
                    time.sleep(0.01)
                    continue
                
                H, W, _ = frame.shape
                frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
                
                results = self.detector.detect(mp_image)

                if results.hand_landmarks:
                    # FIX: SORT HANDS Left-to-Right to match training data
                    sorted_hands = sorted(results.hand_landmarks, key=lambda h: h[0].x)
                    
                    for hand_landmarks in sorted_hands:
                        for landmark in hand_landmarks:
                            x_px = int(landmark.x * W)
                            y_px = int(landmark.y * H)
                            cv2.circle(frame, (x_px, y_px), 5, (0, 255, 0), -1)
                        
                        for landmark in hand_landmarks:
                            x_.append(landmark.x)
                            y_.append(landmark.y)

                    if x_ and y_:
                        min_x = min(x_)
                        min_y = min(y_)
                        for hand_landmarks in sorted_hands:
                            for landmark in hand_landmarks:
                                data_aux.append(landmark.x - min_x)
                                data_aux.append(landmark.y - min_y)

                        if len(data_aux) == 42:
                            data_aux.extend([0.0] * 42)
                        
                        if len(data_aux) == 84:
                            # 1. Update rolling buffer for Words
                            self.frame_buffer.append(data_aux)
                            if len(self.frame_buffer) > self.SEQUENCE_LENGTH:
                                self.frame_buffer.pop(0)
                            
                            prediction_source = None
                            predicted_character = None
                            
                            # 2. Sequence Prediction (Words - Priority)
                            # EXECUTÉ SEULEMENT SI LE MODE EST "MOTS"
                            if self.interface.detection_mode == "MOTS":
                                if len(self.frame_buffer) == self.SEQUENCE_LENGTH:
                                    seq_input = np.array(self.frame_buffer).flatten()
                                    seq_probs = self.interface.model_sequence.predict_proba([seq_input])[0]
                                    max_prob = np.max(seq_probs)
                                    idx = np.argmax(seq_probs)
                                    candidate = self.interface.model_sequence.classes_[idx]
                                    
                                    # --- DEBUG: PROUVER LA COMPARAISON ---
                                    print(f"🔍 Analyzing Sequence... Top Candidate: '{candidate}' (Confidence: {max_prob:.2f})")
                                    
                                    # --- LOGIC OPTIMISÉE (VOTE GLISSANT) ---
                                    # Au lieu de compter les frames consécutives (fragile), on regarde l'historique
                                    if not hasattr(self, 'candidate_history'):
                                        self.candidate_history = []
                                    
                                    self.candidate_history.append(candidate)
                                    if len(self.candidate_history) > 10: # Garder les 10 derniers resultats
                                        self.candidate_history.pop(0)

                                    # Compter les votes dans l'historique
                                    counts = Counter(self.candidate_history)
                                    most_common, frequency = counts.most_common(1)[0]
                                    
                                    # CRITÈRE DE VALIDATION :
                                    # 1. Le mot est majoritaire dans les 10 dernières images (au moins 5 fois)
                                    # 2. La confiance actuelle est au moins > 0.15 (très permissif)
                                    if most_common == candidate and frequency >= 5 and max_prob > 0.15:
                                        # Anti-spam: ne pas répéter le même mot instantanément
                                        if self.interface.phrase_keys and self.interface.phrase_keys[-1] == candidate and (time.time() - self.interface.last_time_added < 2.0):
                                            pass
                                        else:
                                            predicted_character = candidate
                                            prediction_source = "WORD"
                                            self.candidate_history = [] # Reset après validation
                                            print(f"✅ VOTE VALIDATED: {candidate} (Freq: {frequency}/10 | Score: {max_prob:.2f})")

                            # 3. Static Prediction (Letters - Fallback)
                            # EXECUTÉ SEULEMENT SI LE MODE EST "LETTRES" 
                            # (OU si on veut un fallback "hybrid" - mais l'utilisateur a demandé strict)
                            if self.interface.detection_mode == "LETTRES":
                                # Seulement si on n'est pas en train de détecter un mot probable
                                word_confidence = max_prob if 'max_prob' in locals() else 0
                                
                                if not prediction_source:
                                    static_probs = self.interface.model_static.predict_proba([np.asarray(data_aux)])[0]
                                    if np.max(static_probs) > 0.4: # Seuil réduit pour capter plus de lettres
                                        idx = np.argmax(static_probs)
                                        predicted_character = self.interface.model_static.classes_[idx]
                                        prediction_source = "LETTER"

                            if predicted_character:
                                print(f"Detected {prediction_source}: {predicted_character}")
                                self.detected_letters.append(predicted_character)
                                
                                x1, y1 = int(min(x_) * W) - 10, int(min(y_) * H) - 10
                                x2, y2 = int(max(x_) * W) + 10, int(max(y_) * H) + 10
                                color = (255, 0, 0) if prediction_source == "WORD" else (0, 0, 0)
                                
                                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 4)
                                cv2.putText(frame, predicted_character, (x1, y1 - 10), 
                                            cv2.FONT_HERSHEY_SIMPLEX, 1.3, color, 3, cv2.LINE_AA)

                                self.interface.build_phrase(self.detected_letters)

                    # --- DEBUG VISUEL : Afficher l'état du buffer ---
                    # Cela permet de voir si le système "enregistre" bien la séquence
                    cv2.putText(frame, f"Seq Buffer: {len(self.frame_buffer)}/{self.SEQUENCE_LENGTH}", (10, 30), 
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                    
                    if len(self.frame_buffer) == self.SEQUENCE_LENGTH:
                         cv2.putText(frame, "READY", (250, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

                frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                frame = Image.fromarray(frame)
                frame = ImageTk.PhotoImage(image=frame)
                self.label.config(image=frame)
                self.label.image = frame
                self.letters_label.config(text=" ".join(self.detected_letters))

                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
            except Exception as e:
                print(f"⚠️ Error: {e}")
                time.sleep(0.1)

        self.cap.release()
        cv2.destroyAllWindows()



class InterfaceUtilisateur:
    def __init__(self, fenetre, model_static, model_sequence):
        self.tts = TTSThread() # Démarrer le thread audio dédié
        
        self.fenetre = fenetre
        self.fenetre.geometry('1280x720')
        self.fenetre.title('Sign Language Hybrid Recognition')
        self.fenetre['bg'] = '#E2E9C0'
        self.load_translations()
        self.current_lang = 'fr'
        
        # Initialisation reconnaissance vocale
        try:
            self.speech_recognizer = create_speech_recognizer(self.current_lang)
            print("✅ Reconnaissance vocale initialisée")
        except Exception as e:
            print(f"⚠️ Reconnaissance vocale erreur: {e}")
            self.speech_recognizer = None
        
        # Design UI
        self.frame_gauche = Frame(self.fenetre, bg='#313131')
        self.frame_gauche.place(relx=0, rely=0, relwidth=0.7, relheight=1)
        self.frame_droite = Frame(self.fenetre, bg='#282828')
        self.frame_droite.place(relx=0.7, rely=0, relwidth=0.3, relheight=1)

        self.camera_label = Label(self.frame_gauche, bg='#e5ddde', relief=SOLID)
        self.camera_label.place(x=0, y=0, width=620, height=420)
        
        self.suggestion_button = Button(self.frame_gauche, text="", font=("Segoe UI Emoji", 40), 
                                        bg="#313131", fg="white", borderwidth=0, 
                                        command=self.confirm_suggestion)
        self.pending_word_key = None

        self.label_phrase = Label(self.frame_gauche, text="Phrase : ", bg="#313131",
                                  font=("Helvitica", 14, "bold"), wraplength=800, fg="#e5ddde", justify=LEFT)
        self.label_phrase.place(relx=0.02, rely=0.80)

        self.letters_label = Label(self.frame_gauche, text="", bg='#313131', font=("Helvitica", 12), fg="#e5ddde")
        self.letters_label.place(relx=0.05, rely=0.70)

        # Buttons
        self.detection_mode = "MOTS" # Default mode
        self.btn_mode = customtkinter.CTkButton(self.frame_droite, text="Mode: MOTS", command=self.toggle_mode, fg_color="#E91E63", hover_color="#D81B60")
        self.btn_mode.place(relx=0.5, rely=0.1, anchor=CENTER)

        customtkinter.CTkButton(self.frame_droite, text="Clear", command=self.clear_interface).place(relx=0.5, rely=0.2, anchor=CENTER)
        customtkinter.CTkButton(self.frame_droite, text="Audio", command=self.speak_phrase).place(relx=0.5, rely=0.4, anchor=CENTER)
        customtkinter.CTkButton(self.frame_droite, text="DEL", command=self.delete_letter).place(relx=0.5, rely=0.6, anchor=CENTER)
        customtkinter.CTkButton(self.frame_droite, text="Espace", command=self.add_space).place(relx=0.5, rely=0.8, anchor=CENTER)

        # Language Buttons
        self.bouton_fr = customtkinter.CTkButton(self.frame_droite, text="FR", width=60, command=lambda: self.change_language('fr'))
        self.bouton_fr.place(relx=0.2, rely=0.95, anchor=CENTER)
        self.bouton_en = customtkinter.CTkButton(self.frame_droite, text="EN", width=60, command=lambda: self.change_language('en'))
        self.bouton_en.place(relx=0.5, rely=0.95, anchor=CENTER)
        self.bouton_ar = customtkinter.CTkButton(self.frame_droite, text="AR", width=60, command=lambda: self.change_language('ar'))
        self.bouton_ar.place(relx=0.8, rely=0.95, anchor=CENTER)

        # Bouton MICRO (Voice to Gesture)
        self.btn_micro = customtkinter.CTkButton(self.frame_droite, text="MICRO 🎤", command=self.start_voice_recognition, fg_color="#9C27B0", hover_color="#7B1FA2")
        self.btn_micro.place(relx=0.5, rely=0.7, anchor=CENTER)

        self.model_static = model_static
        self.model_sequence = model_sequence

        self.camera = Camera(self.camera_label, self.letters_label, self)
        threading.Thread(target=self.camera.open_camera_thread, daemon=True).start()

        self.phrase_text = ""
        self.phrase_keys = []
        self.last_time_added = time.time()

    def toggle_mode(self):
        if self.detection_mode == "MOTS":
            self.detection_mode = "LETTRES"
            self.btn_mode.configure(text="Mode: LETTRES", fg_color="#4CAF50", hover_color="#388E3C")
            self.camera.frame_buffer = [] # Reset buffer
        else:
            self.detection_mode = "MOTS"
            self.btn_mode.configure(text="Mode: MOTS", fg_color="#E91E63", hover_color="#D81B60")
            self.camera.frame_buffer = []

    def load_translations(self):
        try:
            with open('translations.json', 'r', encoding='utf-8') as f:
                self.translations = json.load(f)
        except: self.translations = {}
    
    def translate(self, key):
        if key in self.translations: return self.translations[key].get(self.current_lang, key)
        return key
    
    def get_emoji(self, key):
        if key in self.translations: return self.translations[key].get("emoji")
        return None

    def build_phrase(self, detected_items):
        now = time.time()
        if now - self.last_time_added < 1.5: return # Cooldown

        for item in detected_items:
            emoji = self.get_emoji(item)
            
            # FILTRE STRICT SELON LE MODE
            if self.detection_mode == "MOTS" and not emoji:
                 continue # Ignorer les lettres en mode MOTS
            
            if self.detection_mode == "LETTRES" and emoji:
                 continue # Ignorer les mots en mode LETTRES (sécurité)

            if emoji: # C'est un MOT
                self.pending_word_key = item
                self.suggestion_button.config(text=emoji)
                self.suggestion_button.place(relx=0.5, rely=0.5, anchor=CENTER)
                self.last_time_added = now
            else: # C'est une LETTRE
                self.phrase_keys.append(item)
                self.last_time_added = now
                self.suggestion_button.place_forget()
                self.update_ui()

    def confirm_suggestion(self):
        if self.pending_word_key:
            self.phrase_keys.append(self.pending_word_key)
            self.suggestion_button.place_forget()
            self.pending_word_key = None
            self.last_time_added = time.time()
            self.update_ui()

    def update_ui(self):
        self.phrase_text = " ".join([self.translate(k) for k in self.phrase_keys])
        
        # Amélioration RTL pour l'Arabe
        if self.current_lang == 'ar':
            self.label_phrase.config(justify=RIGHT)
            # Alignment à droite pour l'arabe
            self.label_phrase.place(relx=0.98, rely=0.80, anchor=NE)
        else:
            self.label_phrase.config(justify=LEFT)
            self.label_phrase.place(relx=0.02, rely=0.80, anchor=NW)

        phrase_wrapped = [self.phrase_text[i:i + 50] for i in range(0, len(self.phrase_text), 50)]
        self.label_phrase.config(text="Phrase : " + "\n".join(phrase_wrapped))

    def change_language(self, lang):
        self.current_lang = lang
        self.update_ui()

    def clear_interface(self):
        self.phrase_keys = []
        self.update_ui()
        self.suggestion_button.place_forget()
        # TTS thread ne s'arrête pas, il attend juste la prochaine commande

    def delete_letter(self):
        if self.phrase_keys: self.phrase_keys.pop(); self.update_ui()

    def add_space(self):
        self.phrase_keys.append(" "); self.update_ui()

    def speak_phrase(self):
        if not self.phrase_text or self.phrase_text.strip() == "":
            print("⚠️ Phrase vide, rien à lire.")
            return
        
        # Send to queue
        self.tts.say(self.phrase_text, self.current_lang)

    # === RECONNAISSANCE VOCALE (PC Tkinter) ===
    
    def start_voice_recognition(self):
        """Démarrer l'écoute et mettre la caméra en pause"""
        if not self.speech_recognizer:
            print("⚠️ Reconnaissance vocale non disponible")
            return
        
        print("🎤 Démarrage écoute...")
        self.btn_micro.configure(text="Ecoute... 👂", fg_color="#E65100") # Orange
        
        # Mettre la caméra en pause pour afficher l'image
        self.camera.paused = True
        
        # Effacer l'image caméra actuelle (mettre un fond noir ou gris)
        # self.camera_label.config(image='') 
        
        # Démarrer l'écoute (non-bloquant via thread interne du module)
        self.speech_recognizer.start_listening(self.on_speech_recognized)

    def on_speech_recognized(self, text):
        """Callback après reconnaissance"""
        print(f"🗣️ Texte reconnu: '{text}'")
        
        # Restaurer bouton
        self.btn_micro.configure(text="MICRO 🎤", fg_color="#9C27B0")
        
        text = text.lower().strip()
        gesture_key = self.find_gesture_key(text)
        
        if gesture_key:
            self.show_gesture_image(gesture_key)
        else:
            print(f"⚠️ Pas de geste pour: {text}")
            # Reprendre la caméra après 2 secondes si échec
            self.fenetre.after(2000, self.resume_camera)

    def find_gesture_key(self, text):
        """Trouver la clé depuis le texte (parcours translations)"""
        # 1. Chercher correspondance exacte mot
        for key, data in self.translations.items():
            if isinstance(data, dict):
                for lang, word in data.items():
                    if word and word.lower() == text:
                        return key
        
        # 2. Chercher lettre
        if len(text) == 1 and text.isalpha():
            return text.upper()
            
        return None

    def show_gesture_image(self, key):
        """Afficher l'image du geste dans le label caméra"""
        try:
            image_path = get_gesture_image(key)
            if image_path:
                print(f"🖼️ Affichage: {key} -> {image_path}")
                
                # Charger et redimensionner l'image avec PIL
                pil_img = Image.open(image_path)
                pil_img = pil_img.resize((640, 480), Image.Resampling.LANCZOS)
                tk_img = ImageTk.PhotoImage(pil_img)
                
                # Mettre à jour le label
                self.camera_label.configure(image=tk_img)
                self.camera_label.image = tk_img # Garder référence !
                
                # Programmer la reprise de la caméra après 4 secondes
                self.fenetre.after(4000, self.resume_camera)
            else:
                print(f"⚠️ Image non trouvée pour: {key}")
                self.resume_camera()
        except Exception as e:
            print(f"❌ Erreur affichage image: {e}")
            self.resume_camera()

    def resume_camera(self):
        """Reprendre le flux vidéo"""
        print("▶️ Reprise caméra")
        self.camera.paused = False

if __name__ == "__main__":
    def load_model(path):
        try: return pickle.load(open(path, 'rb'))['model']
        except: return None

    m_static = load_model('./model.p')
    m_sequence = load_model('./model_sequence.p')
    
    if not m_static and not m_sequence:
        print("❌ Error: No models found. Please train first.")
    else:
        root = Tk()
        InterfaceUtilisateur(root, m_static, m_sequence)
        root.mainloop()
