// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter/material.dart';
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
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                  animation: animationController,
                  builder: (context, child) => Transform.rotate(
                      angle: animation.value * pi, child: child),
                  child: const Text('Running')),
              const SizedBox(height: 50),
              FilledButton(
                  onPressed: () async {
                    await download();
                  },
                  child: const Text('download')),
              FilledButton(
                  onPressed: () async {
                    await deleteModel();
                  },
                  child: const Text('delete'))
            ],
          ),
        ),
      ),
    );
  }
}
