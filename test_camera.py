import cv2
import time

print("🔍 Test de Caméra PC - Diagnostic")
print("=" * 50)

# Test des différents backends
backends = [
    ("MSMF (Windows Media Foundation)", cv2.CAP_MSMF),
    ("DSHOW (DirectShow)", cv2.CAP_DSHOW),
    ("V4L2 (Video4Linux2)", cv2.CAP_V4L2),
    ("ANY (Automatique)", cv2.CAP_ANY)
]

cameras_found = []

for name, backend in backends:
    print(f"\n📹 Test Backend: {name}")
    for index in range(3):
        try:
            print(f"   Essai caméra index {index}...", end=" ")
            cap = cv2.VideoCapture(index, backend)
            
            if cap.isOpened():
                time.sleep(0.3)
                ret, frame = cap.read()
                
                if ret and frame is not None:
                    h, w = frame.shape[:2]
                    print(f"✅ TROUVÉE! Résolution: {w}x{h}")
                    cameras_found.append({
                        'index': index,
                        'backend': name,
                        'backend_code': backend,
                        'resolution': (w, h)
                    })
                    cap.release()
                else:
                    print("❌ Échec lecture frame")
                    cap.release()
            else:
                print("❌ Échec ouverture")
        except Exception as e:
            print(f"❌ Erreur: {e}")

print("\n" + "=" * 50)
print("📊 RÉSULTATS")
print("=" * 50)

if cameras_found:
    print(f"\n✅ {len(cameras_found)} caméra(s) détectée(s):\n")
    for i, cam in enumerate(cameras_found, 1):
        print(f"{i}. Index {cam['index']} - {cam['backend']}")
        print(f"   Résolution: {cam['resolution'][0]}x{cam['resolution'][1]}")
        print()
    
    # Test avec la première caméra trouvée
    print("🎥 Test d'affichage avec la première caméra...")
    best_cam = cameras_found[0]
    
    cap = cv2.VideoCapture(best_cam['index'], best_cam['backend_code'])
    
    if cap.isOpened():
        print(f"\n✅ Caméra ouverte: Index {best_cam['index']} - {best_cam['backend']}")
        print("\n📹 Affichage de la caméra...")
        print("   Appuyez sur 'Q' pour quitter\n")
        
        frame_count = 0
        while True:
            ret, frame = cap.read()
            if ret:
                frame_count += 1
                cv2.putText(frame, f"Frame: {frame_count}", (10, 30),
                           cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                cv2.putText(frame, "Appuyez sur Q pour quitter", (10, 70),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                
                cv2.imshow('Test Camera', frame)
                
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
            else:
                print("❌ Erreur lecture frame")
                break
        
        cap.release()
        cv2.destroyAllWindows()
        print("\n✅ Test terminé avec succès!")
    else:
        print("❌ Impossible d'ouvrir la caméra pour le test")
else:
    print("\n❌ AUCUNE CAMÉRA DÉTECTÉE!")
    print("\n💡 Solutions possibles:")
    print("   1. Vérifiez que votre webcam est branchée")
    print("   2. Fermez les applications qui utilisent la caméra (Zoom, Teams, etc.)")
    print("   3. Redémarrez l'ordinateur")
    print("   4. Vérifiez les pilotes de la webcam dans le Gestionnaire de périphériques")
    print("   5. Donnez les permissions caméra à Python dans Paramètres Windows")

print("\n" + "=" * 50)
