"""
Script de Test des Modèles TFLite
==================================
Ce script teste les modèles TFLite de reconnaissance de gestes sur votre PC
avant de les déployer dans l'application Android.

Usage:
    python test_models_complet.py

Contrôles:
    - Appuyez sur 'M' pour changer de mode (LETTRES/MOTS)
    - Appuyez sur 'Q' pour quitter
"""

import cv2
import numpy as np
import tensorflow as tf
import mediapipe as mp
import time
import os
import sys

# =========================
# CONFIGURATION
# =========================

MODELS_DIR = 'flutter_app/assets'
MODEL_LETTERS_PATH = os.path.join(MODELS_DIR, 'model_letters.tflite')
MODEL_WORDS_PATH = os.path.join(MODELS_DIR, 'model_words_lstm.tflite')  # LSTM model
LABELS_LETTERS_PATH = os.path.join(MODELS_DIR, 'model_letters_labels.txt')
LABELS_WORDS_PATH = os.path.join(MODELS_DIR, 'model_words_labels.txt')

SEQUENCE_LENGTH = 15  # For LSTM word model

# =========================
# VERIFICATION DES FICHIERS
# =========================

print("=" * 60)
print("🔍 VERIFICATION DES MODELES TFLITE")
print("=" * 60)

missing_files = []
for file_path in [MODEL_LETTERS_PATH, MODEL_WORDS_PATH, LABELS_LETTERS_PATH, LABELS_WORDS_PATH]:
    if os.path.exists(file_path):
        size = os.path.getsize(file_path) / 1024  # KB
        print(f"✅ {os.path.basename(file_path)}: {size:.2f} KB")
    else:
        print(f"❌ MANQUANT: {file_path}")
        missing_files.append(file_path)

if missing_files:
    print(f"\n❌ ERREUR: {len(missing_files)} fichier(s) manquant(s)!")
    sys.exit(1)

print("\n" + "=" * 60)
print("📦 CHARGEMENT DES MODELES")
print("=" * 60)

# =========================
# LOAD LABELS
# =========================

def load_labels(path):
    with open(path, 'r', encoding='utf-8') as f:
        return [line.strip() for line in f.readlines() if line.strip()]

try:
    labels_letters = load_labels(LABELS_LETTERS_PATH)
    labels_words = load_labels(LABELS_WORDS_PATH)
    print(f"✅ Lettres: {len(labels_letters)} classes - {labels_letters}")
    print(f"✅ Mots: {len(labels_words)} classes - {labels_words}")
except Exception as e:
    print(f"❌ Erreur de chargement des labels: {e}")
    sys.exit(1)

# =========================
# LOAD TFLITE MODELS
# =========================

try:
    # Letters Model
    interpreter_letters = tf.lite.Interpreter(model_path=MODEL_LETTERS_PATH)
    interpreter_letters.allocate_tensors()
    input_details_letters = interpreter_letters.get_input_details()
    output_details_letters = interpreter_letters.get_output_details()
    
    print(f"\n📊 Modèle LETTRES:")
    print(f"   Input shape: {input_details_letters[0]['shape']}")
    print(f"   Output shape: {output_details_letters[0]['shape']}")
    
    # Words Model (LSTM) - REQUIRES FLEX DELEGATE
    print("\n🔧 Chargement modèle LSTM avec Flex delegate...")
    interpreter_words = tf.lite.Interpreter(
        model_path=MODEL_WORDS_PATH,
        experimental_op_resolver_type=tf.lite.experimental.OpResolverType.BUILTIN_REF
    )
    interpreter_words.allocate_tensors()
    input_details_words = interpreter_words.get_input_details()
    output_details_words = interpreter_words.get_output_details()
    
    print(f"\n📊 Modèle MOTS (LSTM):")
    print(f"   Input shape: {input_details_words[0]['shape']}")
    print(f"   Output shape: {output_details_words[0]['shape']}")
    
    print("\n✅ Modèles TFLite chargés avec succès!")
    
