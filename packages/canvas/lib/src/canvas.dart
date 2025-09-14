import 'package:canvas/canvas.dart';
import 'package:canvas/src/canvas_objects_container.dart';
import 'package:canvas/src/zoom_drag_detector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

final class Canvas extends StatefulWidget {
  final List<Widget> objects;

  // todo: HitTestBehavior
  // todo: cellSize

  const Canvas({super.key, required this.objects});

  @override
  State<Canvas> createState() => _CanvasState();
}

// we need a [StatefulWidget] because we don't want the zoom and offset to
// reset every time the widget is rebuilt
final class _CanvasState extends State<Canvas> {
  final ValueNotifier<double> _zoom = ValueNotifier(1.0);
  final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);

  @override
  Widget build(BuildContext context) => Stack(
    // clip background + object container
    clipBehavior: Clip.hardEdge,
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
      CanvasObjectsContainer(
        offset: _offset,
        zoom: _zoom,
        children: widget.objects,
      ),
    ],
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty("zoom", _zoom.value))
      ..add(DiagnosticsProperty("offset", _offset.value))
      ..add(IntProperty("objects", widget.objects.length));
  }
}
