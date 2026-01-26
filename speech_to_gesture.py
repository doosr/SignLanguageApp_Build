# Module de reconnaissance vocale pour Sign Language App
# Convertit la parole en geste de langue des signes

from kivy.utils import platform

if platform == 'android':
    from jnius import autoclass, cast
    from android.permissions import request_permissions, Permission
    
    # Classes Java Android
    Intent = autoclass('android.content.Intent')
    RecognizerIntent = autoclass('android.speech.RecognizerIntent')
    PythonActivity = autoclass('org.kivy.android.PythonActivity')
    
    SPEECH_AVAILABLE = True
else:
    SPEECH_AVAILABLE = False

import threading
import time

class SpeechToGesture:
    """Convertit la parole en geste de langue des signes"""
    
    def __init__(self, language='fr-FR'):
        self.language = language
        self.is_listening = False
        self.callback = None
        
        # Mapping langues
        self.lang_codes = {
            'fr': 'fr-FR',
            'en': 'en-US',
            'ar': 'ar-SA'
        }
    
    def request_permissions(self):
        """Demander permissions microphone"""
        if SPEECH_AVAILABLE:
            request_permissions([Permission.RECORD_AUDIO])
    
    def set_language(self, lang):
        """Changer la langue de reconnaissance"""
        self.language = self.lang_codes.get(lang, 'fr-FR')
        print(f"[INFO] Langue reconnaissance: {self.language}")
    
    def start_listening(self, callback):
        """
        Démarrer la reconnaissance vocale
        
        Args:
            callback: Fonction appelée avec le texte reconnu
                      callback(text: str)
        """
        if not SPEECH_AVAILABLE:
            print("[ERROR] Reconnaissance vocale non disponible")
            return False
        
        self.callback = callback
        self.is_listening = True
        
        try:
            print("[INFO] Démarrage reconnaissance vocale...")
            
            # Créer Intent de reconnaissance vocale
            intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            intent.putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, self.language)
            intent.putExtra(RecognizerIntent.EXTRA_PROMPT, "Parlez maintenant...")
            intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            
            # Obtenir l'activité courante
            activity = PythonActivity.mActivity
            
            # Code de requête unique
            REQUEST_CODE = 1234
            
            # Démarrer l'activité de reconnaissance
            activity.startActivityForResult(intent, REQUEST_CODE)
            
            # Lancer thread pour récupérer le résultat
            threading.Thread(
                target=self._wait_for_result,
                args=(activity, REQUEST_CODE),
                daemon=True
            ).start()
            
            return True
            
        except Exception as e:
            print(f"[ERROR] Reconnaissance vocale: {e}")
            self.is_listening = False
            return False
    
    def _wait_for_result(self, activity, request_code):
        """Attendre le résultat de la reconnaissance"""
        try:
            # Note: Dans une vraie implémentation Android/Kivy,
            # il faut utiliser onActivityResult callback
            # Cette version est simplifiée
            
            time.sleep(5)  # Timeout
            
            if self.is_listening:
                print("[INFO] Timeout reconnaissance vocale")
                self.is_listening = False
                
        except Exception as e:
            print(f"[ERROR] Attente résultat: {e}")
            self.is_listening = False
    
    def process_result(self, results):
        """
        Traiter les résultats de reconnaissance
        
        Args:
            results: Liste de textes reconnus
        """
        if results and len(results) > 0:
            recognized_text = results[0]
            print(f"[OK] Texte reconnu: {recognized_text}")
            
            if self.callback:
                self.callback(recognized_text)
        
        self.is_listening = False
    
    def stop_listening(self):
        """Arrêter la reconnaissance"""
        self.is_listening = False
        print("[INFO] Reconnaissance vocale arrêtée")


# Version PC (pour tests)
class SpeechToGesturePC:
    """Version PC utilisant speech_recognition"""
    
    def __init__(self, language='fr-FR'):
        self.language = language
        self.is_listening = False
        self.callback = None
        
        try:
            import speech_recognition as sr
            self.recognizer = sr.Recognizer()
            self.microphone = sr.Microphone()
            print("[OK] SpeechRecognition initialisé")
        except ImportError:
            print("[ERROR] Module 'SpeechRecognition' ou 'pyaudio' manquant sur PC")
            print("  Installez avec: pip install SpeechRecognition pyaudio")
            self.recognizer = None
        except Exception as e:
            print(f"[ERROR] Erreur init SpeechRecognition PC: {e}")
            import traceback
            traceback.print_exc()
            self.recognizer = None
    
    def request_permissions(self):
        pass  # Pas besoin sur PC
    
    def set_language(self, lang):
        self.language = {'fr': 'fr-FR', 'en': 'en-US', 'ar': 'ar-SA'}.get(lang, 'fr-FR')
    
    def start_listening(self, callback):
        """Démarrer écoute sur PC"""
        if not self.recognizer:
            return False
        
        self.callback = callback
        self.is_listening = True
        
        def listen_thread():
            try:
                import speech_recognition as sr
                
                with self.microphone as source:
                    print("[INFO] Ajustement bruit ambiant...")
                    self.recognizer.adjust_for_ambient_noise(source, duration=1)
                    print("[INFO] Parlez maintenant...")
                    audio = self.recognizer.listen(source, timeout=5)
                
                print("[INFO] Reconnaissance en cours...")
                text = self.recognizer.recognize_google(audio, language=self.language)
                
                print(f"[OK] Reconnu: {text}")
                
                if self.callback:
                    self.callback(text)
                    
            except sr.WaitTimeoutError:
                print("[WARNING] Timeout - rien détecté")
            except sr.UnknownValueError:
                print("[WARNING] Parole non comprise")
            except sr.RequestError as e:
                print(f"[ERROR] Service reconnaissance: {e}")
            except Exception as e:
                print(f"[ERROR] Reconnaissance: {e}")
            finally:
                self.is_listening = False
        
        threading.Thread(target=listen_thread, daemon=True).start()
        return True
    
    def stop_listening(self):
        self.is_listening = False


# Factory function
def create_speech_recognizer(language='fr'):
    """Créer le bon recognizer selon la plateforme"""
    if platform == 'android':
        return SpeechToGesture(language)
    else:
        return SpeechToGesturePC(language)
