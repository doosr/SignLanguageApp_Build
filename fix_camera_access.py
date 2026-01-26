import cv2
import sys

def find_working_camera():
    """
    Test différents index et backends pour trouver une caméra fonctionnelle.
    Retourne (index, backend) ou None si aucune caméra n'est trouvée.
    """
    print("🔍 Recherche de caméras disponibles...\n")
    
    backends = [
        ("CAP_DSHOW (DirectShow - Windows)", cv2.CAP_DSHOW),
        ("CAP_MSMF (Media Foundation - Windows)", cv2.CAP_MSMF),
        ("CAP_ANY (Auto)", cv2.CAP_ANY),
    ]
    
    for backend_name, backend_id in backends:
        print(f"\n📷 Test avec {backend_name}:")
        for index in range(3):  # Teste les 3 premiers index
            try:
                print(f"   • Index {index}...", end=" ")
                cap = cv2.VideoCapture(index, backend_id)
                
                if cap.isOpened():
                    ret, frame = cap.read()
                    if ret and frame is not None:
                        h, w = frame.shape[:2]
                        print(f"✅ FONCTIONNE! ({w}x{h})")
                        cap.release()
                        return index, backend_id, backend_name
                    else:
                        print("⚠️  Ouvert mais ne peut pas lire")
                else:
                    print("❌ Ne peut pas ouvrir")
                
                cap.release()
            except Exception as e:
                print(f"❌ Erreur: {e}")
    
    print("\n❌ Aucune caméra fonctionnelle trouvée!")
    return None

def test_camera(index, backend):
    """Test l'accès caméra avec un affichage en temps réel"""
    print(f"\n🎥 Test de la caméra {index} avec backend {backend}")
    
    cap = cv2.VideoCapture(index, backend)
    
    if not cap.isOpened():
        print("❌ Impossible d'ouvrir la caméra")
        return False
    
    # Définir les paramètres de la caméra
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 30)
    
    print("✅ Caméra ouverte!")
    print("📸 Appuyez sur 'q' pour quitter, 'ESPACE' pour prendre une photo")
    
    frame_count = 0
    while True:
        ret, frame = cap.read()
        
        if not ret or frame is None:
            print(f"⚠️  Erreur de lecture à la frame {frame_count}")
            break
        
        frame_count += 1
        
        # Ajouter des informations sur l'image
        cv2.putText(frame, f"Frame: {frame_count}", (10, 30), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        cv2.putText(frame, "Appuyez sur 'q' pour quitter", (10, 60), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        
        cv2.imshow('Test Camera', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            print(f"\n✅ Test terminé - {frame_count} frames lues avec succès")
            break
        elif key == ord(' '):
            filename = f"test_capture_{frame_count}.jpg"
            cv2.imwrite(filename, frame)
            print(f"📸 Photo sauvegardée: {filename}")
    
    cap.release()
    cv2.destroyAllWindows()
    return True

def main():
    print("=" * 60)
    print("🔧 DIAGNOSTIC ET TEST DE LA CAMÉRA")
    print("=" * 60)
    
    result = find_working_camera()
    
    if result is None:
        print("\n⚠️  SOLUTIONS POSSIBLES:")
        print("  1. Vérifiez que la caméra est connectée")
        print("  2. Fermez les autres applications utilisant la caméra")
        print("  3. Redémarrez votre ordinateur")
        print("  4. Vérifiez les permissions de la caméra dans Windows")
        sys.exit(1)
    
    index, backend, backend_name = result
    
    print(f"\n✅ CONFIGURATION TROUVÉE:")
    print(f"   Index: {index}")
    print(f"   Backend: {backend_name}")
    print(f"\n💾 Pour utiliser cette configuration dans votre code:")
    print(f"   cap = cv2.VideoCapture({index}, cv2.{backend_name.split('(')[0].strip()})")
    
    # Demander si l'utilisateur veut tester
    print("\n" + "=" * 60)
    choice = input("\n🎥 Voulez-vous tester la caméra en direct? (o/n): ")
    if choice.lower() in ['o', 'y', 'oui', 'yes']:
        test_camera(index, backend)

if __name__ == "__main__":
    main()
