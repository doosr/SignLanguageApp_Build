import cv2
import numpy as np
import tensorflow.lite as tflite
import mediapipe as mp
import time

# --- Config ---
MODEL_LETTERS_PATH = 'flutter_app/assets/model_letters.tflite'
MODEL_WORDS_PATH = 'flutter_app/assets/model_words.tflite'
LABELS_LETTERS_PATH = 'flutter_app/assets/model_letters_labels.txt'
LABELS_WORDS_PATH = 'flutter_app/assets/model_words_labels.txt'

SEQUENCE_LENGTH = 15

# --- Load Labels ---
def load_labels(path):
    with open(path, 'r', encoding='utf-8') as f:
        return [line.strip() for line in f.readlines() if line.strip()]

labels_letters = load_labels(LABELS_LETTERS_PATH)
labels_words = load_labels(LABELS_WORDS_PATH)

print(f"✅ Loaded {len(labels_letters)} letter labels and {len(labels_words)} word labels.")

# --- Load Models ---
interpreter_letters = tflite.Interpreter(model_path=MODEL_LETTERS_PATH)
interpreter_letters.allocate_tensors()

interpreter_words = tflite.Interpreter(model_path=MODEL_WORDS_PATH)
interpreter_words.allocate_tensors()

input_details_letters = interpreter_letters.get_input_details()
output_details_letters = interpreter_letters.get_output_details()

input_details_words = interpreter_words.get_input_details()
output_details_words = interpreter_words.get_output_details()

print("✅ TFLite Models loaded.")

# --- MediaPipe ---
import mediapipe as mp
try:
    from mediapipe import solutions
    mp_hands = solutions.hands
    mp_drawing = solutions.drawing_utils
    mp_drawing_styles = solutions.drawing_styles
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

# --- State ---
mode = "LETTRES" # or "MOTS"
sequence_buffer = []
predicted_text = ""
accuracy = 0.0

cap = cv2.VideoCapture(0)

print("\n📷 Starting Camera... Press 'm' to toggle mode, 'q' to quit.\n")

while cap.isOpened():
    success, image = cap.read()
    if not success:
        print("Ignoring empty camera frame.")
        continue

    image.flags.writeable = False
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = hands.process(image_rgb)

    image.flags.writeable = True
    image = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)
    H, W, _ = image.shape

    data_aux = []
    x_ = []
    y_ = []

    if results.hand_landmarks:
        # Sort hands by x position to ensure consistency (left hand first in list if on left side of screen)
        # Note: MediaPipe x is normalized [0, 1].
        sorted_hands = sorted(results.hand_landmarks, key=lambda h: h.landmark[0].x)
        
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
            # If only 1 hand detected (42 features), pad the remaining 42 with 0
            while len(data_aux) < 84:
                data_aux.append(0.0)
            
            # Truncate if somehow larger (shouldn't happen with max_num_hands=2)
            data_aux = data_aux[:84]

            # --- INFERENCE ---
            if mode == "LETTRES":
                # Reshape for model: (1, 84)
                input_data = np.array([data_aux], dtype=np.float32)
                interpreter_letters.set_tensor(input_details_letters[0]['index'], input_data)
                interpreter_letters.invoke()
                output_data = interpreter_letters.get_tensor(output_details_letters[0]['index'])
                
                idx = np.argmax(output_data[0])
                prob = output_data[0][idx]
                
                if prob > 0.6:
                    predicted_text = labels_letters[idx]
                    accuracy = prob
                else:
                    predicted_text = "..."
                    accuracy = 0.0

            elif mode == "MOTS":
                sequence_buffer.append(data_aux)
                if len(sequence_buffer) > SEQUENCE_LENGTH:
                    sequence_buffer.pop(0)
                
                if len(sequence_buffer) == SEQUENCE_LENGTH:
                    # Flatten sequence: (1, 1260) -> 15 * 84 = 1260
                    flattened = []
                    for frame in sequence_buffer:
                        flattened.extend(frame)
                    
                    input_data = np.array([flattened], dtype=np.float32)
                    interpreter_words.set_tensor(input_details_words[0]['index'], input_data)
                    interpreter_words.invoke()
                    output_data = interpreter_words.get_tensor(output_details_words[0]['index'])
                    
                    idx = np.argmax(output_data[0])
                    prob = output_data[0][idx]
                    
                    if prob > 0.8:
                        predicted_text = labels_words[idx]
                        accuracy = prob
                        sequence_buffer = [] # Reset buffer after detection
    
    # Draw UI
    cv2.rectangle(image, (0, 0), (W, 80), (0, 0, 0), -1)
    
    # Mode Text
    cv2.putText(image, f"Mode: {mode} (Press 'M' to switch)", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (200, 200, 200), 2)
    
    # Prediction Text
    color = (0, 255, 0) if accuracy > 0.7 else (0, 165, 255)
    text_display = f"Pred: {predicted_text} ({accuracy:.2f})"
    cv2.putText(image, text_display, (10, 70), cv2.FONT_HERSHEY_SIMPLEX, 1, color, 3)

    cv2.imshow('TFLite Model Test', image)
    
    key = cv2.waitKey(1) & 0xFF
    if key == ord('q'):
        break
    elif key == ord('m'):
        mode = "MOTS" if mode == "LETTRES" else "LETTRES"
        sequence_buffer = []
        predicted_text = "..."
        print(f"Switched to mode: {mode}")

cap.release()
cv2.destroyAllWindows()
