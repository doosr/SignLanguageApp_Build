import cv2
import time

print("=" * 60)
print("TEST DETAILLE DE LA CAMERA")
print("=" * 60)

backends = [
    ("CAP_DSHOW", cv2.CAP_DSHOW),
    ("CAP_MSMF", cv2.CAP_MSMF), 
    ("CAP_ANY", cv2.CAP_ANY),
]

for backend_name, backend_id in backends:
    print(f"\n{'='*60}")
    print(f"Test avec {backend_name}")
    print('='*60)
    
    for index in range(3):
        print(f"\n  Index {index}:")
        try:
            cap = cv2.VideoCapture(index, backend_id)
            print(f"    isOpened(): {cap.isOpened()}")
            
            if cap.isOpened():
                # Attendre un peu pour la camera
                time.sleep(0.5)
                
                ret, frame = cap.read()
                print(f"    read() ret: {ret}")
                
                if ret and frame is not None:
                    print(f"    Frame shape: {frame.shape}")
                    print(f"    ✅ SUCCES!")
                    
                    # Test de lecture multiple
                    success_count = 0
                    for i in range(5):
                        ret, _ = cap.read()
                        if ret:
                            success_count += 1
                    print(f"    5 lectures supplementaires: {success_count}/5 reussies")
                    
                    cap.release()
                    print(f"\n🎉 CONFIGURATION FONCTIONNELLE TROUVEE!")
                    print(f"   Backend: {backend_name}")
                    print(f"   Index: {index}")
                    break
                else:
                    print(f"    ❌ Erreur de lecture")
            
            cap.release()
            time.sleep(0.3)
        except Exception as e:
            print(f"    ❌ Exception: {e}")
    else:
        continue
    break
else:
    print("\n❌ Aucune configuration fonctionnelle trouvee")
    print("\nSOLUTIONS POSSIBLES:")
    print("  1. Fermez toutes les applications utilisant la camera (Zoom, Teams, etc.)")
    print("  2. Redemarrez votre ordinateur")
    print("  3. Verifiez les permissions de la camera dans Windows Settings")
