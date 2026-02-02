# Fix pour le Test Python des Modèles TFLite

## Problème

Le modèle LSTM utilise des opérations TensorFlow Flex qui nécessitent une configuration spéciale.

## Solution Rapide

Créez un nouveau script de test qui utilise seulement le modèle de LETTRES (qui fonctionne) :

```bash
python test_letters_only.py
```

## Solution Complète (Pour tester LSTM sur PC)

Installez TensorFlow avec support pour les Flex ops :

```bash
pip install tensorflow==2.14.0
```

Puis utilisez ce script :

```python
import tensorflow as tf

# Enable Flex delegate
interpreter = tf.lite.Interpreter(
    model_path='flutter_app/assets/model_words_lstm.tflite',
    experimental_op_resolver_type=tf.lite.experimental.OpResolverType.BUILTIN_REF
)
```

## Note Importante

✅ **Android App** : La dépendance `tensorflow-lite-select-tf-ops` a été ajoutée au `build.gradle`, donc le modèle LSTM fonctionnera dans l'APK.

❌ **Test Python** : Le test Python nécessite TensorFlow complet (pas juste tflite-runtime)

## Recommandation

Pour tester rapidement sur PC, utilisez le modèle de LETTRES uniquement. Le test complet se fera sur l'appareil Android après le build de l'APK.
