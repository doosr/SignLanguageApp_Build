import unittest
import os
import sys
import importlib

class TestSanity(unittest.TestCase):
    def test_files_exist(self):
        """Vérifie que les fichiers essentiels sont présents"""
        required_files = [
            'main.py',
            'buildozer.spec',
            'speech_to_gesture.py',
            'speech_to_image_model.py',
            'gesture_display_utils.py'
        ]
        for f in required_files:
            self.assertTrue(os.path.exists(f), f"Fichier manquant: {f}")

    def test_syntax_check(self):
        """Vérifie qu'il n'y a pas d'erreurs de syntaxe dans les fichiers Python"""
        python_files = [f for f in os.listdir('.') if f.endswith('.py')]
        for py_file in python_files:
            with open(py_file, 'r', encoding='utf-8') as f:
                source = f.read()
            try:
                compile(source, py_file, 'exec')
            except SyntaxError as e:
                self.fail(f"Erreur de syntaxe dans {py_file}: {e}")

if __name__ == '__main__':
    unittest.main()
