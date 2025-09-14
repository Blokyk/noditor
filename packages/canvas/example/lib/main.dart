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
          brightness: Brightness.dark,
        ),
      ),
      home: Material(child: MyHome()),
    );
  }
}

class MyHome extends StatefulWidget {
  const MyHome({super.key});

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  @override
  Widget build(BuildContext context) {
    return Canvas(
      objects: [
        Positioned(
          top: 0,
          left: 0,
          child: Listener(
            onPointerMove: (event) => print("move @ $event"),
            child: Container(
              width: 1280,
              height: 720,
              color: Colors.pink[200],
              child: Text("hello"),
            ),
          ),
        ),
      ],
    );
  }
}
