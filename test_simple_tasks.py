"""
Test Simple - Utilise MediaPipe Tasks API (la version que vous avez)
====================================================================
Ce script utilise EXACTEMENT la même API que inference_classifier.py
"""

import cv2
import numpy as np
import tensorflow as tf
import time

# MediaPipe Tasks API (compatible avec votre version)
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import mediapipe as mp

print("=" * 60)
print("🔍 TEST MODELE LETTRES - MediaPipe Tasks API")
print("=" * 60)

# 1. Load TFLite model
MODEL_PATH = 'flutter_app/assets/model_letters.tflite'
LABELS_PATH = 'flutter_app/assets/model_letters_labels.txt'

with open(LABELS_PATH, 'r') as f:
    labels = [line.strip() for line in f.readlines() if line.strip()]

print(f"✅ {len(labels)} lettres: {labels}")

interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"\n📊 Modèle: {input_details[0]['shape']} -> {output_details[0]['shape']}")

# 2. Initialize MediaPipe Hand Landmarker (Tasks API)
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

print("✅ MediaPipe Tasks API initialisé\n")
print("=" * 60)
print("📷 Démarrage caméra... (Appuyez sur 'Q' pour quitter)")
print("=" * 60)

# 3. Open camera
cap = cv2.VideoCapture(0)
letter_buffer = []

while cap.isOpened():
    success, frame = cap.read()
    if not success:
        continue

    H, W, _ = frame.shape
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
    
    # Detect hands
    results = detector.detect(mp_image)

    predicted = "..."
    confidence = 0.0

    if results.hand_landmarks:
        # SAME AS PYTHON: Sort hands left-to-right
        sorted_hands = sorted(results.hand_landmarks, key=lambda h: h[0].x)
        
        x_, y_ = [], []
        for hand_landmarks in sorted_hands:
            # Draw landmarks
            for landmark in hand_landmarks:
                x_px = int(landmark.x * W)
                y_px = int(landmark.y * H)
                cv2.circle(frame, (x_px, y_px), 5, (0, 255, 0), -1)
            
            for landmark in hand_landmarks:
                x_.append(landmark.x)
                y_.append(landmark.y)

        if x_ and y_:
            min_x, min_y = min(x_), min(y_)
            data_aux = []
            
            for hand_landmarks in sorted_hands:
                for landmark in hand_landmarks:
                    data_aux.append(landmark.x - min_x)
                    data_aux.append(landmark.y - min_y)
            
            # Pad to 84
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
            
            # SAME THRESHOLD AS PYTHON: 0.4 (using 0.5 for safety)
            if prob > 0.4:
                label = labels[idx]
                letter_buffer.append(label)
                if len(letter_buffer) > 5:
                    letter_buffer.pop(0)
                
                count = letter_buffer.count(label)
                if count >= 3:
                    predicted = label
                    confidence = prob
            else:
                letter_buffer.clear()

    # UI
    cv2.rectangle(frame, (0, 0), (W, 80), (0, 0, 0), -1)
    cv2.putText(frame, "Mode: LETTRES", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (100, 200, 255), 2)
    
    color = (0, 255, 0) if confidence > 0.7 else (0, 165, 255)
    text = f"Lettre: {predicted} ({confidence:.2f})"
    cv2.putText(frame, text, (10, 65), cv2.FONT_HERSHEY_SIMPLEX, 1, color, 3)

    cv2.imshow('Test Lettres - MediaPipe Tasks', frame)
    
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
print("\n✅ Test terminé!")
