import tensorflow as tf
import os

MODEL_PATH = 'flutter_app/assets/model_letters.tflite'

print(f"Checking model: {MODEL_PATH}")
print(f"Size: {os.path.getsize(MODEL_PATH)} bytes")

try:
    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    print("✅ Model loaded and tensors allocated successfully!")
except Exception as e:
    print(f"❌ Failed to load model: {e}")
