import 'dart:math';

import 'package:flutter/material.dart' hide Canvas;
import 'package:canvas/canvas.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      home: Material(child: MyHome()),
    );
  }
}

class MyHome extends StatelessWidget {
  static final rnd = Random();

  const MyHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Canvas(
      objects: List.generate(
        1000,
        (idx) => DraggableObject(
          position: ValueNotifier(
            Offset(
              (rnd.nextInt(100) - 50) * 100,
              (rnd.nextInt(100) - 50) * 100,
            ),
          ),
          child: Container(
            width: 200,
            height: 200,
            color: Color(rnd.nextInt(0xFFFFFF)).withAlpha(255),
            child: Text("Object $idx"),
          ),
        ),
        growable: false,
      ),
    );
  }
}
