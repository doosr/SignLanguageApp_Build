import sys
import os

print("="*40)
print("🔍 DIAGNOSTIC TENSORFLOW")
print("="*40)

print(f"Python Executable: {sys.executable}")
print(f"CWD: {os.getcwd()}")
print(f"Path: {sys.path[:3]}...")

print("-" * 20)
try:
    import tensorflow
    print(f"✅ TensorFlow imported")
    print(f"   Source: {getattr(tensorflow, '__file__', 'Unknown')}")
    print(f"   Has __version__? {hasattr(tensorflow, '__version__')}")
    if hasattr(tensorflow, '__version__'):
        print(f"   Version: {tensorflow.__version__}")
    
    print(f"   Has lite? {hasattr(tensorflow, 'lite')}")
    
    try:
        import tensorflow.lite
        print(f"   ✅ import tensorflow.lite SUCCEEDED")
    except ImportError as e:
        print(f"   ❌ import tensorflow.lite FAILED: {e}")

    print(f"   Dir(tf) start: {dir(tensorflow)[:10]}")

except ImportError as e:
    print(f"❌ TensorFlow import failed: {e}")
except Exception as e:
    print(f"❌ Unexpected error: {e}")

print("="*40)
