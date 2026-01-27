package com.example.flutter_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.framework.image.BitmapImageBuilder
import android.graphics.BitmapFactory
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.flutter_app/mediapipe"
    private var handLandmarker: HandLandmarker? = null
    private val backgroundExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        setupLandmarker()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "detectHands") {
                val imageBytes = call.argument<ByteArray>("image")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                
                if (imageBytes != null && width > 0 && height > 0) {
                    backgroundExecutor.execute {
                         detect(imageBytes, width, height, result)
                    }
                } else {
                    result.error("INVALID_ARGS", "Image data or dims missing", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun setupLandmarker() {
        try {
            val baseOptions = com.google.mediapipe.tasks.core.BaseOptions.builder()
                .setModelAssetPath("hand_landmarker.task")
                .build()

            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(RunningMode.IMAGE)
                .setNumHands(2)
                .setMinHandDetectionConfidence(0.5f)
                .build()

            handLandmarker = HandLandmarker.createFromOptions(context, options)
        } catch (e: Exception) {
            println("MediaPipe Error: ${e.message}")
        }
    }

    private fun detect(bytes: ByteArray, width: Int, height: Int, result: MethodChannel.Result) {
        if (handLandmarker == null) {
            runOnUiThread { result.error("NOT_INIT", "Landmarker not initialized", null) }
            return
        }

        try {
            // Handle NV21 (YUV) from Flutter Camera
            // We need to convert NV21 -> Bitmap -> MPImage
            // Note: MediaPipe might support ByteBuffer direct, but Bitmap is safest bridge.
            
            val yuvImage = android.graphics.YuvImage(bytes, android.graphics.ImageFormat.NV21, width, height, null)
            val out = java.io.ByteArrayOutputStream()
            yuvImage.compressToJpeg(android.graphics.Rect(0, 0, width, height), 50, out)
            val imageBytes = out.toByteArray()
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            
            if (bitmap == null) {
                 runOnUiThread { result.error("DECODE_ERR", "Could not decode bitmap from YUV", null) }
                 return
            }

            // Create MPImage
            val mpImage = BitmapImageBuilder(bitmap).build()
            
            // Run inference
            val landmarkerResult = handLandmarker!!.detect(mpImage)
            
            val handsList = ArrayList<ArrayList<Double>>()
            
            for (landmarks in landmarkerResult.landmarks()) {
                val handPoints = ArrayList<Double>()
                for (point in landmarks) {
                    handPoints.add(point.x().toDouble())
                    handPoints.add(point.y().toDouble())
                }
                handsList.add(handPoints)
            }
            
            runOnUiThread {
                result.success(handsList)
            }
            
        } catch (e: Exception) {
            runOnUiThread { result.error("DETECT_ERR", e.message, null) }
        }
    }
}
