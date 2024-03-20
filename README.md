# Google's ML Kit Digital Ink Recognition for Flutter

A Flutter plugin to use [Google's ML Kit Digital Ink Recognition](https://developers.google.com/ml-kit/vision/digital-ink-recognition) to recognize handwritten text on a digital surface in hundreds of languages, as well as classify sketches.


- [Google's ML Kit](https://developers.google.com/ml-kit) was build only for mobile platforms: iOS and Android apps.

- This plugin is not sponsored or maintained by Google. The [authors](https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/AUTHORS) are developers excited about Machine Learning that wanted to expose Google's native APIs to Flutter.

- Google's ML Kit APIs are only developed natively for iOS and Android. This plugin uses Flutter Platform Channels as explained [here](https://docs.flutter.dev/development/platform-integration/platform-channels).


  Messages and responses are passed asynchronously, to ensure the user interface remains responsive. To read more about platform channels go [here](https://docs.flutter.dev/development/platform-integration/platform-channels).

  Because this plugin uses platform channels, no Machine Learning processing is done in Flutter/Dart, all the calls are passed to the native platform using `MethodChannel` in Android and `FlutterMethodChannel` in iOS, and executed using Google's native APIs. Think of this plugin as a bridge between your app and Google's native ML Kit APIs. This plugin only passes the call to the native API and the processing is done by Google's API. It is important that you understand this concept when it comes to debugging errors for your ML model and/or app.

## Requirements

### iOS

- Minimum iOS Deployment Target: 12.0
- Xcode 13.2.1 or newer
- Swift 5
- ML Kit does not support 32-bit architectures (i386 and armv7). ML Kit does support 64-bit architectures (x86_64 and arm64). Check this [list](https://developer.apple.com/support/required-device-capabilities/) to see if your device has the required device capabilities. More info [here](https://developers.google.com/ml-kit/migration/ios).

Since ML Kit does not support 32-bit architectures (i386 and armv7), you need to exclude armv7 architectures in Xcode in order to run `flutter build ios` or `flutter build ipa`. More info [here](https://developers.google.com/ml-kit/migration/ios).

Go to Project > Runner > Building Settings > Excluded Architectures > Any SDK > armv7


Your Podfile should look like this:

```ruby
platform :ios, '12.0'  # or newer version

...

# add this line:
$iOSVersion = '12.0'  # or newer version

post_install do |installer|
  # add these lines:
  installer.pods_project.build_configurations.each do |config|
    config.build_settings["EXCLUDED_ARCHS[sdk=*]"] = "armv7"
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = $iOSVersion
  end
  
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # add these lines:
    target.build_configurations.each do |config|
      if Gem::Version.new($iOSVersion) > Gem::Version.new(config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'])
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = $iOSVersion
      end
    end
    
  end
end
```

Notice that the minimum `IPHONEOS_DEPLOYMENT_TARGET` is 12.0, you can set it to something newer but not older.

### Android

- minSdkVersion: 21
- targetSdkVersion: 33
- compileSdkVersion: 33

## Usage

### Import
```
import 'package:digital_ink_recognition_mlkit/digital_ink_recognition_mlkit.dart';
```

### Digital Ink Recognition

#### Create an instance of `DigitalInkRecognizer`

```dart
String languageCode; // BCP-47 Code from https://developers.google.com/ml-kit/vision/digital-ink-recognition/base-models?hl=en#text
final digitalInkRecognizer = DigitalInkRecognizer(languageCode: languageCode);
```

### Managing remote models

#### Download model

```dart
final bool response = await digitalInkRecognizer.downLoadModel(model);
```
Returns true if model downloads successfully or model is already downloaded.
On failing to download it throws an error.

#### Delete model

```dart
final bool response = await digitalInkRecognizer.deleteModel(model);
```
Returns true if model is deleted successfully or model is not present.

#### Process ink

```dart
final p1 = StrokePoint(x: x1, y: y1, t: DateTime.now().millisecondsSinceEpoch); // make sure that `t` is a long
final p2 = StrokePoint(x: x1, y: y1, t: DateTime.now().millisecondsSinceEpoch); // make sure that `t` is a long

Stroke stroke1 = Stroke(); // it contains all of the StrokePoint
stroke1.points = [p1, p2, ...]

Ink ink = Ink(); // it contains all of the Stroke
ink.strokes = [stroke1, stroke2, ...];

final List<RecognitionCandidate> candidates = await digitalInkRecognizer.recognize(ink);

for (final candidate in candidates) {
  final text = candidate.text;
  final score = candidate.score;
}
```

Make sure you download the language model before processing any `Ink`.

To improve the accuracy of text recognition you can set an writing area and pre-context. More details [here](https://developers.google.cn/ml-kit/vision/digital-ink-recognition/ios#tips-to-improve-text-recognition-accuracy).

```dart
String preContext;
double width;
double height;
final context = DigitalInkRecognitionContext(
  preContext: preContext,
  writingArea: WritingArea(width: width, height: height),
);

final List<RecognitionCandidate> candidates = await digitalInkRecognizer.recognize(ink, context: context);

```

#### Release resources with `close()`

```dart
digitalInkRecognizer.close();
```


