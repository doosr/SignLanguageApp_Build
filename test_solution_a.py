"""
Solution A : Test LSTM avec TensorFlow Flex Ops
================================================
Ce script utilise TensorFlow complet pour supporter les opérations Flex du modèle LSTM
"""

import cv2
import numpy as np
import tensorflow as tf  # Import complet, pas tflite
import mediapipe as mp
import time
import os

print("=" * 60)
print("🔧 SOLUTION A - TEST LSTM AVEC FLEX OPS")
print("=" * 60)

# Configuration
MODEL_LETTERS_PATH = 'flutter_app/assets/model_letters.tflite'
MODEL_WORDS_PATH = 'flutter_app/assets/model_words_lstm.tflite'
LABELS_LETTERS_PATH = 'flutter_app/assets/model_letters_labels.txt'
LABELS_WORDS_PATH = 'flutter_app/assets/model_words_labels.txt'
SEQUENCE_LENGTH = 15

# Vérification
for path in [MODEL_LETTERS_PATH, MODEL_WORDS_PATH, LABELS_LETTERS_PATH, LABELS_WORDS_PATH]:
    if not os.path.exists(path):
        print(f"❌ Fichier manquant: {path}")
        exit(1)
    size = os.path.getsize(path) / 1024
    print(f"✅ {os.path.basename(path)}: {size:.2f} KB")

# Load labels
def load_labels(path):
    with open(path, 'r', encoding='utf-8') as f:
        return [line.strip() for line in f if line.strip()]

labels_letters = load_labels(LABELS_LETTERS_PATH)
labels_words = load_labels(LABELS_WORDS_PATH)

print(f"\n📦 Lettres: {len(labels_letters)} classes")
print(f"📦 Mots: {len(labels_words)} classes")

# Load models avec support Flex
print("\n🔧 Chargement modèles avec Flex delegate...")
try:
    # Lettres - modèle standard
    interpreter_letters = tf.lite.Interpreter(model_path=MODEL_LETTERS_PATH)
    interpreter_letters.allocate_tensors()
    input_details_letters = interpreter_letters.get_input_details()
    output_details_letters = interpreter_letters.get_output_details()
    print(f"✅ Modèle LETTRES: {input_details_letters[0]['shape']} -> {output_details_letters[0]['shape']}")
    
    # LSTM - modèle avec Flex ops
    # CRITICAL: Use experimental_op_resolver_type to enable Flex delegate
    interpreter_words = tf.lite.Interpreter(
        model_path=MODEL_WORDS_PATH,
        experimental_op_resolver_type=tf.lite.experimental.OpResolverType.BUILTIN_REF
    )
    interpreter_words.allocate_tensors()
    input_details_words = interpreter_words.get_input_details()
    output_details_words = interpreter_words.get_output_details()
    print(f"✅ Modèle LSTM: {input_details_words[0]['shape']} -> {output_details_words[0]['shape']}")
    
except Exception as e:
    print(f"\n❌ Erreur: {e}")
    print("\n💡 Solution: Installez TensorFlow complet:")
    print("   pip uninstall tensorflow-lite")
    print("   pip install tensorflow==2.14.0")
    exit(1)

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

print("\n" + "=" * 60)
print("📷 DEMARRAGE TEST")
print("=" * 60)
print("Contrôles:")
print("  - Appuyez sur 'M' pour changer de mode (LETTRES/MOTS)")
print("  - Appuyez sur 'Q' pour quitter")
print("=" * 60)

# State
mode = "LETTRES"
sequence_buffer = []
letter_buffer = []
word_candidate_history = []
predicted_text = "..."
confidence = 0.0

cap = cv2.VideoCapture(0)
fps_counter = 0
fps_start = time.time()
current_fps = 0

