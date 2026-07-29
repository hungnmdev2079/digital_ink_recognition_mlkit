package com.hungnm.digital_ink_recognition_mlkit

import com.google.mlkit.common.MlKitException
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.vision.digitalink.common.RecognitionResult
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognition
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognitionModel
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognitionModelIdentifier
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognizer
import com.google.mlkit.vision.digitalink.recognition.DigitalInkRecognizerOptions
import com.google.mlkit.vision.digitalink.recognition.Ink
import com.google.mlkit.vision.digitalink.recognition.RecognitionContext
import com.google.mlkit.vision.digitalink.recognition.WritingArea
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DigitalInkRecognitionMlkitPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val instances = mutableMapOf<String, DigitalInkRecognizer>()
    private val remoteModelManager = RemoteModelManager.getInstance()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            START -> handleDetection(call, result)
            CLOSE -> closeDetector(call, result)
            DOWNLOAD -> downloadModel(call, result)
            DELETE -> deleteModel(call, result)
            CHECK -> isModelDownloaded(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun handleDetection(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val tag =
            call.argument<String>("model")
                ?: run {
                    result.error("InvalidArguments", "Missing model argument", null)
                    return
                }
        val model = getModel(tag, result) ?: return

        remoteModelManager
            .isModelDownloaded(model)
            .addOnSuccessListener { isDownloaded ->
                if (!isDownloaded) {
                    result.error("Model Error", "Model has not been downloaded yet", null)
                    return@addOnSuccessListener
                }
                recognize(call, model, result)
            }
            .addOnFailureListener { error ->
                result.error("Model Check Error", error.toString(), null)
            }
    }

    @Suppress("UNCHECKED_CAST")
    private fun recognize(
        call: MethodCall,
        model: DigitalInkRecognitionModel,
        result: MethodChannel.Result,
    ) {
        val id =
            call.argument<String>("id")
                ?: run {
                    result.error("InvalidArguments", "Missing recognizer id", null)
                    return
                }
        val recognizer =
            instances.getOrPut(id) {
                DigitalInkRecognition.getClient(
                    DigitalInkRecognizerOptions.builder(model).build(),
                )
            }

        val inkMap =
            call.argument<Map<String, Any>>("ink")
                ?: run {
                    result.error("InvalidArguments", "Missing ink data", null)
                    return
                }
        val strokeList = inkMap["strokes"] as? List<Map<String, Any>>
        if (strokeList == null) {
            result.error("InvalidArguments", "Missing stroke data", null)
            return
        }

        val inkBuilder = Ink.builder()
        for (strokeMap in strokeList) {
            val strokeBuilder = Ink.Stroke.builder()
            val points = strokeMap["points"] as? List<Map<String, Any>> ?: continue
            for (point in points) {
                val x = (point["x"] as? Number)?.toFloat() ?: continue
                val y = (point["y"] as? Number)?.toFloat() ?: continue
                val timestamp = (point["t"] as? Number)?.toLong() ?: continue
                strokeBuilder.addPoint(Ink.Point.create(x, y, timestamp))
            }
            inkBuilder.addStroke(strokeBuilder.build())
        }
        val ink = inkBuilder.build()

        val context =
            call.argument<Map<String, Any>>("context")?.let { contextMap ->
                val builder =
                    RecognitionContext
                        .builder()
                        .setPreContext(contextMap["preContext"] as? String ?: "")
                (contextMap["writingArea"] as? Map<*, *>)?.let { writingArea ->
                    val width = (writingArea["width"] as? Number)?.toFloat()
                    val height = (writingArea["height"] as? Number)?.toFloat()
                    if (width != null && height != null) {
                        builder.setWritingArea(WritingArea(width, height))
                    }
                }
                builder.build()
            }

        val onSuccess = { recognitionResult: RecognitionResult ->
            processRecognitionResult(recognitionResult, result)
        }
        val onFailure = { error: Exception ->
            result.error("Recognition Error", error.toString(), null)
        }

        if (context == null) {
            recognizer
                .recognize(ink)
                .addOnSuccessListener(onSuccess)
                .addOnFailureListener(onFailure)
        } else {
            recognizer
                .recognize(ink, context)
                .addOnSuccessListener(onSuccess)
                .addOnFailureListener(onFailure)
        }
    }

    private fun processRecognitionResult(
        recognitionResult: RecognitionResult,
        result: MethodChannel.Result,
    ) {
        val candidates =
            recognitionResult.candidates.map { candidate ->
                mapOf(
                    "text" to candidate.text,
                    "score" to (candidate.score?.toDouble() ?: 0.0),
                )
            }
        result.success(candidates)
    }

    private fun closeDetector(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        call.argument<String>("id")?.let { id ->
            instances.remove(id)?.close()
        }
        result.success(null)
    }

    private fun downloadModel(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val model = modelFromCall(call, result) ?: return
        remoteModelManager
            .isModelDownloaded(model)
            .addOnSuccessListener { isDownloaded ->
                if (isDownloaded) {
                    result.success(true)
                    return@addOnSuccessListener
                }
                remoteModelManager
                    .download(model, DownloadConditions.Builder().build())
                    .addOnSuccessListener { result.success(true) }
                    .addOnFailureListener { result.success(false) }
            }
            .addOnFailureListener { result.success(false) }
    }

    private fun deleteModel(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val model = modelFromCall(call, result) ?: return
        remoteModelManager
            .deleteDownloadedModel(model)
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { result.success(false) }
    }

    private fun isModelDownloaded(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val model = modelFromCall(call, result) ?: return
        remoteModelManager
            .isModelDownloaded(model)
            .addOnSuccessListener(result::success)
            .addOnFailureListener { error ->
                result.error("Check Error", error.toString(), null)
            }
    }

    private fun modelFromCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ): DigitalInkRecognitionModel? {
        val tag =
            call.argument<String>("model")
                ?: run {
                    result.error("InvalidArguments", "Missing model argument", null)
                    return null
                }
        return getModel(tag, result)
    }

    private fun getModel(
        tag: String,
        result: MethodChannel.Result,
    ): DigitalInkRecognitionModel? {
        val identifier =
            try {
                DigitalInkRecognitionModelIdentifier.fromLanguageTag(tag)
            } catch (error: MlKitException) {
                result.error("Failed to create model identifier", error.toString(), null)
                return null
            }

        if (identifier == null) {
            result.error("Model Identifier error", "No model was found", null)
            return null
        }
        return DigitalInkRecognitionModel.builder(identifier).build()
    }

    companion object {
        private const val CHANNEL_NAME = "digital_ink_recognition_mlkit"
        private const val START = "vision#startDigitalInkRecognizer"
        private const val CLOSE = "vision#closeDigitalInkRecognizer"
        private const val DOWNLOAD = "vision#downLoadModels"
        private const val DELETE = "vision#deleteModels"
        private const val CHECK = "vision#isModelDownloaded"
    }
}
