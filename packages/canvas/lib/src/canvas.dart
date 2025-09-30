import 'package:canvas/canvas.dart';
import 'package:canvas/src/canvas_objects_container.dart';
import 'package:canvas/src/zoom_drag_detector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

final class Canvas extends StatefulWidget {
  final List<Widget> objects;

  final CanvasController? controller;

  /// {@macro canvas.trackpadScrollCausesScale}
  final bool trackpadScrollCausesScale;

  // todo: HitTestBehavior

  /// The size of the cells used for accelerating various operations in the
  /// canvas.
  ///
  /// {@macro structial.spatial_grid.cellSize.perf}
  ///
  /// This value should change as little as possible during the lifetime of
  /// this canvas, as modifying it involves recomputing the position and bounds
  /// of every object in the canvas.
  final double cellSize;

  const Canvas({
    super.key,
    required this.objects,
    this.controller,
    this.cellSize = 1024,
    this.trackpadScrollCausesScale = false,
  });

  @override
  State<Canvas> createState() => _CanvasState();
}

// we need a [StatefulWidget] because we don't want the zoom and offset to
// reset every time the widget is rebuilt
final class _CanvasState extends State<Canvas> {
  late CanvasController _controller;

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? CanvasController();
  }

  @override
  void didUpdateWidget(covariant Canvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    var newController = widget.controller;
    var oldController = _controller;

    if (newController != null && newController != oldController) {
      _controller = newController;
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    // clip background + object container
    clipBehavior: Clip.hardEdge,
    children: [
      Positioned.fill(
        child: ZoomDragDetector(
          controller: _controller,
          trackpadScrollCausesScale: widget.trackpadScrollCausesScale,
        ),
      ),
      Positioned.fill(
        child: GridBackground.empty(
          hitTestBehavior: HitTestBehavior.translucent,
          size: Size.zero,
          zoom: _controller.zoom,
          offset: _controller.position,
        ),
      ),
      CanvasObjectsContainer(
        controller: _controller,
        cellSize: widget.cellSize,
        children: widget.objects,
      ),
    ],
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);

    // add props directly from controller
    _controller.debugFillProperties(properties);
    properties.add(IntProperty("objects", widget.objects.length));
  }
}

@immutable
final class CanvasObject extends ParentDataWidget<CanvasObjectParentData> {
  CanvasObject.atCoords({
    super.key,
    required double x,
    required double y,
    this.depth,
    this.size,
    required super.child,
  }) : position = Offset(x, y);

  const CanvasObject({
    super.key,
    required this.position,
    this.depth,
    this.size,
    required super.child,
  });

  /// The xy coordinates of the object in the canvas.
  ///
  /// A canvas object exists inside the "world" of the canvas, which has its
  /// own coordinate system, separate from the coordinates of other elements
  /// on the screen. This world is navigated through changing [Canvas.offset]
  /// and [Canvas.zoom]. The [Canvas] widget takes care of translating these
  /// world coordinates into the viewport of the canvas, which is the fraction
  /// of the world displayed in the widget.
  final Offset position;

  /// The exact size this object takes up in the canvas.
  ///
  /// By default, canvas objects are given infinite constraints and choose
  /// their own size. This property can be used to give an object a specific,
  /// pre-determined size to avoid having to it in a [SizedBox].
  final Size? size;

