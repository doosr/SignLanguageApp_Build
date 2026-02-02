"""
TEST COMPLET (LETTRES + MOTS) - MediaPipe Tasks API
===================================================
Basé sur le script qui fonctionne (test_simple_tasks.py)
Ajoute le support du modèle LSTM pour les mots.
"""

import cv2
import numpy as np
import tensorflow as tf
import time
import sys

# ROBUST INTERPRETER IMPORT STRATEGY
try:
    import tensorflow as tf
    try:
        from tensorflow.lite.python.interpreter import Interpreter
    except ImportError:
        try:
            import tensorflow.lite as tflite
            Interpreter = tflite.Interpreter
        except (AttributeError, ImportError):
            Interpreter = tf.lite.Interpreter
    print("✅ Interpreter loaded")
except Exception as e:
    print(f"❌ CRITICAL ERROR: Could not find TFLite Interpreter. {e}")
    sys.exit(1)

# MediaPipe Tasks API
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import mediapipe as mp

print("=" * 60)
print("🔍 TEST COMPLET (LETTRES + MOTS)")
print("=" * 60)

# =============================================================================
# 1. LOAD MODELS
# =============================================================================

# PATHS
MODEL_LETTERS_PATH = 'flutter_app/assets/model_letters.tflite'
MODEL_WORDS_PATH = 'flutter_app/assets/model_words_lstm.tflite'
LABELS_LETTERS_PATH = 'flutter_app/assets/model_letters_labels.txt'
LABELS_WORDS_PATH = 'flutter_app/assets/model_words_labels.txt'

# Load Labels
def load_labels(path):
    with open(path, 'r', encoding='utf-8') as f:
        return [line.strip() for line in f.readlines() if line.strip()]

labels_letters = load_labels(LABELS_LETTERS_PATH)
labels_words = load_labels(LABELS_WORDS_PATH)

print(f"✅ Lettres: {len(labels_letters)} classes")
print(f"✅ Mots: {len(labels_words)} classes")

# Load TFLite Interpreters
try:
    # Letters
    interpreter_letters = Interpreter(model_path=MODEL_LETTERS_PATH)
    interpreter_letters.allocate_tensors()
    input_details_letters = interpreter_letters.get_input_details()
    output_details_letters = interpreter_letters.get_output_details()

    # Words (LSTM) - Requires Flex Delegate
    interpreter_words = Interpreter(
        model_path=MODEL_WORDS_PATH,
        experimental_op_resolver_type=tf.lite.experimental.OpResolverType.BUILTIN_REF
    )
    interpreter_words.allocate_tensors()
    input_details_words = interpreter_words.get_input_details()
    output_details_words = interpreter_words.get_output_details()

    print("\n✅ Modèles chargés avec succès!")

except Exception as e:
    print(f"\n❌ Erreur chargement modèles: {e}")
    sys.exit(1)

# =============================================================================
# 2. INITIALIZE MEDIAPIPE (TASKS API)
# =============================================================================

base_options = python.BaseOptions(model_asset_path='hand_landmarker.task')
options = vision.HandLandmarkerOptions(
    base_options=base_options,
    running_mode=vision.RunningMode.IMAGE,
    num_hands=2,
    min_hand_detection_confidence=0.3,
    min_hand_presence_confidence=0.3,
    min_tracking_confidence=0.3
)
detector = vision.HandLandmarker.create_from_options(options)

print("✅ MediaPipe Tasks API initialisé")

# =============================================================================
# 3. STATE VARIABLES
# =============================================================================

MODE = "LETTRES" # or "MOTS"
SEQUENCE_LENGTH = 15

# Buffers
sequence_buffer = []      # For LSTM ([15, 84])
letter_buffer = []
word_candidate_history = []
predicted_text = "..."
confidence = 0.0

# =============================================================================
# 4. MAIN LOOP
# =============================================================================

print("\n" + "=" * 60)
print("📷 DEMARRAGE CAMERA")
print("   [M] Changer Mode | [Q] Quitter")
print("=" * 60)

cap = cv2.VideoCapture(0)

