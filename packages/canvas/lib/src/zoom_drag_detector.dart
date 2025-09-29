import 'package:canvas/src/canvas.dart';
import 'package:flutter/widgets.dart';

final class ZoomDragDetector extends StatefulWidget {
  final CanvasController controller;

  const ZoomDragDetector({super.key, required this.controller});

  @override
  State<ZoomDragDetector> createState() => _ZoomDragDetectorState();
}

class _ZoomDragDetectorState extends State<ZoomDragDetector> {
  double _originalZoom = 1.0;

  void _handleScaleStart(ScaleStartDetails details) {
    _originalZoom = widget.controller.zoom.value;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.focalPointDelta.distanceSquared != 0) {
      // we have to scale the movement delta because [controller.position] is in world space:
      //    - if we're zoomed-in, the offset needs to be scaled-down to avoid moving
      //      tens of units when the viewport barely shows one unit
      //    - if we're zoomed-out, the offset needs to be blown-up, since we now have
      //      the opposite issue of showing thousands of units and only have a delta
      //      of a few units, which is too small to really notice
      var viewDelta = details.focalPointDelta / widget.controller.zoom.value;
      widget.controller.position.value -= viewDelta;
    } else {
      widget.controller.zoom.value = _originalZoom * details.scale;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onScaleStart: _handleScaleStart,
    onScaleUpdate: _handleScaleUpdate,
    trackpadScrollCausesScale: true,
  );
}
