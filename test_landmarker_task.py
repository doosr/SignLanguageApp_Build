import cv2
import mediapipe as mp
import time
import numpy as np

# Import the new MediaPipe Tasks API
BaseOptions = mp.tasks.BaseOptions
HandLandmarker = mp.tasks.vision.HandLandmarker
HandLandmarkerOptions = mp.tasks.vision.HandLandmarkerOptions
VisionRunningMode = mp.tasks.vision.RunningMode

# Path to your .task file
MODEL_PATH = 'hand_landmarker.task'

# Hardcoded connections if mp.solutions is unavailable
HAND_CONNECTIONS = [
    (0, 1), (1, 2), (2, 3), (3, 4),        # Thumb
    (0, 5), (5, 6), (6, 7), (7, 8),        # Index
    (5, 9), (9, 10), (10, 11), (11, 12),   # Middle
    (9, 13), (13, 14), (14, 15), (15, 16), # Ring
    (13, 17), (17, 18), (18, 19), (19, 20),# Pinky
    (0, 17)                                # Wrist to Pinky
]

def draw_landmarks_on_image(image, detection_result):
    """Draws hand landmarks on the image using OpenCV."""
    hand_landmarks_list = detection_result.hand_landmarks
    annotated_image = np.copy(image)
    height, width, _ = annotated_image.shape

    # Loop through the detected hands to visualize.
    for hand_landmarks in hand_landmarks_list:
        
        # Draw connections
        for connection in HAND_CONNECTIONS:
            start_idx = connection[0]
            end_idx = connection[1]
            
            if start_idx < len(hand_landmarks) and end_idx < len(hand_landmarks):
                start_point = hand_landmarks[start_idx]
                end_point = hand_landmarks[end_idx]
                
                x1 = int(start_point.x * width)
                y1 = int(start_point.y * height)
                x2 = int(end_point.x * width)
                y2 = int(end_point.y * height)
                
                cv2.line(annotated_image, (x1, y1), (x2, y2), (200, 200, 200), 2)

        # Draw points
        for landmark in hand_landmarks:
            x = int(landmark.x * width)
            y = int(landmark.y * height)
            cv2.circle(annotated_image, (x, y), 5, (0, 255, 0), -1)
            
    return annotated_image

# Create a hand landmarker instance with the live stream mode:
options = HandLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=MODEL_PATH),
    running_mode=VisionRunningMode.LIVE_STREAM,
    num_hands=2,
    result_callback=lambda result, output_image, timestamp_ms: save_result(result, output_image, timestamp_ms))

# Global variable to store the latest result
latest_result = None

def save_result(result, output_image, timestamp_ms):
    global latest_result
    latest_result = result

print(f"Loading model from {MODEL_PATH}...")
try:
    with HandLandmarker.create_from_options(options) as landmarker:
        cap = cv2.VideoCapture(0)
        print("Camera started. Press 'q' to exit.")
        
        while cap.isOpened():
            success, image = cap.read()
            if not success:
                print("Ignoring empty camera frame.")
                continue

            # Convert to RGB (MediaPipe requires RGB)
            rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_image)
            
            # Send live image data to perform hand landmarks detection.
            landmarker.detect_async(mp_image, int(time.time() * 1000))

            # Draw visualization based on the latest result immediately
            if latest_result:
                image = draw_landmarks_on_image(image, latest_result)

            cv2.imshow('MediaPipe Hand Landmarker Task', image)
            
            if cv2.waitKey(5) & 0xFF == ord('q'):
                break
                
        cap.release()
        cv2.destroyAllWindows()

except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
