import 'package:flutter/material.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: SizedBox(
        width: 300,
        height: 300,
        child: GridBackground(
          child: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Text("Hello, world!"),
            ),
          ),
        ),
      ),
    );
  }
}
