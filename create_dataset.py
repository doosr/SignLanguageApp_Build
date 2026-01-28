import os
import pickle
import cv2
import numpy as np
# Suppress TF oneDNN warnings
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

# Use MediaPipe Tasks API (compatible with 0.10.x)
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import mediapipe as mp

# REDUCED SEQUENCE LENGTH: 30 -> 15
# This makes recognition FASTER and easier to trigger
SEQUENCE_LENGTH = 15 

class HandLandmarkExtractor:
    def __init__(self, data_dir='./Data'):
        self.data_dir = data_dir
        self.pickle_file_static = 'data.pickle'    # Pour les lettres (A-Z)
        self.pickle_file_sequence = 'sequence_data.pickle' # Pour les mots (vidéo)
        
        # Initialize hand landmarker using Tasks API
        base_options = python.BaseOptions(model_asset_path='hand_landmarker.task')
        options = vision.HandLandmarkerOptions(
            base_options=base_options,
            num_hands=2,
            min_hand_detection_confidence=0.3,
            min_hand_presence_confidence=0.3,
            min_tracking_confidence=0.3
        )
        self.detector = vision.HandLandmarker.create_from_options(options)

    def extract_features(self, img):
        """Extrait les 84 features d'une image. Retourne None si aucune main détectée."""
        data_aux = []
        x_ = []
        y_ = []
        
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=img_rgb)
        
        results = self.detector.detect(mp_image)
        
        if results.hand_landmarks:
            # SORT HANDS by x-coordinate (Left to Right) to ensure consistency
            # landmarks[0] is the wrist. We use wrist.x to sort.
            sorted_hands = sorted(results.hand_landmarks, key=lambda h: h[0].x)
            
            for hand_landmarks in sorted_hands:
                for landmark in hand_landmarks:
                    x_.append(landmark.x)
                    y_.append(landmark.y)

            if x_ and y_:
                min_x = min(x_)
                min_y = min(y_)

                for hand_landmarks in sorted_hands:
                    for landmark in hand_landmarks:
                        data_aux.append(landmark.x - min_x)
                        data_aux.append(landmark.y - min_y)

            # Padding
            if len(data_aux) == 42:
                data_aux.extend([0.0] * 42)
            
            if len(data_aux) == 84:
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
        # On suppose que les fichiers sont numérotés ou triables par nom pour former une séquence
        files = [f for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f))]
        
        # Tentative de tri numérique (car(1), car(2)...)
        try:
            files.sort(key=lambda f: int(''.join(filter(str.isdigit, f))))
        except:
            files.sort()

        all_frames_features = []
        
        for img_name in files:
            img_path = os.path.join(folder_path, img_name)
            
            # FIX: Unicode path support for Windows (cv2.imread fails with accents)
            try:
                # Lecture via numpy pour supporter les accents (ex: "métro")
                stream = np.fromfile(img_path, dtype=np.uint8)
                img = cv2.imdecode(stream, cv2.IMREAD_COLOR)
            except Exception as e:
                print(f"Error reading {img_path}: {e}")
                continue
                
            if img is None: continue
            
            features = self.extract_features(img)
            if features:
                all_frames_features.append(features)

        # Création des séquences de longueur fixe (SEQUENCE_LENGTH)
        sequences_created = 0
        
        # Adaptive Stride: If video is short, use smaller stride to get more samples
        STRIDE = 4
        if len(all_frames_features) < 60:
            STRIDE = 1
        elif len(all_frames_features) < 100:
            STRIDE = 2
            
        if len(all_frames_features) >= SEQUENCE_LENGTH:
            # Créer des fenêtres glissantes de 30 frames
            for start_idx in range(0, len(all_frames_features) - SEQUENCE_LENGTH + 1, STRIDE):
                sampled_sequence = all_frames_features[start_idx : start_idx + SEQUENCE_LENGTH]
                flattened_sequence = np.array(sampled_sequence).flatten().tolist()
                data.append(flattened_sequence)
                labels.append(label)
                sequences_created += 1
            
            # --- AUGMENTATION DE SECOURS (Si < 2 échantillons) ---
            # Si malgré le glissement on a qu'un seul échantillon (ex: vidéo de 32 frames, stride 4 -> 1 sample)
            # On ajoute du bruit pour créer un 2ème échantillon artificiel
            if sequences_created < 2:
                print(f"  - Augmenting data for '{label}' (only {sequences_created} found)...")
                original_seq = data[-1] # Le dernier ajouté
                # Ajouter un léger bruit (jitter)
                noisy_seq = np.array(original_seq) + np.random.normal(0, 0.01, len(original_seq))
                data.append(noisy_seq.tolist())
                labels.append(label)
                sequences_created += 1
            
            print(f"  - Generated {sequences_created} sequences for '{label}' (from {len(all_frames_features)} frames)")
            return sequences_created
            
        elif len(all_frames_features) > 10: # Si on a au moins 10 frames mais moins que 30
             # On upsample (étire) pour atteindre 30 frames
             indices = np.linspace(0, len(all_frames_features) - 1, SEQUENCE_LENGTH, dtype=int)
             sampled_sequence = [all_frames_features[i] for i in indices]
             flattened_sequence = np.array(sampled_sequence).flatten().tolist()
             
             # Sample 1 (Original Upsamled)
             data.append(flattened_sequence)
             labels.append(label)
             
             # Sample 2 (Noisy Upsampled) -> Pour garantir au moins 2 samples
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
        
        print(f"Parsing directories in {self.data_dir}...")
        
        for root, dirs, files in os.walk(self.data_dir):
            if not files: continue # Skip directories without files
            
            # Use the leaf directory name as the label
            label = os.path.basename(root)
            
            # Check if this folder contains images
            image_files = [f for f in files if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
            if not image_files: continue
            
            # HEURISTIQUE: Si le label a 1 seule lettre -> Static (A-Z)
            # Sinon -> Sequence (Mots)
            if len(label) == 1:
                print(f"Processing STATIC category: {label} (Path: {root})")
                self.process_static_folder(root, label, data_static, labels_static)
            else:
                print(f"Processing SEQUENCE category: {label} (Path: {root})")
                self.process_sequence_folder(root, label, data_sequence, labels_sequence)
        
        # Save Static Data (Letters)
        if data_static:
            with open(self.pickle_file_static, 'wb') as f:
                pickle.dump({'data': data_static, 'labels': labels_static}, f)
            print(f"\n✅ Static Dataset saved: {len(data_static)} samples ({len(data_static[0])} features/sample)")
            
        # Save Sequence Data (Words)
        if data_sequence:
            with open(self.pickle_file_sequence, 'wb') as f:
                pickle.dump({'data': data_sequence, 'labels': labels_sequence}, f)
            print(f"✅ Sequence Dataset saved: {len(data_sequence)} samples ({len(data_sequence[0])} features/sample)")
        
        if not data_static and not data_sequence:
            print("\n❌ No data collected. Check your Data directory structure.")


if __name__ == "__main__":
    extractor = HandLandmarkExtractor()
    extractor.extract_landmarks()
