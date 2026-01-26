"""
Script de diagnostic avancé pour résoudre les problèmes d'accès caméra Windows
Teste différentes configurations avec délais prolongés et libération entre tentatives
"""
import cv2
import time
import sys

def release_all_cameras():
    """Libère toutes les caméras potentiellement ouvertes"""
    for i in range(5):
        try:
            cap = cv2.VideoCapture(i)
            cap.release()
        except:
            pass
    cv2.destroyAllWindows()
    time.sleep(0.5)

def test_camera_with_delay(index, backend_name, backend_id, delay=2.0, attempts=5):
    """
    Test caméra avec délai prolongé et tentatives multiples
    
    Args:
        index: Index de la caméra
        backend_name: Nom du backend (pour affichage)
        backend_id: ID du backend OpenCV
        delay: Délai d'attente après ouverture (secondes)
        attempts: Nombre de tentatives de lecture
    """
    print(f"\n{'='*60}")
    print(f"Test: Index={index}, Backend={backend_name}")
    print(f"Délai d'initialisation: {delay}s, Tentatives: {attempts}")
    print('='*60)
    
    # Libérer avant d'essayer
    release_all_cameras()
    
    # Ouvrir la caméra
    cap = cv2.VideoCapture(index, backend_id)
    
    if not cap.isOpened():
        print("❌ Impossible d'ouvrir la caméra")
        cap.release()
        return False
    
    print(f"✓ Caméra ouverte (isOpened = True)")
    
    # Configurer les paramètres
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 30)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # Réduire buffer
    
    # CRUCIAL: Attendre que la caméra s'initialise
    print(f"⏳ Attente de {delay}s pour initialisation...")
    time.sleep(delay)
    
    # Tenter plusieurs lectures
    success_count = 0
    for i in range(attempts):
        print(f"  Tentative {i+1}/{attempts}...", end=" ")
        ret, frame = cap.read()
        
        if ret and frame is not None:
            h, w = frame.shape[:2]
            print(f"✅ Lecture réussie ({w}x{h})")
            success_count += 1
        else:
            print(f"❌ Échec de lecture")
        
        time.sleep(0.2)
    
    cap.release()
    
    if success_count > 0:
        print(f"\n🎉 SUCCÈS! {success_count}/{attempts} lectures réussies")
        return True
    else:
        print(f"\n❌ ÉCHEC - Aucune lecture réussie")
        return False

def main():
    print("="*70)
    print("🔧 DIAGNOSTIC AVANCÉ - ACCÈS CAMÉRA WINDOWS")
    print("="*70)
    
    # Vérifier les applications qui pourraient utiliser la caméra
    print("\n⚠️  IMPORTANT: Fermez toutes les applications suivantes si ouvertes:")
    print("  - Zoom, Microsoft Teams, Skype")
    print("  - Windows Camera app")
    print("  - Tout autre outil de visioconférence")
    print("  - Navigateurs avec accès webcam")
    
    input("\n▶ Appuyez sur ENTRÉE quand vous êtes prêt...")
    
    # Libérer toutes les caméras au départ
    print("\n🔄 Libération de toutes les caméras...")
    release_all_cameras()
    
    # Configurations à tester (ordre de priorité)
    configurations = [
        # Backend, Index, Délai initial
        ("MSMF", cv2.CAP_MSMF, 0, 3.0),
        ("MSMF", cv2.CAP_MSMF, 1, 3.0),
        ("DSHOW", cv2.CAP_DSHOW, 0, 2.0),
        ("DSHOW", cv2.CAP_DSHOW, 1, 2.0),
        ("ANY", cv2.CAP_ANY, 0, 2.0),
        ("ANY", cv2.CAP_ANY, 1, 2.0),
    ]
    
    working_config = None
    
    for backend_name, backend_id, index, delay in configurations:
        if test_camera_with_delay(index, backend_name, backend_id, delay=delay):
            working_config = (index, backend_name, backend_id, delay)
            break
        time.sleep(1)  # Pause entre tests
    
    print("\n" + "="*70)
    
    if working_config:
        index, backend_name, backend_id, delay = working_config
        print("✅ CONFIGURATION FONCTIONNELLE TROUVÉE!")
        print("="*70)
        print(f"\n📋 Paramètres à utiliser:")
        print(f"   Index caméra: {index}")
        print(f"   Backend: {backend_name} (cv2.CAP_{backend_name})")
        print(f"   Délai d'initialisation: {delay}s")
        
        print(f"\n💻 Code à utiliser dans vos scripts:")
        print(f"```python")
        print(f"cap = cv2.VideoCapture({index}, cv2.CAP_{backend_name})")
        print(f"time.sleep({delay})  # CRUCIAL: attendre initialisation")
        print(f"ret, frame = cap.read()")
        print(f"```")
        
        # Test interactif
        choice = input("\n🎥 Voulez-vous tester en direct? (o/n): ")
        if choice.lower() in ['o', 'y', 'oui', 'yes']:
            test_live_camera(index, backend_id, delay)
    else:
        print("❌ AUCUNE CONFIGURATION FONCTIONNELLE")
        print("="*70)
        print("\n🔍 SOLUTIONS POSSIBLES:")
        print("  1. Redémarrer l'ordinateur (libère tous les accès caméra)")
        print("  2. Vérifier les permissions caméra dans:")
        print("     Paramètres Windows → Confidentialité → Caméra")
        print("  3. Mettre à jour les pilotes de la webcam")
        print("  4. Tester avec une webcam USB externe")
        print("  5. Désactiver temporairement l'antivirus")

def test_live_camera(index, backend_id, delay):
    """Test en direct avec affichage vidéo"""
    print(f"\n🎥 Test caméra en direct...")
    print("   Appuyez sur 'q' pour quitter")
    
    release_all_cameras()
    cap = cv2.VideoCapture(index, backend_id)
    time.sleep(delay)
    
    if not cap.isOpened():
        print("❌ Erreur: impossible d'ouvrir la caméra")
        return
    
    frame_count = 0
    while True:
        ret, frame = cap.read()
        
        if ret and frame is not None:
            frame_count += 1
            cv2.putText(frame, f"Frame: {frame_count}", (10, 30),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            cv2.putText(frame, "Appuyez sur 'q' pour quitter", (10, 60),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
            
            cv2.imshow('Test Camera', frame)
        
        if cv2.waitKey(1) & 0xFF == ord('q'):
            print(f"\n✅ Test terminé - {frame_count} frames affichées")
            break
    
    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Interruption utilisateur")
        release_all_cameras()
        sys.exit(0)
