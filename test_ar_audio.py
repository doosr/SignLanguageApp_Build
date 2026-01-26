from gtts import gTTS
from pygame import mixer
import os
import time
import tempfile

def test_ar_audio():
    text = "مرحبا بك في تطبيق التعرف على لغة الإشارة"
    print(f"Testing Arabic TTS for: {text}")
    
    try:
        tts = gTTS(text=text, lang='ar')
        with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as f:
            temp_filename = f.name
        
        tts.save(temp_filename)
        print(f"Saved to {temp_filename}")
        
        mixer.init()
        mixer.music.load(temp_filename)
        mixer.music.play()
        
        print("Playing...")
        while mixer.music.get_busy():
            time.sleep(0.1)
            
        mixer.music.stop()
        mixer.quit()
        
        if os.path.exists(temp_filename):
            os.remove(temp_filename)
            print("Cleaned up.")
            
        print("✅ Test successful!")
    except Exception as e:
        print(f"❌ Test failed: {e}")

if __name__ == "__main__":
    test_ar_audio()