  /// The z-axis depth of this object.
  ///
  /// This determines the order in which
  /// objects are not only painted but also hit-tested. Objects with a
  /// shallower depth will be visually in front of others with a greater
  /// depth, and will be hit-tested first.
  ///
  /// If this is unset, the reverse order of the child in the canvas object
  /// list (i.e. [Canvas.objects]) will be used instead: children defined
  /// earlier in the list will be "deeper" than (or "behind") their later
  /// depth-less siblings. This calculation is unaffected by any sibling with
  /// a defined depth.
  final double? depth;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is CanvasObjectParentData);
    var data = renderObject.parentData! as CanvasObjectParentData;
    var parentNeedsLayout = false;

    if (data.position != position) {
      data.position = position;
      parentNeedsLayout = true;
    }

    if (data.size != size) {
      data.size = size;
      parentNeedsLayout = true;
    }

    if (depth != null && data.depth != depth) {
      data.depth = depth;
      parentNeedsLayout = true;
    }

    if (parentNeedsLayout) renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass =>
      // technically it's CanvasObjectsContainer, but Canvas is the user-visible wrapper widget
      Canvas;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty("position", position))
      ..add(DiagnosticsProperty("size", size, defaultValue: null))
      ..add(DoubleProperty("depth", depth, defaultValue: null));
  }
}

final class CanvasController with Diagnosticable {
  CanvasController({
    double initialZoom = 1.0,
    Offset initialOffset = Offset.zero,
  }) : zoom = ValueNotifier(initialZoom),
       position = ValueNotifier(initialOffset),
       _viewportSize = ValueNotifier(Size.zero) {
    zoom.addListener(_updateTransform);
    position.addListener(_updateTransform);
    viewportSize.addListener(_updateTransform);
  }

  final ValueNotifier<double> zoom;

  final ValueNotifier<Offset> position;

  void setZoomAt(double newZoom, Offset canvasFocalPoint) {
    var zoomDelta = zoom.value / newZoom;

    print('zoom delta: $zoomDelta');

    // to figure out the new center position, we interpolate between the old
    // center and the point we're trying to zoom into. that way, the viewport's
    // center slowly moves towards the focal point. we also get two nice
    // side-effects:
    //    - the focal point will stay at the same visual position no matter how
    //      much we zoom in
    //    - zooming-out is effortlessly supported, because in that case, we get
    //      `zoom / newZoom` > 1, which means `1 - delta` will be negative,
    //      and thus the lerp will start moving the center in the direction
    //      opposite of the focal point (which also maintains the earlier
    //      side-effect)
    var newCenter = Offset.lerp(
      position.value,
      canvasFocalPoint,
      1 - zoomDelta,
    )!;

    print(
      'center: $newCenter (${(position.value - newCenter).distance} units away)',
    );

    zoom.value = newZoom;
    position.value = newCenter;
  }

  final ValueNotifier<Size> _viewportSize;
  ValueListenable<Size> get viewportSize => _viewportSize;
  @visibleForTesting // should not be used by public consumers, only by CanvasObjectsContainer
  set viewportSize(Size newSize) {
    assert(newSize.isFinite);
    if (newSize == _viewportSize.value) return;

    _viewportSize.value = newSize;
  }

  Matrix4? _canvasToView;
  Matrix4 get canvasToView => _canvasToView ??= _computeWorldViewTransform();
  Matrix4? _viewToCanvas;
  Matrix4 get viewToCanvas => _viewToCanvas ??= Matrix4.inverted(canvasToView);

  Matrix4 _computeWorldViewTransform() {
    var zoom = this.zoom.value;
    var offset = position.value;
    var viewport = viewportSize.value;

    return Matrix4.identity()
      ..translateByDouble(viewport.width / 2, viewport.height / 2, 0, 1)
      ..scaleByDouble(zoom, zoom, 1, 1)
      ..translateByDouble(-offset.dx, -offset.dy, 0, 1);
  }

  void _updateTransform() {
    _viewToCanvas = null;
    _canvasToView = null;
  }

  Offset toCanvas(Offset viewPoint) =>
      MatrixUtils.transformPoint(viewToCanvas, viewPoint);
  Offset toView(Offset canvasPoint) =>
      MatrixUtils.transformPoint(canvasToView, canvasPoint);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);

    properties
      ..add(DoubleProperty('zoom', zoom.value))
      ..add(DiagnosticsProperty('position', position.value))
      ..add(DiagnosticsProperty('viewport size', viewportSize.value));
  }
}
