// ignore_for_file: avoid_print

import 'package:flutter/material.dart' hide Ink;
import 'dart:async';

import 'package:digital_ink_recognition_mlkit/digital_ink_recognition_mlkit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  final _digitalInkRecognitionMlkitPlugin =
      DigitalInkRecognizer(languageCode: 'ja');

  late AnimationController animationController;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();
    animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    animation = Tween<double>(begin: 0, end: 1).animate(animationController);
    animationController.repeat();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> download() async {
    final result = await _digitalInkRecognitionMlkitPlugin.downLoadModel();
    print(result.toString());
  }

  Future<void> deleteModel() async {
    final result = await _digitalInkRecognitionMlkitPlugin.deleteModel();
    print(result);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DigitalInkView(),
    );
  }
}

class DigitalInkView extends StatefulWidget {
  @override
  State<DigitalInkView> createState() => _DigitalInkViewState();
}

class _DigitalInkViewState extends State<DigitalInkView> {
  var _language = 'en';
  // Codes from https://developers.google.com/ml-kit/vision/digital-ink-recognition/base-models?hl=en#text
  final _languages = [
    'en',
    'es',
    'fr',
    'hi',
    'it',
    'ja',
    'pt',
    'ru',
    'zh-Hani',
  ];
  late DigitalInkRecognizer _digitalInkRecognizer =
      DigitalInkRecognizer(languageCode: _language);
  final Ink _ink = Ink();
  List<StrokePoint> _points = [];
  String _recognizedText = '';

  @override
  void dispose() {
    _digitalInkRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Digital Ink Recognition')),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDropdown(),
                  ElevatedButton(
                    onPressed: _downloadModel,
                    child: Icon(Icons.download),
                  ),
                  ElevatedButton(
                    onPressed: _deleteModel,
                    child: Icon(Icons.delete),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _recogniseText,
                    child: Text('Read Text'),
                  ),
                  ElevatedButton(
                    onPressed: _clearPad,
                    child: Text('Clear Pad'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onPanStart: (DragStartDetails details) {
                  _ink.strokes.add(Stroke());
                },
                onPanUpdate: (DragUpdateDetails details) {
                  setState(() {
                    final RenderObject? object = context.findRenderObject();
                    final localPosition = (object as RenderBox?)
                        ?.globalToLocal(details.localPosition);
                    if (localPosition != null) {
                      _points = List.from(_points)
                        ..add(StrokePoint(
                          x: localPosition.dx,
                          y: localPosition.dy,
                          t: DateTime.now().millisecondsSinceEpoch,
                        ));
                    }
                    if (_ink.strokes.isNotEmpty) {
                      _ink.strokes.last.points = _points.toList();
                    }
                  });
                },
                onPanEnd: (DragEndDetails details) {
                  _points.clear();
                  setState(() {});
                },
                child: CustomPaint(
                  painter: Signature(ink: _ink),
                  size: Size.infinite,
                ),
              ),
            ),
            if (_recognizedText.isNotEmpty)
              Text(
                'Candidates: $_recognizedText',
                style: TextStyle(fontSize: 23),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown() => DropdownButton<String>(
        value: _language,
        icon: const Icon(Icons.arrow_downward),
        elevation: 16,
        style: const TextStyle(color: Colors.blue),
        underline: Container(
          height: 2,
          color: Colors.blue,
        ),
        onChanged: (String? lang) {
          if (lang != null) {
            setState(() {
              _language = lang;
              _digitalInkRecognizer.close();
              _digitalInkRecognizer =
                  DigitalInkRecognizer(languageCode: _language);
            });
          }
        },
        items: _languages.map<DropdownMenuItem<String>>((lang) {
          return DropdownMenuItem<String>(
            value: lang,
            child: Text(lang),
          );
        }).toList(),
      );

  void _clearPad() {
    setState(() {
      _ink.strokes.clear();
      _points.clear();
      _recognizedText = '';
    });
  }

  Future<void> _deleteModel() async {
    _digitalInkRecognizer
        .deleteModel()
        .then((value) => value ? 'success' : 'failed');
  }

  Future<void> _downloadModel() async {
    _digitalInkRecognizer
        .downLoadModel()
        .then((value) => value ? 'success' : 'failed');
  }

  Future<void> _recogniseText() async {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Recognizing'),
            ),
        barrierDismissible: true);
    try {
      final candidates = await _digitalInkRecognizer.recognize(_ink);
      _recognizedText = '';
      for (final candidate in candidates) {
        _recognizedText += '\n${candidate.text}';
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
      ));
    }
    Navigator.pop(context);
  }
}

class Signature extends CustomPainter {
  Ink ink;

  Signature({required this.ink});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.blue
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    for (final stroke in ink.strokes) {
      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        canvas.drawLine(Offset(p1.x.toDouble(), p1.y.toDouble()),
            Offset(p2.x.toDouble(), p2.y.toDouble()), paint);
      }
    }
  }

  @override
  bool shouldRepaint(Signature oldDelegate) => true;
}
