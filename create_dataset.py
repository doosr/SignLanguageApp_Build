import os
import pickle
import cv2
import numpy as np
# Suppress TF oneDNN warnings
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

# Use MediaPipe Holistic for full-body tracking
import mediapipe as mp

# REDUCED SEQUENCE LENGTH: 15
SEQUENCE_LENGTH = 15 

class HolisticLandmarkExtractor:
    def __init__(self, data_dir='./Data'):
        self.data_dir = data_dir
        self.pickle_file_static = 'data.pickle'
        self.pickle_file_sequence = 'sequence_data.pickle'
        
        # Initialize Holistic
        self.mp_holistic = mp.solutions.holistic
        self.holistic = self.mp_holistic.Holistic(
            static_image_mode=True,
            model_complexity=1,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )

    def extract_features(self, img):
        """Extrait les features holistiques (Mains + Corps + Visage)."""
        data_aux = []
        
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        results = self.holistic.process(img_rgb)
        
        # 1. Pose (Corps) - 33 landmarks * 2 (x, y) = 66
        if results.pose_landmarks:
            for landmark in results.pose_landmarks.landmark:
                data_aux.append(landmark.x)
                data_aux.append(landmark.y)
        else:
            data_aux.extend([0.0] * 66)

        # 2. Visage (Sous-ensemble : 10 points clés) - 10 * 2 = 20
        # Indices: Eyes, Nose, Mouth corners
        if results.face_landmarks:
            subset_indices = [0, 13, 14, 17, 33, 133, 159, 263, 362, 386] 
            for idx in subset_indices:
                landmark = results.face_landmarks.landmark[idx]
                data_aux.append(landmark.x)
                data_aux.append(landmark.y)
        else:
            data_aux.extend([0.0] * 20)

        # 3. Mains (Gauche + Droite) - 2 * 21 * 2 = 84
        def extract_hand(hand_landmarks):
            h_data = []
            if hand_landmarks:
                for landmark in hand_landmarks.landmark:
                    h_data.append(landmark.x)
                    h_data.append(landmark.y)
            else:
                h_data.extend([0.0] * 42)
            return h_data

        data_aux.extend(extract_hand(results.left_hand_landmarks))
        data_aux.extend(extract_hand(results.right_hand_landmarks))

        # Total expected features: 170
        if len(data_aux) == 170:
            # Normalization relative au nez (pose 0) pour recentrer
            if results.pose_landmarks:
                ref_x = results.pose_landmarks.landmark[0].x
                ref_y = results.pose_landmarks.landmark[0].y
                for i in range(0, len(data_aux), 2):
                    if data_aux[i] != 0.0:
                        data_aux[i] -= ref_x
                        data_aux[i+1] -= ref_y
            return data_aux
        
        return None

    def process_static_folder(self, folder_path, label, data, labels):
        """Traite un dossier comme collection d'images indépendantes (Lettres)"""
        count = 0
        for img_name in os.listdir(folder_path):
            img_path = os.path.join(folder_path, img_name)
            if not os.path.isfile(img_path): continue
            
            # FIX: Unicode path support for Windows
            try:
                stream = np.fromfile(img_path, dtype=np.uint8)
                img = cv2.imdecode(stream, cv2.IMREAD_COLOR)
            except:
                continue
                
            if img is None: continue
            
            features = self.extract_features(img)
            if features:
                data.append(features)
                labels.append(label)
                count += 1
        return count

    def process_sequence_folder(self, folder_path, label, data, labels):
        """Traite un dossier comme une séquence vidéo (Mots)"""
        files = [f for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f))]
        
        try:
            files.sort(key=lambda f: int(''.join(filter(str.isdigit, f))))
        except:
            files.sort()

        all_frames_features = []
        
        for img_name in files:
            img_path = os.path.join(folder_path, img_name)
            try:
                stream = np.fromfile(img_path, dtype=np.uint8)
                img = cv2.imdecode(stream, cv2.IMREAD_COLOR)
            except Exception as e:
                print(f"Error reading {img_path}: {e}")
                continue
                
            if img is None: continue
            
            features = self.extract_features(img)
            if features:
                all_frames_features.append(features)

        sequences_created = 0
        STRIDE = 4
        if len(all_frames_features) < 60:
            STRIDE = 1
        elif len(all_frames_features) < 100:
            STRIDE = 2
            
        if len(all_frames_features) >= SEQUENCE_LENGTH:
            for start_idx in range(0, len(all_frames_features) - SEQUENCE_LENGTH + 1, STRIDE):
                sampled_sequence = all_frames_features[start_idx : start_idx + SEQUENCE_LENGTH]
                flattened_sequence = np.array(sampled_sequence).flatten().tolist()
                data.append(flattened_sequence)
                labels.append(label)
                sequences_created += 1
            
            if sequences_created < 2:
                print(f"  - Augmenting data for '{label}' (only {sequences_created} found)...")
                original_seq = data[-1]
                noisy_seq = np.array(original_seq) + np.random.normal(0, 0.01, len(original_seq))
                data.append(noisy_seq.tolist())
                labels.append(label)
                sequences_created += 1
            
            print(f"  - Generated {sequences_created} sequences for '{label}' (from {len(all_frames_features)} frames)")
            return sequences_created
            
        elif len(all_frames_features) > 10:
             indices = np.linspace(0, len(all_frames_features) - 1, SEQUENCE_LENGTH, dtype=int)
             sampled_sequence = [all_frames_features[i] for i in indices]
             flattened_sequence = np.array(sampled_sequence).flatten().tolist()
             
             data.append(flattened_sequence)
             labels.append(label)
             
             noisy_seq = np.array(flattened_sequence) + np.random.normal(0, 0.01, len(flattened_sequence))
             data.append(noisy_seq.tolist())
             labels.append(label)
             
             print(f"  - Upsampled & Augmented 2 sequences for '{label}' (from {len(all_frames_features)} frames)")
             return 2
        else:
            print(f"  - Warning: Not enough frames for '{label}' sequence ({len(all_frames_features)} frames). Skipping.")
            return 0

    def extract_landmarks(self):
        data_static = []
        labels_static = []
        data_sequence = []
        labels_sequence = []
        
        print(f"Parsing directories in {self.data_dir} using Holistic Extraction...")
        
        for root, dirs, files in os.walk(self.data_dir):
            if not files: continue
            label = os.path.basename(root)
            image_files = [f for f in files if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
            if not image_files: continue
            
            if len(label) == 1:
                print(f"Processing STATIC category: {label} (Path: {root})")
                self.process_static_folder(root, label, data_static, labels_static)
            else:
                print(f"Processing SEQUENCE category: {label} (Path: {root})")
                self.process_sequence_folder(root, label, data_sequence, labels_sequence)
        
        if data_static:
            with open(self.pickle_file_static, 'wb') as f:
                pickle.dump({'data': data_static, 'labels': labels_static}, f)
            print(f"\n✅ Static Dataset saved: {len(data_static)} samples ({len(data_static[0])} features/sample)")
            
        if data_sequence:
            with open(self.pickle_file_sequence, 'wb') as f:
                pickle.dump({'data': data_sequence, 'labels': labels_sequence}, f)
            print(f"✅ Sequence Dataset saved: {len(data_sequence)} samples ({len(data_sequence[0])} features/sample)")
        
        if not data_static and not data_sequence:
            print("\n❌ No data collected. Check your Data directory structure.")

if __name__ == "__main__":
    extractor = HolisticLandmarkExtractor()
    extractor.extract_landmarks()
