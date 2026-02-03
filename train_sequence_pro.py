import pickle
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout, BatchNormalization, Input
from tensorflow.keras.callbacks import ModelCheckpoint, EarlyStopping, ReduceLROnPlateau
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
import os

# --- PRO CONFIGURATION ---
DATA_FILE = 'sequence_data.pickle'
MODEL_TFLITE_PATH = 'flutter_app/assets/model_words_lstm.tflite' # Target the new file
SEQUENCE_LENGTH = 15
FEATURES_PER_FRAME = 84
EPOCHS = 200
BATCH_SIZE = 16 # Smaller batch for sequence stability

def load_data():
    if not os.path.exists(DATA_FILE):
        print(f"❌ Error: {DATA_FILE} not found. Run create_dataset.py first.")
        return None, None
        
    print(f"📂 Loading sequence data from {DATA_FILE}...")
    with open(DATA_FILE, 'rb') as f:
        data_dict = pickle.load(f)

    data = np.asarray(data_dict['data'])
    labels = np.asarray(data_dict['labels'])
    
    # Reshape if flat
    if len(data.shape) == 2 and data.shape[1] == SEQUENCE_LENGTH * FEATURES_PER_FRAME:
        data = data.reshape(-1, SEQUENCE_LENGTH, FEATURES_PER_FRAME)
        
    print(f"📊 Data Shape: {data.shape} (Sequences, Time, Features)")
    return data, labels

def train_pro_sequence_model():
    print("🚀 Starting PRO Training for WORDS (LSTM)...")
    
    # 1. Load
    data, labels = load_data()
    if data is None: return

    # 2. Encode
    le = LabelEncoder()
    labels_encoded = le.fit_transform(labels)
    classes = le.classes_
    num_classes = len(classes)
    
    print(f"🏷️ Classes ({num_classes}): {classes}")
    
    # Save labels
    with open('flutter_app/assets/model_words_labels.txt', 'w', encoding='utf-8') as f:
        f.write('\n'.join(classes))

    # 3. Split
    try:
        x_train, x_test, y_train, y_test = train_test_split(
            data, labels_encoded, test_size=0.2, shuffle=True, stratify=labels_encoded, random_state=42
        )
    except ValueError:
        print("⚠️ Not enough samples per class for Stratify. Using random split.")
        x_train, x_test, y_train, y_test = train_test_split(
            data, labels_encoded, test_size=0.2, shuffle=True, random_state=42
        )

    # 4. Define PRO Architecture (Stacked LSTM)
    model = Sequential([
        Input(shape=(SEQUENCE_LENGTH, FEATURES_PER_FRAME)),
        
        # LSTM Layer 1 (Return Sequences for stacking)
        LSTM(128, return_sequences=True),
        BatchNormalization(),
        Dropout(0.3),
        
        # LSTM Layer 2 (Abstract features)
        LSTM(64, return_sequences=False),
        BatchNormalization(),
        Dropout(0.3),
        
        # Dense Classifier
        Dense(64, activation='relu'),
        Dropout(0.2), # Final dropout
        
        Dense(num_classes, activation='softmax')
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.0005), # Slower learning start
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    model.summary()

    # 5. Callbacks
    callbacks = [
        EarlyStopping(monitor='val_loss', patience=25, restore_best_weights=True, verbose=1),
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
    print(f"\n🏆 Final Sequence Accuracy: {acc*100:.2f}%")

    # 8. Convert
    print("\n📦 Converting to TFLite (with static batch size for compatibility)...")
    
    # Define a concrete function with FIXED batch size = 1
    # This is crucial for LSTM conversion to standard TFLite ops (prevents "TensorList" errors)
    run_model = tf.function(lambda x: model(x))
    concrete_func = run_model.get_concrete_function(
        tf.TensorSpec([1, SEQUENCE_LENGTH, FEATURES_PER_FRAME], model.inputs[0].dtype)
    )
    
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
    
    converter.target_spec.supported_ops = [
      tf.lite.OpsSet.TFLITE_BUILTINS,
    ]
    # converter.optimizations = [tf.lite.Optimize.DEFAULT] # Optional: Enable for smaller size
    
    tflite_model = converter.convert()

    with open(MODEL_TFLITE_PATH, 'wb') as f:
        f.write(tflite_model)
        
    print(f"🎉 Sequence Model Updated: {MODEL_TFLITE_PATH}")

if __name__ == "__main__":
    train_pro_sequence_model()