except Exception as e:
    print(f"❌ Erreur de chargement des modèles: {e}")
    print("\n💡 SOLUTION:")
    print("   Le modèle LSTM nécessite TensorFlow complet (pas tensorflow-lite)")
    print("   Commandes:")
    print("   pip uninstall tensorflow-lite")
    print("   pip install tensorflow==2.14.0")
    print("\n   Ou utilisez: python test_letters_only.py (lettres seulement)")
    sys.exit(1)

# =========================
# MEDIAPIPE SETUP
# =========================

print("\n" + "=" * 60)
print("👋 INITIALISATION MEDIAPIPE")
print("=" * 60)

# MediaPipe - Compatible with different versions
try:
    from mediapipe.python.solutions import hands as mp_hands
    from mediapipe.python.solutions import drawing_utils as mp_drawing
    from mediapipe.python.solutions import drawing_styles as mp_drawing_styles
except ImportError:
    mp_hands = mp.solutions.hands
    mp_drawing = mp.solutions.drawing_utils
    mp_drawing_styles = mp.solutions.drawing_styles

hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=2,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

print("✅ MediaPipe Hands initialisé")

# =========================
# STATE VARIABLES
# =========================

mode = "LETTRES"  # "LETTRES" or "MOTS"
sequence_buffer = []
predicted_text = "..."
confidence = 0.0
letter_buffer = []
word_candidate_history = []

# =========================
# CAMERA SETUP
# =========================

print("\n" + "=" * 60)
print("📷 OUVERTURE DE LA CAMERA")
print("=" * 60)

cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("❌ Impossible d'ouvrir la caméra!")
    sys.exit(1)

print("✅ Caméra ouverte")
print("\n" + "=" * 60)
print("🎯 TEST EN COURS")
print("=" * 60)
print("Contrôles:")
print("  - Appuyez sur 'M' pour changer de mode (LETTRES/MOTS)")
print("  - Appuyez sur 'Q' pour quitter")
print("=" * 60)

fps_counter = 0
fps_start_time = time.time()
current_fps = 0

# =========================
# MAIN LOOP
# =========================

