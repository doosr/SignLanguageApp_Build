import pickle
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import numpy as np
import time
import os

class HandGestureClassifier:
    def __init__(self, data_file, model_file):
        self.data_file = data_file
        self.model_file = model_file

    def load_data(self):
        if not os.path.exists(self.data_file):
            print(f"⚠️  {self.data_file} not found. Skipping.")
            return None, None
            
        data_dict = pickle.load(open(self.data_file, 'rb'))
        data = np.asarray(data_dict['data'])
        labels = np.asarray(data_dict['labels'])
        return data, labels

    def train_and_save(self):
        print(f"\n--- Training for {self.data_file} ---")
        data, labels = self.load_data()
        
        if data is None or len(data) == 0:
            return
        
        # Check if stratification is possible (need at least 2 samples per class)
        unique, counts = np.unique(labels, return_counts=True)
        min_samples = np.min(counts)
        use_stratify = min_samples >= 2
        
        if not use_stratify:
            print(f"⚠️  Some classes have only 1 sample. Stratification disabled.")
            print(f"   Classes with 1 sample: {list(unique[counts == 1])}")
        
        x_train, x_test, y_train, y_test = train_test_split(
            data, labels, test_size=0.2, shuffle=True, 
            stratify=labels if use_stratify else None, 
            random_state=42
        )
        
        model = RandomForestClassifier(
            n_estimators=50,
            max_depth=15,
            n_jobs=-1,
            random_state=42,
            verbose=0
        )
        
        print(f"Training on {len(x_train)} samples with {len(data[0])} features each...")
        model.fit(x_train, y_train)
        
        y_predict = model.predict(x_test)
        score = accuracy_score(y_predict, y_test)
        print(f"✅ Accuracy: {score * 100:.2f}%")
        print(f"   Train/Test split: {len(x_train)}/{len(x_test)} samples")
        
        with open(self.model_file, 'wb') as f:
            pickle.dump({'model': model}, f)
        print(f"✅ Model saved to {self.model_file}")
        return score


if __name__ == "__main__":
    print("="*60)
    print("ENTRAÎNEMENT DU MODÈLE DE RECONNAISSANCE HYBRIDE")
    print("="*60)
    
    start_time = time.time()
    
    # 1. Train Static Model (Letters)
    static_trainer = HandGestureClassifier('data.pickle', 'model.p')
    static_trainer.train_and_save()
    
    # 2. Train Sequence Model (Words)
    sequence_trainer = HandGestureClassifier('sequence_data.pickle', 'model_sequence.p')
    sequence_trainer.train_and_save()
    
    elapsed_time = time.time() - start_time
    print(f"\n{'='*60}")
    print(f"✅ Entraînement terminé en {elapsed_time:.2f} secondes")
    print(f"{'='*60}")

