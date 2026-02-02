import tensorflow as tf
import os

MODEL_PATH = 'flutter_app/assets/model_words_lstm.tflite'

print(f"Checking LSTM model: {MODEL_PATH}")
print(f"Size: {os.path.getsize(MODEL_PATH)} bytes")

try:
    print("Attempting to load with Flex delegate (standard BUILTIN_REF)...")
    interpreter = tf.lite.Interpreter(
        model_path=MODEL_PATH,
        experimental_op_resolver_type=tf.lite.experimental.OpResolverType.BUILTIN_REF
    )
    interpreter.allocate_tensors()
    print("✅ LSTM Model loaded successfully!")
except Exception as e:
    print(f"❌ Failed to load LSTM model: {e}")
