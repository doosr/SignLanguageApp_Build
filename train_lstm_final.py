import pickle
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout, Input
from tensorflow.keras.callbacks import ModelCheckpoint, EarlyStopping
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
import os

# --- CONFIGURATION ---
DATA_FILE = 'sequence_data.pickle'
MODEL_TFLITE_PATH = 'flutter_app/assets/model_words_lstm.tflite'
SEQUENCE_LENGTH = 15
FEATURES_PER_FRAME = 84

def load_data():
    if not os.path.exists(DATA_FILE):
        print(f"❌ Error: {DATA_FILE} not found. Run create_dataset.py first.")
        return None, None, None

    print(f"📂 Loading data from {DATA_FILE}...")
    with open(DATA_FILE, 'rb') as f:
        data_dict = pickle.load(f)

    data = np.asarray(data_dict['data'])
    labels = np.asarray(data_dict['labels'])
    
    print(f"📊 Raw data shape: {data.shape}")  # Should be (samples, 1260) if flattened
    
    # Reshape Flattened (1260) -> Sequence (15, 84)
    # 15 frames * 84 landmarks = 1260 features
    try:
        data = data.reshape(-1, SEQUENCE_LENGTH, FEATURES_PER_FRAME)
        print(f"🔄 Reshaped to LSTM format: {data.shape}")
    except ValueError as e:
        print(f"❌ Error reshaping data: {e}. Check your SEQUENCE_LENGTH setting.")
        return None, None, None

    return data, labels

def train_model():
    # 1. Load Data
    data, labels = load_data()
    if data is None: return

    # 2. Encode Labels (String -> Integer)
    le = LabelEncoder()
    labels_encoded = le.fit_transform(labels)
    classes = le.classes_
    num_classes = len(classes)
    
    print(f"🏷️  Classes found ({num_classes}): {classes}")
    
    # Save labels for Flutter
    with open('flutter_app/assets/model_words_labels.txt', 'w', encoding='utf-8') as f:
        f.write('\n'.join(classes))
    print("📝 Labels saved to flutter_app/assets/model_words_labels.txt")

    # 3. Split Train/Test
    # Stratify to ensure all classes are represented in train and test
    try:
        x_train, x_test, y_train, y_test = train_test_split(
            data, labels_encoded, test_size=0.2, shuffle=True, stratify=labels_encoded, random_state=42
        )
    except ValueError:
        print("⚠️ Warning: Some classes have too few samples for stratification. Falling back to random split.")
        x_train, x_test, y_train, y_test = train_test_split(
            data, labels_encoded, test_size=0.2, shuffle=True, random_state=42
        )

    # 4. Define LSTM Architecture
    model = Sequential([
        Input(shape=(SEQUENCE_LENGTH, FEATURES_PER_FRAME)),
        
        # LSTM Layers - The "Brain" for temporal/sequence data
        LSTM(64, return_sequences=True), 
        Dropout(0.2), # Prevent overfitting
        LSTM(32, return_sequences=False),
        Dropout(0.2),
        
        # Classification Layers
        Dense(32, activation='relu'),
        Dense(num_classes, activation='softmax') # Output probabilities
    ])

    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    model.summary()

    # 5. Train
    print("\n🚀 Starting Training...")
    early_stopping = EarlyStopping(monitor='val_loss', patience=15, restore_best_weights=True)
    
    history = model.fit(
        x_train, y_train,
        epochs=100,
        batch_size=16,
        validation_data=(x_test, y_test),
        callbacks=[early_stopping]
    )

    # 6. Evaluate
    loss, acc = model.evaluate(x_test, y_test)
    print(f"\n✅ Final Accuracy: {acc*100:.2f}%")

    # 7. Convert to TFLite
    print("\n📦 Converting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Enable TF Ops (sometimes needed for LSTM) -> Actually standard LSTM is supported
    converter.target_spec.supported_ops = [
      tf.lite.OpsSet.TFLITE_BUILTINS, # Enable TensorFlow Lite ops.
      tf.lite.OpsSet.SELECT_TF_OPS    # Enable TensorFlow ops.
    ]
    # Reduce size
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    tflite_model = converter.convert()

    # Save
    with open(MODEL_TFLITE_PATH, 'wb') as f:
        f.write(tflite_model)
    
    print(f"🎉 Success! TFLite model saved to: {MODEL_TFLITE_PATH}")
    print("👉 Now: Rebuild your Flutter app to use this new brain!")

if __name__ == "__main__":
    train_model()
