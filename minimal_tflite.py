import sys
try:
    import tensorflow.lite as tflite
    print(f"SUCCESS: {tflite.Interpreter}")
except Exception as e:
    print(f"FAILURE: {e}")
    import tensorflow
    print(f"TF Path: {getattr(tensorflow, '__file__', 'None')}")