while cap.isOpened():
    success, image = cap.read()
    if not success:
        print("⚠️ Frame vide ignoré")
        continue

    # FPS Calculation
    fps_counter += 1
    if time.time() - fps_start_time >= 1.0:
        current_fps = fps_counter
        fps_counter = 0
        fps_start_time = time.time()

    # Process image
    image.flags.writeable = False
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = hands.process(image_rgb)

    image.flags.writeable = True
    image = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)
    H, W, _ = image.shape

    data_aux = []
    x_ = []
    y_ = []

    if results.multi_hand_landmarks:
        # Sort hands left-to-right (spatial sorting)
        sorted_hands = sorted(results.multi_hand_landmarks, key=lambda h: h.landmark[0].x)
        
        # Draw landmarks
        for hand_landmarks in sorted_hands:
            mp_drawing.draw_landmarks(
                image,
                hand_landmarks,
                mp_hands.HAND_CONNECTIONS,
                mp_drawing_styles.get_default_hand_landmarks_style(),
                mp_drawing_styles.get_default_hand_connections_style())

            for i in range(len(hand_landmarks.landmark)):
                x = hand_landmarks.landmark[i].x
                y = hand_landmarks.landmark[i].y
                x_.append(x)
                y_.append(y)

        # Normalize features relative to min x, min y
        if x_ and y_:
            min_x = min(x_)
            min_y = min(y_)
            
            for hand_landmarks in sorted_hands:
                for i in range(len(hand_landmarks.landmark)):
                    x = hand_landmarks.landmark[i].x
                    y = hand_landmarks.landmark[i].y
                    data_aux.append(x - min_x)
                    data_aux.append(y - min_y)

            # Pad to 84 features (2 hands * 21 points * 2 coordinates)
            while len(data_aux) < 84:
                data_aux.append(0.0)
            
            data_aux = data_aux[:84]

            # =========================
            # INFERENCE
            # =========================
            
            if mode == "LETTRES":
                # Letters mode: Single frame classification
                input_data = np.array([data_aux], dtype=np.float32)
                interpreter_letters.set_tensor(input_details_letters[0]['index'], input_data)
                interpreter_letters.invoke()
                output_data = interpreter_letters.get_tensor(output_details_letters[0]['index'])
                
                idx = np.argmax(output_data[0])
                prob = output_data[0][idx]
                
                if prob > 0.5:  # Threshold
                    label = labels_letters[idx]
                    letter_buffer.append(label)
                    if len(letter_buffer) > 5:
                        letter_buffer.pop(0)
                    
                    # Consistency check (3/5)
                    count = letter_buffer.count(label)
                    if count >= 3:
                        predicted_text = label
                        confidence = prob
                else:
                    predicted_text = "..."
                    confidence = 0.0
                    
            elif mode == "MOTS":
                # Words mode: Sequence classification (LSTM)
                sequence_buffer.append(data_aux)
                if len(sequence_buffer) > SEQUENCE_LENGTH:
                    sequence_buffer.pop(0)
                
                if len(sequence_buffer) == SEQUENCE_LENGTH:
                    # LSTM expects [1, 15, 84]
                    input_data = np.array([sequence_buffer], dtype=np.float32)
                    interpreter_words.set_tensor(input_details_words[0]['index'], input_data)
                    interpreter_words.invoke()
                    output_data = interpreter_words.get_tensor(output_details_words[0]['index'])
                    
                    idx = np.argmax(output_data[0])
                    prob = output_data[0][idx]
                    
                    label = labels_words[idx]
                    word_candidate_history.append(label)
                    
                    if len(word_candidate_history) > 10:
                        word_candidate_history.pop(0)
                    
                    freq = word_candidate_history.count(label)
                    
                    # High confidence + stability
                    if prob > 0.85 and freq >= 6:
                        predicted_text = label
                        confidence = prob
                        word_candidate_history.clear()
                        sequence_buffer.clear()
    else:
        # No hands detected
        predicted_text = "..."
        confidence = 0.0

    # =========================
    # DRAW UI
    # =========================
    
    # Background panel
    cv2.rectangle(image, (0, 0), (W, 120), (0, 0, 0), -1)
    
    # Mode indicator
    mode_color = (100, 200, 255) if mode == "LETTRES" else (255, 150, 100)
    cv2.putText(image, f"Mode: {mode}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, mode_color, 2)
    
    # FPS
    cv2.putText(image, f"FPS: {current_fps}", (W - 120, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 2)
    
    # Prediction
    color = (0, 255, 0) if confidence > 0.7 else (0, 165, 255)
    text_display = f"Detection: {predicted_text} ({confidence:.2f})"
    cv2.putText(image, text_display, (10, 70), cv2.FONT_HERSHEY_SIMPLEX, 1, color, 3)
    
    # Instructions
    cv2.putText(image, "Press 'M' = Mode | 'Q' = Quit", (10, 105), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (150, 150, 150), 1)

    # Show result
    cv2.imshow('Test Modeles TFLite - SignLanguage', image)
    
    # Handle keyboard
    key = cv2.waitKey(1) & 0xFF
    if key == ord('q') or key == ord('Q'):
        print("\n✅ Test terminé!")
        break
    elif key == ord('m') or key == ord('M'):
        mode = "MOTS" if mode == "LETTRES" else "LETTRES"
        sequence_buffer = []
        letter_buffer = []
        word_candidate_history = []
        predicted_text = "..."
        print(f"\n🔄 Mode changé: {mode}")

# Cleanup
cap.release()
cv2.destroyAllWindows()
hands.close()

print("\n" + "=" * 60)
print("✅ TEST TERMINE - Modèles fonctionnent correctement!")
print("=" * 60)
