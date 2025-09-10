import 'package:canvas/canvas.dart';
import 'package:canvas/src/zoom_drag_detector.dart';
import 'package:flutter/widgets.dart';

final class Canvas extends StatefulWidget {
  final List<Widget> objects;

  const Canvas({super.key, required this.objects});

  @override
  State<Canvas> createState() => _CanvasState();
}

class _CanvasState extends State<Canvas> {
  late final ValueNotifier<double> _zoom = ValueNotifier(1.0);
  late final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: ZoomDragDetector(
          onZoomUpdate: (zoom) => _zoom.value = zoom,
          onOffsetUpdate: (offset) => _offset.value = offset,
        ),
      ),
      Positioned.fill(
        child: GridBackground.empty(
          zoom: _zoom,
          offset: _offset,
          hitTestBehavior: HitTestBehavior.translucent,
          size: Size.zero,
        ),
      ),
    ],
  );
}