while cap.isOpened():
    success, frame = cap.read()
    if not success:
        continue

    # Prepare Image
    H, W, _ = frame.shape
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
    
    # Run Detection
    results = detector.detect(mp_image)

    # Reset prediction if no hands
    if not results.hand_landmarks:
        if MODE == "LETTRES":
            predicted_text = "..."
            confidence = 0.0
            letter_buffer.clear()
        
        # Don't clear sequence buffer for words immediately to allow short pauses? 
        # Actually standard logic is to append zero-padding or stop
        # For simplicity, we just stop detection updates
    
    else:
        # 1. Sort Hands Left-to-Right
        sorted_hands = sorted(results.hand_landmarks, key=lambda h: h[0].x)
        
        # 2. Extract & Draw
        x_, y_ = [], []
        
        for hand_landmarks in sorted_hands:
            # Draw
            for lm in hand_landmarks:
                cv2.circle(frame, (int(lm.x * W), int(lm.y * H)), 5, (0, 255, 0), -1)
                x_.append(lm.x)
                y_.append(lm.y)
        
        # 3. Normalize & Create Feature Vector (84 floats)
        if x_ and y_:
            min_x, min_y = min(x_), min(y_)
            data_aux = []
            
            for hand_landmarks in sorted_hands:
                for lm in hand_landmarks:
                    data_aux.append(lm.x - min_x)
                    data_aux.append(lm.y - min_y)
            
            # Pad to 84 features
            while len(data_aux) < 84:
                data_aux.append(0.0)
            data_aux = data_aux[:84]

            # 4. INFERENCE
            
            # --- LETTRES ---
            if MODE == "LETTRES":
                input_data = np.array([data_aux], dtype=np.float32)
                interpreter_letters.set_tensor(input_details_letters[0]['index'], input_data)
                interpreter_letters.invoke()
                output = interpreter_letters.get_tensor(output_details_letters[0]['index'])
                
                idx = np.argmax(output[0])
                prob = output[0][idx]
                
                if prob > 0.4:
                    label = labels_letters[idx]
                    letter_buffer.append(label)
                    if len(letter_buffer) > 5:
                        letter_buffer.pop(0)
                    
                    if letter_buffer.count(label) >= 3:
                        predicted_text = label
                        confidence = prob
                else:
                    letter_buffer.clear()

            # --- MOTS (LSTM) ---
            elif MODE == "MOTS":
                sequence_buffer.append(data_aux)
                if len(sequence_buffer) > SEQUENCE_LENGTH:
                    sequence_buffer.pop(0)
                
                if len(sequence_buffer) == SEQUENCE_LENGTH:
                    input_data = np.array([sequence_buffer], dtype=np.float32) # [1, 15, 84]
                    interpreter_words.set_tensor(input_details_words[0]['index'], input_data)
                    interpreter_words.invoke()
                    output = interpreter_words.get_tensor(output_details_words[0]['index'])
                    
                    idx = np.argmax(output[0])
                    prob = output[0][idx]
                    
                    label = labels_words[idx]
                    
                    # Filtering logic
                    word_candidate_history.append(label)
                    if len(word_candidate_history) > 10:
                        word_candidate_history.pop(0)
                    
                    if prob > 0.75 and word_candidate_history.count(label) >= 5:
                        predicted_text = label
                        confidence = prob
                        word_candidate_history.clear()
                        sequence_buffer.clear() # Reset after detection

    # UI Display
    # Header
    cv2.rectangle(frame, (0, 0), (W, 80), (0, 0, 0), -1)
    
    # Mode Indicator
    color_mode = (100, 200, 255) if MODE == "LETTRES" else (255, 100, 200)
    cv2.putText(frame, f"MODE: {MODE}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color_mode, 2)
    
    # Prediction
    color_pred = (0, 255, 0) if confidence > 0.6 else (0, 165, 255)
    cv2.putText(frame, f"Predict: {predicted_text} ({confidence:.2f})", (10, 65), cv2.FONT_HERSHEY_SIMPLEX, 1, color_pred, 2)

    cv2.imshow('Test Complet - MediaPipe Tasks', frame)
    
    # Key Controls
    key = cv2.waitKey(1) & 0xFF
    if key == ord('q'):
        break
    elif key == ord('m'):
        MODE = "MOTS" if MODE == "LETTRES" else "LETTRES"
        # Reset buffers
        sequence_buffer.clear()
        letter_buffer.clear()
        word_candidate_history.clear()
        predicted_text = "..."
        print(f"🔄 Mode changé: {MODE}")

cap.release()
cv2.destroyAllWindows()
print("\n✅ Test terminé!")