while cap.isOpened():
    success, image = cap.read()
    if not success:
        continue

    # FPS
    fps_counter += 1
    if time.time() - fps_start >= 1.0:
        current_fps = fps_counter
        fps_counter = 0
        fps_start = time.time()

    # Process
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = hands.process(image_rgb)
    image = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)
    H, W, _ = image.shape

    data_aux = []
    x_, y_ = [], []

    if results.multi_hand_landmarks:
        sorted_hands = sorted(results.multi_hand_landmarks, key=lambda h: h.landmark[0].x)
        
        for hand_landmarks in sorted_hands:
            mp_drawing.draw_landmarks(
                image, hand_landmarks, mp_hands.HAND_CONNECTIONS,
                mp_drawing_styles.get_default_hand_landmarks_style(),
                mp_drawing_styles.get_default_hand_connections_style()
            )
            for lm in hand_landmarks.landmark:
                x_.append(lm.x)
                y_.append(lm.y)

        if x_ and y_:
            min_x, min_y = min(x_), min(y_)
            
            for hand_landmarks in sorted_hands:
                for lm in hand_landmarks.landmark:
                    data_aux.append(lm.x - min_x)
                    data_aux.append(lm.y - min_y)
            
            while len(data_aux) < 84:
                data_aux.append(0.0)
            data_aux = data_aux[:84]

            # INFERENCE
            if mode == "LETTRES":
                input_data = np.array([data_aux], dtype=np.float32)
                interpreter_letters.set_tensor(input_details_letters[0]['index'], input_data)
                interpreter_letters.invoke()
                output = interpreter_letters.get_tensor(output_details_letters[0]['index'])
                
                idx = np.argmax(output[0])
                prob = output[0][idx]
                
                if prob > 0.5:
                    label = labels_letters[idx]
                    letter_buffer.append(label)
                    if len(letter_buffer) > 5:
                        letter_buffer.pop(0)
                    
                    count = letter_buffer.count(label)
                    if count >= 3:
                        predicted_text = label
                        confidence = prob
                        
            elif mode == "MOTS":
                sequence_buffer.append(data_aux)
                if len(sequence_buffer) > SEQUENCE_LENGTH:
                    sequence_buffer.pop(0)
                
                if len(sequence_buffer) == SEQUENCE_LENGTH:
                    # LSTM: [1, 15, 84]
                    input_data = np.array([sequence_buffer], dtype=np.float32)
                    interpreter_words.set_tensor(input_details_words[0]['index'], input_data)
                    interpreter_words.invoke()
                    output = interpreter_words.get_tensor(output_details_words[0]['index'])
                    
                    idx = np.argmax(output[0])
                    prob = output[0][idx]
                    
                    label = labels_words[idx]
                    word_candidate_history.append(label)
                    
                    if len(word_candidate_history) > 10:
                        word_candidate_history.pop(0)
                    
                    freq = word_candidate_history.count(label)
                    
                    if prob > 0.85 and freq >= 6:
                        predicted_text = label
                        confidence = prob
                        word_candidate_history.clear()
                        sequence_buffer.clear()
                        print(f"🎯 Mot détecté: {label} ({prob:.2f})")
    else:
        predicted_text = "..."
        confidence = 0.0

    # UI
    cv2.rectangle(image, (0, 0), (W, 100), (0, 0, 0), -1)
    
    mode_color = (100, 200, 255) if mode == "LETTRES" else (255, 150, 100)
    cv2.putText(image, f"Mode: {mode}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, mode_color, 2)
    cv2.putText(image, f"FPS: {current_fps}", (W - 100, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 2)
    
    color = (0, 255, 0) if confidence > 0.7 else (0, 165, 255)
    text = f"{predicted_text} ({confidence:.2f})"
    cv2.putText(image, text, (10, 70), cv2.FONT_HERSHEY_SIMPLEX, 1.2, color, 3)
    
    cv2.putText(image, "M=Mode | Q=Quit", (10, 95), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (150, 150, 150), 1)

    cv2.imshow('Test LSTM avec Flex Ops - Solution A', image)
    
    key = cv2.waitKey(1) & 0xFF
    if key == ord('q') or key == ord('Q'):
        break
    elif key == ord('m') or key == ord('M'):
        mode = "MOTS" if mode == "LETTRES" else "LETTRES"
        sequence_buffer.clear()
        letter_buffer.clear()
        word_candidate_history.clear()
        predicted_text = "..."
        print(f"\n🔄 Mode: {mode}")

cap.release()
cv2.destroyAllWindows()
print("\n✅ Test terminé avec succès!")
