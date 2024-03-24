import Flutter
import UIKit
import MLKitDigitalInkRecognition

public class DigitalInkRecognitionMlkitPlugin: NSObject, FlutterPlugin {
    
    let START = "vision#startDigitalInkRecognizer"
    let CLOSE = "vision#closeDigitalInkRecognizer"
    let DOWNLOAD = "vision#downLoadModels"
    let DELETE = "vision#deleteModels"
    
    var instances = [String: DigitalInkRecognizer]()
    
    var downloadInkResult: FlutterResult?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "digital_ink_recognition_mlkit", binaryMessenger: registrar.messenger())
        let instance = DigitalInkRecognitionMlkitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case START:
            handleDetection(call, result: result)
        case DOWNLOAD:
            downloadModel(call, result: result)
        case DELETE:
            deleteModel(call, result: result)
        case CLOSE:
            if let uid = call.arguments as? String {
                instances.removeValue(forKey: uid)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleDetection(_ call: FlutterMethodCall, result: @escaping FlutterResult){
        guard let args = call.arguments as? [String: Any],
              let modelTag = args["model"] as? String,
              let uid = args["id"] as? String,
              let inkData = args["ink"] as? [String: Any],
              let strokeList = inkData["strokes"] as? [[String: Any]]
        else {
            result(FlutterError(code: "InvalidArguments", message: "Invalid arguments", details: nil))
            return
        }
        guard let modelIndentifier = DigitalInkRecognitionModelIdentifier(forLanguageTag: modelTag) else {
            result(FlutterError(code: "InvalidModelIdentifier", message: "Invalid model identifier", details: nil))
            return
            
        }
        let model = DigitalInkRecognitionModel(modelIdentifier: modelIndentifier)
        let modelManager = ModelManager.modelManager()
        
        if modelManager.isModelDownloaded(model) {
            var recognizer = instances[uid]
            
            
            if recognizer == nil {
                let options = DigitalInkRecognizerOptions(model: model)
                recognizer = DigitalInkRecognizer.digitalInkRecognizer(options: options)
                instances[uid] = recognizer
            }
            
            var strokes = [Stroke]()
            
            for strokeMap in strokeList {
                guard let pointsList = strokeMap["points"] as? [[String:Any]] else { continue }
                var points = [StrokePoint]()
                for pointMap in pointsList {
                    guard let x = pointMap["x"] as? Float64 ,
                          let y = pointMap["y"] as? Float64 ,
                          let t = pointMap["t"] as? Int64 else {
                        continue
                    }
                    let strokePoint = StrokePoint(x: Float(x), y: Float(y), t: Int(t))
                    points.append(strokePoint)
                }
                let stroke = Stroke(points: points)
                strokes.append(stroke)
            }
            
            let ink = Ink(strokes: strokes)
            var context: DigitalInkRecognitionContext?
            
            if let contextMap = args["context"] as? [String: Any] {
                let preContext = contextMap["preContext"] as? String ?? ""
                let writingAreaMap = contextMap["writingArea"] as? [String: Any]
                let width = writingAreaMap?["width"] as? Float ?? 0.0
                let height = writingAreaMap?["height"] as? Float ?? 0.0
                let writingArea = WritingArea(width: width, height: height)
                context = DigitalInkRecognitionContext(preContext: preContext, writingArea: writingArea)
            }
            
            if context != nil {
                recognizer?.recognize(ink: ink, context: context!, completion: { recognitionResult, error in
                    self.processRecognitionResult(recognitionResult, error: error, result: result)
                    
                })
                return
            }
            recognizer?.recognize(ink: ink,  completion: { recognitionResult, error in
                self.processRecognitionResult(recognitionResult, error: error, result: result)
                
            })
            
            
            
            
        }
    }
    func processRecognitionResult(_ recognitionResult: DigitalInkRecognitionResult?, error: Error?, result: FlutterResult) {
        if let error = error {
            result(FlutterError(code: "RecognitionError", message: error.localizedDescription, details: nil))
            return
        }
        
        guard let recognitionResult = recognitionResult else {
            result(nil)
            return
        }
        
        var candidates = [[String: Any]]()
        
        for candidate in recognitionResult.candidates {
            let dictionary: [String: Any] = [
                "text": candidate.text,
                "score": candidate.score?.doubleValue ?? 0.0
            ]
            candidates.append(dictionary)
        }
        
        result(candidates)
    }
    
    private func downloadModel(_ call: FlutterMethodCall, result: @escaping FlutterResult){
        guard let args = call.arguments as? [String: Any],
              let modelTag = args["model"] as? String
        else {
            result(FlutterError(code: "InvalidArguments", message: "Invalid arguments", details: nil))
            return
        }
        guard let modelIndentifier = DigitalInkRecognitionModelIdentifier(forLanguageTag: modelTag) else {
            result(FlutterError(code: "InvalidModelIdentifier", message: "Invalid model identifier", details: nil))
            return
            
        }
        let model = DigitalInkRecognitionModel(modelIdentifier: modelIndentifier)
        let modelManager = ModelManager.modelManager()
        
        if modelManager.isModelDownloaded(model) {
            result(true)
        }else{
            modelManager.download(model, conditions: ModelDownloadConditions(allowsCellularAccess: true, allowsBackgroundDownloading: true))
            NotificationCenter.default.addObserver(self, selector: #selector(receiveTestNotification(_:)), name: .mlkitModelDownloadDidSucceed, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(receiveTestNotification(_:)), name: .mlkitModelDownloadDidFail, object: nil)
            downloadInkResult = result
            
        }
    }
    
    @objc func receiveTestNotification(_ notification: Notification) {
        guard let downloadResult = downloadInkResult else { return }
        
        switch notification.name {
        case .mlkitModelDownloadDidSucceed:
            downloadResult(true)
        case .mlkitModelDownloadDidFail:
            downloadResult(false)
        default:
            break
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    private func deleteModel(_ call: FlutterMethodCall, result: @escaping FlutterResult){
        guard let args = call.arguments as? [String: Any],
              let modelTag = args["model"] as? String
        else {
            result(FlutterError(code: "InvalidArguments", message: "Invalid arguments", details: nil))
            return
        }
        guard let modelIndentifier = DigitalInkRecognitionModelIdentifier(forLanguageTag: modelTag) else {
            result(FlutterError(code: "InvalidModelIdentifier", message: "Invalid model identifier", details: nil))
            return
            
        }
        let model = DigitalInkRecognitionModel(modelIdentifier: modelIndentifier)
        let modelManager = ModelManager.modelManager()
        if modelManager.isModelDownloaded(model) {
            modelManager.deleteDownloadedModel(model, completion:  { error in
                
                if error != nil {
                    result(FlutterError(code: "DeleteError", message: "Delete Model Error", details: nil))
                    return
                }
                result(true)
            })
        }else{
            result(true)
        }
        
    }
}
