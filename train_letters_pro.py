import pickle
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout, BatchNormalization, Input
from tensorflow.keras.callbacks import ModelCheckpoint, EarlyStopping, ReduceLROnPlateau
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
import os

# --- PRO CONFIGURATION ---
DATA_FILE = 'data.pickle'
MODEL_TFLITE_PATH = 'flutter_app/assets/model_letters.tflite' # Overwrite standard model
TEST_SPLIT = 0.2
BATCH_SIZE = 32
EPOCHS = 200 # Higher epochs with early stopping

def load_data():
    if not os.path.exists(DATA_FILE):
        print(f"❌ Error: {DATA_FILE} not found. Run create_dataset.py first.")
        return None, None
        
    print(f"📂 Loading data from {DATA_FILE}...")
    with open(DATA_FILE, 'rb') as f:
        data_dict = pickle.load(f)

    data = np.asarray(data_dict['data'])
    labels = np.asarray(data_dict['labels'])
    
    # Check shape
    # Expected: (samples, 84)
    print(f"📊 Data Shape: {data.shape}")
    
    return data, labels

def train_pro_model():
    print("🚀 Starting PRO Training for LETTERS (Static)...")
    
    # 1. Load Data
    data, labels = load_data()
    if data is None: return

    # 2. Encode Labels
    le = LabelEncoder()
    labels_encoded = le.fit_transform(labels)
    classes = le.classes_
    num_classes = len(classes)
    
    print(f"🏷️ Classes ({num_classes}): {classes}")
    
    # Save labels first
    with open('flutter_app/assets/model_letters_labels.txt', 'w', encoding='utf-8') as f:
        f.write('\n'.join(classes))
    print("📝 Labels saved.")

    # 3. Split Data (Stratified)
    x_train, x_test, y_train, y_test = train_test_split(
        data, labels_encoded, test_size=TEST_SPLIT, shuffle=True, stratify=labels_encoded, random_state=42
    )

    # 4. Define PRO Architecture (Deep Dense Network)
    model = Sequential([
        Input(shape=(84,)), # 42 landmarks * 2 (x,y)
        
        # Layer 1: High Capacity
        Dense(128, activation='relu'),
        BatchNormalization(), # Stabilize learning
        Dropout(0.3),         # Prevent overfitting
        
        # Layer 2: Refinement
        Dense(64, activation='relu'),
        BatchNormalization(),
        Dropout(0.2),
        
        # Layer 3: Compression
        Dense(32, activation='relu'),
        
        # Output
        Dense(num_classes, activation='softmax')
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    model.summary()

    # 5. Callbacks for Precision
    callbacks = [
        EarlyStopping(monitor='val_loss', patience=20, restore_best_weights=True, verbose=1),
        ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=10, min_lr=0.00001, verbose=1)
    ]

    # 6. Train
    model.fit(
        x_train, y_train,
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        validation_data=(x_test, y_test),
        callbacks=callbacks
    )

    # 7. Evaluate
    loss, acc = model.evaluate(x_test, y_test)
    print(f"\n🏆 Final Test Accuracy: {acc*100:.2f}%")

    # 8. Convert to TFLite
    print("\n📦 Converting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT] # Quantization for speed/size
    tflite_model = converter.convert()

    with open(MODEL_TFLITE_PATH, 'wb') as f:
        f.write(tflite_model)
    
    print(f"🎉 Standard Model Updated: {MODEL_TFLITE_PATH}")

if __name__ == "__main__":
    train_pro_model()
