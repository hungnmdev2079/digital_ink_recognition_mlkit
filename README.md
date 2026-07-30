# Digital Ink Recognition ML Kit for Flutter

A lightweight, standalone Flutter plugin for
[Google ML Kit Digital Ink Recognition](https://developers.google.com/ml-kit/vision/digital-ink-recognition).
It recognizes handwriting, symbols, and sketches directly on Android and iOS
devices.

This package separates Digital Ink Recognition from the
[`google_ml_kit`](https://pub.dev/packages/google_ml_kit) umbrella package. It
keeps only the code and native SDKs required for digital ink recognition, so
your app does not need unrelated Flutter ML Kit plugins or dependencies.

> **Important:** Android and iOS are supported. Web is not supported. This
> plugin is not sponsored or maintained by Google.

## Installation

```bash
flutter pub add digital_ink_recognition_mlkit
```

### Android

Configure your app with:

```gradle
android {
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }
}
```

### iOS

Requirements:

- iOS 15.5 or later
- Xcode 13.2.1 or later
- Swift 5

Set the deployment target in `ios/Podfile`:

```ruby
platform :ios, '15.5'
```

Then install the Pods:

```bash
cd ios
pod install
cd ..
```

If the build reports a 32-bit architecture error, exclude `armv7` in:
`Runner > Build Settings > Excluded Architectures`.

### Apple Silicon + iOS Simulator 26 or later

> **Required for this setup:** Google ML Kit pods do not currently provide a
> native `arm64-iphonesimulator` slice. Add the compatibility helper below when
> running an iOS 26+ simulator on an Apple Silicon Mac.

1. In `ios/Podfile`, add this immediately after Flutter's `podhelper` is loaded:

```ruby
require File.expand_path(
  '.symlinks/plugins/digital_ink_recognition_mlkit/ios/scripts/apple_silicon_simulator',
  __dir__,
)
```

2. Add this call at the end of the existing `post_install` block:

```ruby
post_install do |installer|
  # Keep your existing post_install configuration here.

  digital_ink_mlkit_apple_silicon_simulator_patch(installer)
end
```

3. Reinstall the Pods:

```bash
cd ios
pod install
cd ..
```

The helper patches the ML Kit binary for the active build target. The same Pods
installation can still be used for both Apple Silicon simulators and physical
devices. It does not add another Flutter or ML Kit plugin dependency.

## Quick start

```dart
import 'package:digital_ink_recognition_mlkit/digital_ink_recognition_mlkit.dart';

final recognizer = DigitalInkRecognizer(languageCode: 'en');

// The language model must be available before recognition.
final ready = await recognizer.ensureModel();
if (!ready) {
  throw Exception('Could not download the English model');
}

final ink = Ink()
  ..strokes = [
    Stroke()
      ..points = [
        StrokePoint(
          x: 20,
          y: 30,
          t: DateTime.now().millisecondsSinceEpoch,
        ),
        StrokePoint(
          x: 35,
          y: 45,
          t: DateTime.now().millisecondsSinceEpoch,
        ),
      ],
  ];

final candidates = await recognizer.recognize(ink);
if (candidates.isNotEmpty) {
  print(candidates.first.text);
}

await recognizer.close();
```

Each `Stroke` represents one continuous pen or finger movement. Each
`StrokePoint` contains its `x` and `y` coordinates and timestamp `t` in
milliseconds.

Language models use BCP-47 tags such as `en`, `vi`, `ja`, and `zh-Hani`. See
the [supported model list](https://developers.google.com/ml-kit/vision/digital-ink-recognition/base-models).

Model management:

```dart
await recognizer.isModelDownloaded();
await recognizer.downLoadModel();
await recognizer.deleteModel();
```

Provide the writing area and preceding text to improve recognition accuracy:

```dart
final context = DigitalInkRecognitionContext(
  preContext: 'Hello',
  writingArea: WritingArea(width: 320, height: 240),
);

final candidates = await recognizer.recognize(ink, context: context);
```

See the complete app in [`example`](example).

## How it works and upstream sources

The plugin uses Flutter Platform Channels to call the native ML Kit SDKs:

- Android: `com.google.mlkit:digital-ink-recognition:19.0.0`
- iOS: `GoogleMLKit/DigitalInkRecognition ~> 9.0.0`

The API and plugin structure are based on Google's
[Digital Ink Recognition documentation](https://developers.google.com/ml-kit/vision/digital-ink-recognition)
and the open-source
[`google_mlkit_digital_ink_recognition`](https://github.com/flutter-ml/google_ml_kit_flutter/tree/master/packages/google_mlkit_digital_ink_recognition)
implementation.

Dart sends stroke data through a platform channel and receives recognition
candidates. Recognition itself runs in Google's native SDK on the device.
Internet access is only required when downloading a language model for the
first time.

## License

This project is available under the [MIT License](LICENSE). Anyone may use,
copy, modify, distribute, or use the source commercially. No author credit or
copyright notice is required in the application's user interface. Keep the
`LICENSE` file when redistributing the software or a substantial portion of
its source code.

Google ML Kit and other third-party libraries remain subject to their own
licenses and terms.
