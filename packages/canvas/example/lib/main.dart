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
        CanvasObject(
          position: Offset.zero,
          child: Listener(
            onPointerHover: (event) => print("hover pink @ ${event.position}"),
            child: Container(
              width: 200,
              height: 200,
              color: Colors.pink[200],
              child: Center(child: Text("hello")),
            ),
          ),
        ),
        CanvasObject(
          position: Offset(-50, 100),
          child: Listener(
            onPointerHover: (event) => print("hover blue @ ${event.position}"),
            child: Container(
              width: 150,
              height: 150,
              color: Colors.blue[300],
              child: Center(child: Text("world")),
            ),
          ),
        ),
      ],
    );
  }
}
