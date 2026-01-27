import cv2

print("🔍 Test d'accès à la caméra...")
print("-" * 50)


# Test avec DSHOW backend
cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)

if cap.isOpened():
    print("✅ Caméra ouverte avec succès !")
    
    ret, frame = cap.read()
    if ret:
        print("✅ Lecture de frame réussie !")
        print(f"📐 Résolution : {frame.shape[1]}x{frame.shape[0]}")
        print("\n🎉 TOUT FONCTIONNE CORRECTEMENT !")
    else:
        print("❌ Erreur de lecture de frame")
    
    cap.release()
else:
    print("❌ Impossible d'ouvrir la caméra")
    print("\n💡 Vérifiez les autorisations Windows :")
    print("   - Paramètres → Confidentialité → Caméra")
    print("   - Activez 'Autoriser les applications de bureau'")

print("-" * 50)
