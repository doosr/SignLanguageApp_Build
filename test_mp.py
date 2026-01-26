import mediapipe as mp
print("Dir(mp):", dir(mp))
try:
    print("mp.solutions:", mp.solutions)
except AttributeError as e:
    print("Error accessing mp.solutions:", e)
    try:
        import mediapipe.python.solutions
        print("Imported mediapipe.python.solutions successfully")
    except ImportError as e2:
        print("Could not import mediapipe.python.solutions:", e2)
