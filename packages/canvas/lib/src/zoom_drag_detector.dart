import 'package:canvas/src/canvas.dart';
import 'package:flutter/widgets.dart';

final class ZoomDragDetector extends StatefulWidget {
  final CanvasController controller;

  /// {@template canvas.trackpadScrollCausesScale}
  /// Whether trackpad scrolling (on any axis) should be interpreted
  /// as a zoom or not. If enabled, users cannot pan around using
  /// two-finger gestures (which are interpreted as multi-axis scroll).
  /// {@endtemplate}
  final bool trackpadScrollCausesScale;

  const ZoomDragDetector({
    super.key,
    required this.controller,
    this.trackpadScrollCausesScale = false,
  });

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
      // sometimes, for some reason, the scale recognizer doesn't establish a good focal
      // point, and instead just sets the focal point to the position where the pointer
      // was last lifted.
      var focalPoint = details.focalPoint != _maybeFakeFocalPoint
          ? details.localFocalPoint
          // when that happens, zoom into the center of the viewport instead
          : widget.controller.viewportSize.value.center(Offset.zero);

      widget.controller.setZoomAt(
        _originalZoom * details.scale,
        widget.controller.toCanvas(focalPoint),
      );
    }
  }

  // note: the (0, 0) value here *is* useful: if we never click
  // anywhere, then flutter will use (0, 0) as the fake focal point
  Offset _maybeFakeFocalPoint = Offset.zero;

  void _onPointerDown(PointerDownEvent event) =>
      _maybeFakeFocalPoint = event.position;
  void _onPointerMove(PointerMoveEvent event) =>
      _maybeFakeFocalPoint = event.position;
  void _onPointerUp(PointerUpEvent event) =>
      _maybeFakeFocalPoint = event.position;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _onPointerDown,
    onPointerMove: _onPointerMove,
    onPointerUp: _onPointerUp,
    child: GestureDetector(
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      trackpadScrollCausesScale: widget.trackpadScrollCausesScale,
    ),
  );
}
