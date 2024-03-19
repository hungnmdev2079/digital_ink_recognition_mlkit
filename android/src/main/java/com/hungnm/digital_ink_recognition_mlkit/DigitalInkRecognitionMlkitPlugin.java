package com.hungnm.digital_ink_recognition_mlkit;

import androidx.annotation.NonNull;

import com.google.mlkit.common.MlKitException;
import com.google.mlkit.common.model.DownloadConditions;
import com.google.mlkit.common.model.RemoteModelManager;
import com.google.mlkit.vision.digitalink.DigitalInkRecognition;
import com.google.mlkit.vision.digitalink.DigitalInkRecognitionModel;
import com.google.mlkit.vision.digitalink.DigitalInkRecognitionModelIdentifier;
import com.google.mlkit.vision.digitalink.DigitalInkRecognizer;
import com.google.mlkit.vision.digitalink.DigitalInkRecognizerOptions;
import com.google.mlkit.vision.digitalink.Ink;
import com.google.mlkit.vision.digitalink.RecognitionCandidate;
import com.google.mlkit.vision.digitalink.RecognitionContext;
import com.google.mlkit.vision.digitalink.RecognitionResult;
import com.google.mlkit.vision.digitalink.WritingArea;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** DigitalInkRecognitionMlkitPlugin */
public class DigitalInkRecognitionMlkitPlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private static final String START = "vision#startDigitalInkRecognizer";
  private static final String CLOSE = "vision#closeDigitalInkRecognizer";
  private static final String DOWNLOAD = "vision#downLoadModels";
  private static final String DELETE = "vision#deleteModels";
  private MethodChannel channel;
  private final Map<String, DigitalInkRecognizer> instances = new HashMap<>();

  RemoteModelManager remoteModelManager = RemoteModelManager.getInstance();

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "digital_ink_recognition_mlkit");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    String method = call.method;
    switch (method) {
      case START:
        handleDetection(call, result);
        break;
      case CLOSE:
        closeDetector(call);
        break;
      case DOWNLOAD:
        downLoadModel(call, result);
        break;
      case DELETE:
        deleteModel(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  private void handleDetection(MethodCall call, final MethodChannel.Result result) {
    String tag = call.argument("model");
    DigitalInkRecognitionModel model = getModel(tag, result);
    if (model == null) return;
    remoteModelManager.isModelDownloaded(model).addOnSuccessListener(isDownloaded -> {
      if(isDownloaded){
      }else{
        result.error("Model Error", "Model has not been downloaded yet ", null);
      }
    });

    String id = call.argument("id");
    com.google.mlkit.vision.digitalink.DigitalInkRecognizer recognizer = instances.get(id);
    if (recognizer == null) {
      recognizer = DigitalInkRecognition.getClient(DigitalInkRecognizerOptions.builder(model).build());
      instances.put(id, recognizer);
    }

    Map<String, Object> inkMap = call.argument("ink");
    List<Map<String, Object>> strokeList = (List<Map<String, Object>>) inkMap.get("strokes");
    Ink.Builder inkBuilder = Ink.builder();
    for (final Map<String, Object> strokeMap : strokeList) {
      Ink.Stroke.Builder strokeBuilder = Ink.Stroke.builder();
      List<Map<String, Object>> pointsList = (List<Map<String, Object>>) strokeMap.get("points");
      for (final Map<String, Object> point : pointsList) {
        float x = (float) (double) point.get("x");
        float y = (float) (double) point.get("y");
        Object t0 = point.get("t");
        long t;
        if (t0 instanceof Integer) {
          t = (int) t0;
        } else {
          t = (long) t0;
        }
        Ink.Point strokePoint = Ink.Point.create(x, y, t);
        strokeBuilder.addPoint(strokePoint);
      }
      inkBuilder.addStroke(strokeBuilder.build());
    }
    Ink ink = inkBuilder.build();

    RecognitionContext context = null;
    Map<String, Object> contextMap = call.argument("context");
    if (contextMap != null) {
      RecognitionContext.Builder builder = RecognitionContext.builder();
      String preContext = (String) contextMap.get("preContext");
      if (preContext != null) {
        builder.setPreContext(preContext);
      } else {
        builder.setPreContext("");
      }

      Map<String, Object> writingAreaMap = (Map<String, Object>) contextMap.get("writingArea");
      if (writingAreaMap != null) {
        float width = (float) (double) writingAreaMap.get("width");
        float height = (float) (double) writingAreaMap.get("height");
        builder.setWritingArea(new WritingArea(width, height));
      }

      context = builder.build();
    }

    if (context != null) {
      recognizer.recognize(ink, context)
              .addOnSuccessListener(recognitionResult -> process(recognitionResult, result))
              .addOnFailureListener(e -> result.error("recognition Error", e.toString(), null));
    } else {
      recognizer.recognize(ink)
              .addOnSuccessListener(recognitionResult -> process(recognitionResult, result))
              .addOnFailureListener(e -> result.error("recognition Error", e.toString(), null));
    }
  }

  private void process(RecognitionResult recognitionResult, final MethodChannel.Result result) {
    List<Map<String, Object>> candidatesList = new ArrayList<>(recognitionResult.getCandidates().size());
    for (RecognitionCandidate candidate : recognitionResult.getCandidates()) {
      Map<String, Object> candidateData = new HashMap<>();
      double score = 0;
      if (candidate.getScore() != null)
        score = candidate.getScore().doubleValue();
      candidateData.put("text", candidate.getText());
      candidateData.put("score", score);
      candidatesList.add(candidateData);
    }
    result.success(candidatesList);
  }

  private void closeDetector(MethodCall call) {
    String id = call.argument("id");
    com.google.mlkit.vision.digitalink.DigitalInkRecognizer recognizer = instances.get(id);
    if (recognizer == null) return;
    recognizer.close();
    instances.remove(id);
  }

  private void downLoadModel(MethodCall call, final MethodChannel.Result result){
    String tag = call.argument("model");
    DigitalInkRecognitionModel model = getModel(tag, result);
    remoteModelManager.isModelDownloaded(model).addOnSuccessListener(isDownloaded -> {
      if(isDownloaded){
        result.success(true);
      }else{
        remoteModelManager
                .download(model, new DownloadConditions.Builder().build())
                .addOnSuccessListener(aVoid -> result.success(true))
                .addOnFailureListener(
                        e -> result.success(false));
      }
    });

  }

  private void deleteModel(MethodCall call, final MethodChannel.Result result){
    String tag = call.argument("model");
    DigitalInkRecognitionModel model = getModel(tag, result);
    remoteModelManager.deleteDownloadedModel(model)
            .addOnSuccessListener(
                    aVoid -> result.success(true))
            .addOnFailureListener(
                    e -> result.success(false));
  }

  private DigitalInkRecognitionModel getModel(String tag, final MethodChannel.Result result) {
    DigitalInkRecognitionModelIdentifier modelIdentifier;
    try {
      modelIdentifier = DigitalInkRecognitionModelIdentifier.fromLanguageTag(tag);
    } catch (MlKitException e) {
      result.error("Failed to create model identifier", e.toString(), null);
      return null;
    }
    if (modelIdentifier == null) {
      result.error("Model Identifier error", "No model was found", null);
      return null;
    }
    return DigitalInkRecognitionModel.builder(modelIdentifier).build();
  }
}
