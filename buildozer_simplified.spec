[app]

# (str) Title of your application
title = SignLanguageApp

# (str) Package name
package.name = signlanguageapp

# (str) Package domain (needed for android/ios packaging)
package.domain = org.test

# (str) Source code where the main.py live
source.dir = .

# (list) Source files to include (let empty to include all the files)
source.include_exts = py,png,jpg,kv,atlas,p,pickle

# (str) Application versioning (method 1)
version = 0.1

# (list) Application requirements
# SIMPLIFIED VERSION - mediapipe and opencv removed for easier build
# Add them back one at a time if needed
requirements = python3,kivy,plyer,numpy,pillow,scikit-learn

# (str) Presplash of the application (écran de démarrage)
presplash.filename = %(source.dir)s/icon.png

# (str) Icon of the application (icône de lancement)
icon.filename = %(source.dir)s/icon.png

# (str) Supported orientation (one of landscape, sensorLandscape, portrait or all)
orientation = portrait

#
# Android specific
#

# (bool) Indicate if the application should be fullscreen or not
fullscreen = 0

# (list) Permissions
android.permissions = CAMERA, RECORD_AUDIO, WRITE_EXTERNAL_STORAGE, READ_EXTERNAL_STORAGE

# (int) Target Android API, should be as high as possible.
android.api = 31

# (int) Minimum API your APK will support.
android.minapi = 21

# (list) The Android archs to build for, choices: armeabi-v7a, arm64-v8a, x86, x86_64
android.archs = arm64-v8a

# (bool) enables Android auto backup feature (Android API >= 23)
android.allow_backup = True

# Accept SDK license
android.accept_sdk_license = True

# (str) python-for-android branch to use
# p4a.branch = master

# (str) python-for-android git clone directory
# p4a.source_dir = 

# (str) The directory in which python-for-android should look for your own build recipes
# p4a.local_recipes = 

# (list) Pattern to whitelist for the whole project
# android.whitelist = 

# (bool) If True, then skip trying to update the Android sdk
# android.skip_update = False

# (bool) If True, then automatically accept SDK license
# android.accept_sdk_license = False
