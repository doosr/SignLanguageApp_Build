
import pickle
import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
import os

def convert_dataset_to_tflite(data_file, model_output_name, is_sequence=False):
    print(f"\n--- Traitement de {data_file} ---")
    if not os.path.exists(data_file):
        print(f"❌ Fichier introurvable: {data_file}")
        return

    # 1. Charger les données
    with open(data_file, 'rb') as f:
        data_dict = pickle.load(f)
    
    data = np.asarray(data_dict['data'])
    labels = np.asarray(data_dict['labels'])
    
    # Nettoyage des données (Séquences vs Statique)
    # Si séquence, data peut avoir une forme (N, Sequence_Length, Features) ou (N, Solt_Features)
    # Ici on suppose que tout est déjà aplati ou prêt pour le Dense layer
    
    print(f"Data shape: {data.shape}")
    print(f"Labels shape: {labels.shape}")

    # 2. Encoder les labels
    le = LabelEncoder()
    labels_encoded = le.fit_transform(labels)
    classes = le.classes_
    print(f"Classes détectées ({len(classes)}): {classes}")
    
    # Sauvegarder les labels pour Flutter
    labels_file = model_output_name.replace('.tflite', '_labels.txt')
    with open(labels_file, 'w', encoding='utf-8') as f:
        for c in classes:
            f.write(c + '\n')
    print(f"📝 Labels sauvegardés dans {labels_file}")

    # 3. Préparer Train/Test
    X_train, X_test, y_train, y_test = train_test_split(
        data, labels_encoded, test_size=0.2, shuffle=True, stratify=labels_encoded, random_state=42
    )

    # 4. Créer Modèle Keras (Compatible TFLite)
    model = tf.keras.models.Sequential([
        # Input layer
        tf.keras.layers.Input(shape=(data.shape[1],)),
        
        # Dense layers
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dropout(0.1),
        
        # Output layer
        tf.keras.layers.Dense(len(classes), activation='softmax')
    ])

    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )

    # 5. Entraîner
    print("⏳ Entraînement en cours...")
    model.fit(X_train, y_train, epochs=50, batch_size=32, validation_data=(X_test, y_test), verbose=0)
    
    loss, accuracy = model.evaluate(X_test, y_test, verbose=0)
    print(f"✅ Précision (Accuracy): {accuracy*100:.2f}%")

    # 6. Convertir en TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    # Optimisation pour mobile (taille/vitesse)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    # Sauvegarder
    with open(model_output_name, 'wb') as f:
        f.write(tflite_model)
    print(f"💾 Modèle TFLite sauvegardé: {model_output_name}")


if __name__ == "__main__":
    # S'assurer que le dossier flutter assets existe
    assets_dir = os.path.join("flutter_app", "assets")
    if not os.path.exists(assets_dir):
        os.makedirs(assets_dir)
        
    # 1. Modèle Lettres
    convert_dataset_to_tflite(
        'data.pickle', 
        os.path.join(assets_dir, 'model_letters.tflite')
    )
    
    # 2. Modèle Mots (Séquence)
    # Note: Si sequence_data contient des séquences temporelles, Dense layer traite l'input aplati (flattened).
    # C'est ce que faisait le RandomForest aussi.
    convert_dataset_to_tflite(
        'sequence_data.pickle',
        os.path.join(assets_dir, 'model_words.tflite'),
        is_sequence=True
    )
    
    print("\n🚀 Conversion terminée ! Intégrez ces fichiers dans flutter_app/assets/")
