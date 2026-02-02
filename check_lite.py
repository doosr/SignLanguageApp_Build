try:
    import tensorflow as tf
    import tensorflow.lite as tflite
    print(f"TF Version: {tf.__version__}")
    print(f"Lite attributes: {[a for a in dir(tflite) if not a.startswith('_')]}")
    if hasattr(tflite, 'Interpreter'):
        print("✅ Interpreter found in tensorflow.lite")
    else:
        print("❌ Interpreter NOT found in tensorflow.lite")
except Exception as e:
    print(f"❌ Error during diagnostic: {e}")
