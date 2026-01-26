import cv2
import sys

print("=" * 60)
print("DIAGNOSTIC DE CAMÉRA")
print("=" * 60)

# Test 1: Lister les caméras disponibles
print("\n[Test 1] Recherche de caméras disponibles...")
available_cameras = []

for i in range(10):
    cap = cv2.VideoCapture(i)
    if cap.isOpened():
        ret, frame = cap.read()
        if ret:
            print(f"✅ Caméra {i} trouvée et fonctionnelle")
            available_cameras.append(i)
        else:
            print(f"⚠️  Caméra {i} ouverte mais impossible de lire")
        cap.release()
    
if not available_cameras:
    print("❌ Aucune caméra trouvée!")
else:
    print(f"\n✅ Caméras disponibles: {available_cameras}")

# Test 2: Backends
print("\n[Test 2] Test des différents backends...")
backends = [
    ("ANY", cv2.CAP_ANY),
    ("DSHOW", cv2.CAP_DSHOW),
    ("MSMF", cv2.CAP_MSMF),
]

for name, backend in backends:
    print(f"\nBackend {name}:")
    for cam_id in available_cameras or [0]:
        cap = cv2.VideoCapture(cam_id, backend)
        if cap.isOpened():
            ret, frame = cap.read()
            if ret:
                print(f"  ✅ Index {cam_id}: OK")
                cap.release()
                break
            else:
                print(f"  ⚠️  Index {cam_id}: Ouvert mais pas de lecture")
        cap.release()

# Test 3: Permissions Windows
print("\n[Test 3] Vérifications système...")
print("Vérifiez dans les Paramètres Windows:")
print("  • Confidentialité > Caméra")
print("  • Autorisez les applications de bureau à accéder à votre caméra")
print("  • Fermez toutes les applications qui pourraient utiliser la caméra")
print("    (Teams, Zoom, Skype, Discord, OBS, etc.)")

print("\n" + "=" * 60)
print("DIAGNOSTIC TERMINÉ")
print("=" * 60)
