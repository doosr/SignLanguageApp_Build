# Test de reconnaissance vocale
# Teste le module speech_to_gesture sur PC

import sys
import os

# Ajouter le chemin du projet
sys.path.insert(0, os.path.dirname(__file__))

from speech_to_gesture import create_speech_recognizer

def test_callback(text):
    """Callback appelé quand un mot est reconnu"""
    print(f"\n✅ RÉSULTAT: '{text}'")
    print(f"📏 Longueur: {len(text)} caractères")
    print(f"🔤 Majuscules: {text.upper()}")
    print(f"🔤 Minuscules: {text.lower()}")

def main():
    print("=" * 60)
    print("🎤 TEST DE RECONNAISSANCE VOCALE")
    print("=" * 60)
    print()
    
    # Créer le recognizer
    print("[1/3] Initialisation du recognizer...")
    recognizer = create_speech_recognizer('fr')
    print("✓ Recognizer créé\n")
    
    # Demander permissions (sur Android uniquement)
    print("[2/3] Demande de permissions...")
    recognizer.request_permissions()
    print("✓ Permissions OK\n")
    
    # Démarrer l'écoute
    print("[3/3] Démarrage de l'écoute...")
    print("\n" + "=" * 60)
    print("🎙️  PARLEZ MAINTENANT!")
    print("=" * 60)
    print()
    print("Exemples de mots à dire:")
    print("  - Famille")
    print("  - Bonjour")
    print("  - Transport")
    print("  - A, B, C (lettres)")
    print()
    
    success = recognizer.start_listening(test_callback)
    
    if success:
        print("✓ Écoute démarrée!")
        print("\n⏳ En attente de résultat...\n")
        
        # Attendre que la reconnaissance se termine
        import time
        while recognizer.is_listening:
            time.sleep(0.5)
        
        print("\n" + "=" * 60)
        print("✅ Test terminé!")
        print("=" * 60)
    else:
        print("❌ Échec du démarrage de l'écoute")
        print("\nPossibles raisons:")
        print("  - Microphone non branché")
        print("  - Drivers audio manquants")
        print("  - SpeechRecognition non installé")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Test interrompu par l'utilisateur")
    except Exception as e:
        print(f"\n❌ ERREUR: {e}")
        import traceback
        traceback.print_exc()
