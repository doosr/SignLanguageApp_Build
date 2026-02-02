"""
Test Simple - Lettres Seulement
================================
Test rapide du modèle de lettres uniquement (pas de LSTM)
"""

import cv2
import numpy as np
import tensorflow as tf
import mediapipe as mp
import time
import os

# Configuration
MODEL_PATH = 'flutter_app/assets/model_letters.tflite'
LABELS_PATH = 'flutter_app/assets/model_letters_labels.txt'

print("=" * 60)
print("🔍 TEST MODELE LETTRES UNIQUEMENT")
print("=" * 60)

# Load labels
with open(LABELS_PATH, 'r') as f:
    labels = [line.strip() for line in f.readlines() if line.strip()]
print(f"✅ {len(labels)} lettres: {labels}")

# Load model
interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"\n📊 Modèle chargé:")
print(f"   Input: {input_details[0]['shape']}")
print(f"   Output: {output_details[0]['shape']}")

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
    min_detection_confidence=0.5
)

print("\n✅ MediaPipe initialisé")
print("\n" + "=" * 60)
print("📷 Démarrage caméra... (Appuyez sur 'Q' pour quitter)")
print("=" * 60)

cap = cv2.VideoCapture(0)
letter_buffer = []

while cap.isOpened():
    success, image = cap.read()
    if not success:
        continue

    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = hands.process(image_rgb)
    image = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)
    H, W, _ = image.shape

    predicted = "..."
    confidence = 0.0

    if results.multi_hand_landmarks:
        sorted_hands = sorted(results.multi_hand_landmarks, key=lambda h: h.landmark[0].x)
        
        x_, y_ = [], []
        for hand_landmarks in sorted_hands:
            try:
                mp_drawing.draw_landmarks(
                    image, hand_landmarks, mp_hands.HAND_CONNECTIONS,
                    mp_drawing_styles.get_default_hand_landmarks_style(),
                    mp_drawing_styles.get_default_hand_connections_style()
                )
            except:
                mp_drawing.draw_landmarks(image, hand_landmarks, mp_hands.HAND_CONNECTIONS)
            for lm in hand_landmarks.landmark:
                x_.append(lm.x)
                y_.append(lm.y)

        if x_ and y_:
            min_x, min_y = min(x_), min(y_)
            data_aux = []
            
            for hand_landmarks in sorted_hands:
                for lm in hand_landmarks.landmark:
                    data_aux.append(lm.x - min_x)
                    data_aux.append(lm.y - min_y)
            
            while len(data_aux) < 84:
                data_aux.append(0.0)
            data_aux = data_aux[:84]

            # Inference
            input_data = np.array([data_aux], dtype=np.float32)
            interpreter.set_tensor(input_details[0]['index'], input_data)
            interpreter.invoke()
            output = interpreter.get_tensor(output_details[0]['index'])
            
            idx = np.argmax(output[0])
            prob = output[0][idx]
            
            if prob > 0.5:
                label = labels[idx]
                letter_buffer.append(label)
                if len(letter_buffer) > 5:
                    letter_buffer.pop(0)
                
                count = letter_buffer.count(label)
                if count >= 3:
                    predicted = label
                    confidence = prob

    # UI
    cv2.rectangle(image, (0, 0), (W, 80), (0, 0, 0), -1)
    cv2.putText(image, "Mode: LETTRES", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (100, 200, 255), 2)
    
    color = (0, 255, 0) if confidence > 0.7 else (0, 165, 255)
    text = f"Lettre: {predicted} ({confidence:.2f})"
    cv2.putText(image, text, (10, 65), cv2.FONT_HERSHEY_SIMPLEX, 1, color, 3)

    cv2.imshow('Test Modele Lettres', image)
    
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
print("\n✅ Test terminé!")
