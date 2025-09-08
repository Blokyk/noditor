import 'package:flutter/material.dart';
import 'package:canvas/canvas.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _zoom = ValueNotifier(1.0);
  final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);

  @override
  void initState() {}

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
      home: Material(
        child: Column(
          children: [
            Slider(
              label: "Zoom",
              value: _zoom.value,
              onChanged: (value) => setState(() => _zoom.value = value),
              min: 1.0 / 10,
              max: 5,
            ),
            Slider(
              label: "X offset",
              value: _offset.value.dx,
              onChanged: (value) => setState(
                () => _offset.value = Offset(value, _offset.value.dy),
              ),
              min: -100,
              max: 100,
            ),
            Slider(
              label: "Y offset",
              value: _offset.value.dy,
              onChanged: (value) => setState(
                () => _offset.value = Offset(_offset.value.dx, value),
              ),
              min: -100,
              max: 100,
            ),
            GridBackground(
              zoom: _zoom,
              offset: _offset,
              child: SizedBox(
                width: 500,
                height: 500,
                child: Center(child: Text("Hello, world!")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
