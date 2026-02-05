package com.example.flutter_app

import io.flutter.embedding.android.FlutterActivity

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.doosr.signlanguageapp/esp32"
    private var handLandmarker: HandLandmarker? = null
    private var backgroundExecutor: ExecutorService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        backgroundExecutor = Executors.newSingleThreadExecutor()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "detectFromJpeg") {
                val pegBytes = call.argument<ByteArray>("bytes")
                if (pegBytes != null) {
                    processImage(pegBytes, result)
                } else {
                    result.error("INVALID_ARGS", "Bytes are null", null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        setupHandLandmarker()
    }

    private fun setupHandLandmarker() {
        val baseOptionsBuilder = BaseOptions.builder()
            .setModelAssetPath("hand_landmarker.task")

        val baseOptions = baseOptionsBuilder.build()

        val optionsBuilder = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setMinHandDetectionConfidence(0.5f)
            .setMinHandPresenceConfidence(0.5f)
            .setNumHands(2)
            .setRunningMode(RunningMode.IMAGE)

        val options = optionsBuilder.build()

        try {
            handLandmarker = HandLandmarker.createFromOptions(context, options)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun processImage(jpegBytes: ByteArray, result: MethodChannel.Result) {
        backgroundExecutor?.execute {
            try {
                // Decode JPEG
                val bitmap = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
                if (bitmap == null) {
                    runOnUiThread { result.error("DECODE_ERROR", "Could not decode JPEG", null) }
                    return@execute
                }

                // Convert to MPImage
                val mpImage = BitmapImageBuilder(bitmap).build()

                // Run Detection
                if (handLandmarker != null) {
                   val detectionResult: HandLandmarkerResult = handLandmarker!!.detect(mpImage)
                   
                   // Serialize Result
                   val handsList = ArrayList<Map<String, Any>>()
                   
                   for (landmarks in detectionResult.landmarks()) {
                       val landmarksList = ArrayList<Double>()
                       for (landmark in landmarks) {
                           landmarksList.add(landmark.x().toDouble())
                           landmarksList.add(landmark.y().toDouble())
                       }
                       val handMap = HashMap<String, Any>()
                       handMap["landmarks"] = landmarksList
                       handsList.add(handMap)
                   }
                   
                   runOnUiThread { 
                       result.success(handsList) 
                   }
                } else {
                    runOnUiThread { result.error("NOT_INIT", "Landmarker not initialized", null) }
                }
            } catch (e: Exception) {
                 runOnUiThread { result.error("DETECT_ERROR", e.message, null) }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        backgroundExecutor?.shutdown()
        handLandmarker?.close()
    }
}

