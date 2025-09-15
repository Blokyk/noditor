import 'package:canvas/canvas.dart';
import 'package:canvas/src/canvas_objects_container.dart';
import 'package:canvas/src/zoom_drag_detector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

final class Canvas extends StatefulWidget {
  final List<Widget> objects;

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

  const Canvas({super.key, required this.objects, this.cellSize = 1024});

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
        cellSize: widget.cellSize,
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

    if (data.depth != depth) {
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
