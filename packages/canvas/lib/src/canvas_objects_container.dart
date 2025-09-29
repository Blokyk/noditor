import 'package:canvas/canvas.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:structial/structial.dart';

final class CanvasObjectsContainer extends MultiChildRenderObjectWidget {
  final CanvasController controller;

  final double cellSize;

  const CanvasObjectsContainer({
    super.key,
    required super.children,
    required this.controller,
    required this.cellSize,
  });

  @override
  RenderCanvasObjectsContainer createRenderObject(BuildContext context) =>
      RenderCanvasObjectsContainer(controller: controller, cellSize: cellSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderCanvasObjectsContainer renderObject,
  ) {
    renderObject
      ..controller = controller
      ..cellSize = cellSize;
  }
}

final class RenderCanvasObjectsContainer extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CanvasObjectParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CanvasObjectParentData> {
  RenderCanvasObjectsContainer({
    required CanvasController controller,
    required double cellSize,
    List<RenderBox>? children,
  }) : _controller = controller,
       _cellSize = cellSize,
       _positionedChildren = SpatialHashGrid(cellSize: cellSize) {
    addAll(children);

    _controller.zoom.addListener(_markViewportChanged);
    _controller.position.addListener(_markViewportChanged);
    _markViewportChanged();
  }

  // |------------|
  // | PROPERTIES |
  // |------------|

  SpatialHashGrid<RenderBox> _positionedChildren;

  @override
  bool get isRepaintBoundary => true;

  double _cellSize;
  double get cellSize => _cellSize;
  set cellSize(double newSize) {
    if (_cellSize == newSize) return;

    _cellSize = newSize;

    // rebuild the grid with the new size
    _positionedChildren = SpatialHashGrid.from(
      _positionedChildren,
      cellSize: newSize,
    );
  }

  CanvasController _controller;
  CanvasController get controller => _controller;
  set controller(CanvasController newController) {
    if (newController == _controller) return;

    _controller.zoom.removeListener(_markViewportChanged);
    _controller.position.removeListener(_markViewportChanged);

    newController.zoom.addListener(_markViewportChanged);
    newController.position.addListener(_markViewportChanged);

    _controller = newController;

    _markViewportChanged();
  }

  @override
  void dropChild(RenderObject child) {
    assert(child is RenderBox);
    _positionedChildren.remove(child as RenderBox);
    super.dropChild(child);
  }

  @override
  void removeAll() {
    // clear entirely so removes will be dirt-cheap
    _positionedChildren.clear();
    super.removeAll();
  }

  void _markViewportChanged() {
    // this setter was made exclusively for our use
    // ignore: invalid_use_of_visible_for_testing_member
    if (hasSize) _controller.viewportSize = size;

    markNeedsPaint();
  }

  // |-----------------|
  // | LAYOUT & BOUNDS |
  // |-----------------|

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    assert(() {
      // if none of the constraints are infinite, then we're fine :)
      if (constraints.hasBoundedWidth || constraints.hasBoundedHeight) {
        return true;
      }

      throw FlutterError.fromParts([
        ErrorSummary("Canvas was given unbounded width or height."),
        ErrorDescription(
          "A canvas does not have an intrinsic width or height "
          "and thus cannot know how to size itself when given unbounded space.",
        ),
        ErrorHint(
          "Consider wrapping this Canvas in a bounded container, such as a "
          "SizedBox (for a fixed size) or an Expanded/Flexible (when used in "
          "a column or row).",
        ),
      ]);
    }());

    return constraints.biggest;
  }

  // todo: move this to a method called during painting (though we don't want to recompute it on every paint)
  // !! we still have to compute/pass down the constraints from CanvasObjectParentData if any !!
  //
  // even though this is the place where it's expected that these kind of
  // computations will be done, it's generally because the parent lays out its
  // children in some intricate way based on their size, and that influences
  // the object's final size/layout. but here, we always take up as much space
  // as we can, we don't depend on the children at all. (the only "work" we
  // have to do is computing the constraints of the CanvasObjectParentData and
  // passing them to the child.)
  //
  // in reality, we only care about the child's size when it comes to painting
  // it and setting its offset. apparently, a few existing widgets ([Flow], i
  // think?) do this kind of stuff already, so we should check how they work.
  //
  // From the docs for [performLayout]:
  //  > Some special [RenderObject] subclasses (such as the one used by
  //  > [OverlayPortal.overlayChildLayoutBuilder]) call [applyPaintTransform] in
  //  > their [performLayout] implementation. To ensure such [RenderObject]s get
  //  > the up-to-date paint transform, [RenderObject] subclasses should typically
  //  > update the paint transform (as reported by [applyPaintTransform]) in this
  //  > method instead of [paint].
  //
  // !! this is especially bad because we have to relayout every time one of the children needs to relayout !!
  // (because of [parentUsesSize], cause we, y'know, use the size)
  @override
  void performLayout() {
    size = getDryLayout(super.constraints);
    _markViewportChanged();

    var currDepth = 0.0;

    _visitChildrenAndData((child, childData) {
      _debugAssertIsPositioned(child, childData);

      // if the child doesn't have a defined depth, just
      // set it to one minus the depth of the last object
      // without a depth
      childData.depth ??= currDepth--;

      // todo: avoid laying out child if it is outside viewport

      var childConstraints = childData.computeConstraints();

      child.layout(
        childConstraints,
        // we only care about the child's size if the child data doesn't
        // already define a size; otherwise, we just lay it out because
        // of protocol
        parentUsesSize: childData.size == null,
      );

      assert(child.size.isFinite);

      var bounds = childData.computeBounds(laidOutSize: child.size);

      _positionedChildren.update(child, bounds);
      childData.offset = bounds.topLeft;
    });
  }

  // |----------|
  // | PAINTING |
  // |----------|

  void _applyViewportTransform(Matrix4 transform) =>
      transform.multiply(_controller.canvasToView);

  @override
  void applyPaintTransform(covariant RenderObject child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    _applyViewportTransform(transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushTransform(
      needsCompositing,
      offset,
      _controller.canvasToView,
      _paintInWorld,
    );
  }

  void _paintInWorld(PaintingContext context, Offset offset) {
    var viewport = Rect.fromLTRB(0, 0, size.width, size.height);

    // the viewport when translated into the world coordinates used by canvas
    // objects (and thus the spatial hash map)
    var worldViewport = MatrixUtils.transformRect(
      _controller.viewToCanvas,
      viewport,
    );

    // print_mat4(_controller.viewToCanvas);

    var visibleChildren = _positionedChildren.queryArea(worldViewport);

    for (var child in visibleChildren.sortedByReverseDepth) {
      var childPosition = (child.parentData as CanvasObjectParentData).offset;
      child.paint(context, offset + childPosition);
    }
  }

  // |----------|
  // | HIT-TEST |
  // |----------|

  // todo: implement hitTestSelf and add HitTestBehavior parameter to Canvas

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      // transform the hit position from global/view coords to our world coord
      result.addWithRawTransform(
        transform: _controller.viewToCanvas,
        position: position,

        // hitTest with the transformed position
        hitTest: (result, position) {
          // get all objects that overlap with the hit position
          var childrenAtPosition = _positionedChildren.queryPoint(position);

          // then hit test each child, from closest (smallest depth) to furthest (biggest depth)
          for (var child in childrenAtPosition.sortedByDepth) {
            var childPosition = (child.parentData as BoxParentData).offset;

            // offset the position to the child's position and hit test it
            var childIsHit = result.addWithPaintOffset(
              offset: childPosition,
              position: position,
              hitTest: (result, childPosition) =>
                  child.hitTest(result, position: childPosition),
            );

            if (childIsHit) return true;
          }

          // we didn't hit any child
          return false;
        },
      );

  // |------|
  // | MISC |
  // |------|

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CanvasObjectParentData) {
      child.parentData = CanvasObjectParentData();
    }
  }

  void _visitChildrenAndData(
    void Function(RenderBox child, CanvasObjectParentData childData) visitor,
  ) => visitChildren(
    (childObj) => visitor(
      // it's always a RenderBox thanks to ContainerRenderObjectMixin<RenderBox, ...>
      childObj as RenderBox,
      childObj.parentData as CanvasObjectParentData,
    ),
  );

  static void _debugAssertIsPositioned(
    RenderBox child,
    CanvasObjectParentData childData,
  ) {
    assert(() {
      if (childData.position != null) return true;

      throw FlutterError.fromParts([
        ErrorSummary(
          "Every canvas object has to be wrapped in a CanvasObject widget",
        ),
        DiagnosticsProperty("Position data", childData, expandableValue: true),
        ErrorHint(
          "Wrap the canvas object in a CanvasObject widget with its x and y "
          "properties set to the object's coordinates. If you did, make sure "
          "the path from the CanvasObject widget to its enclosing Canvas only "
          "contains StatelessWidgets or StatefulWidgets (not other kinds of "
          "widgets, like RenderObjectWidgets)",
        ),
      ]);
    }());
  }

  @override
  void dispose() {
    super.dispose();
    _positionedChildren.clear();
  }
}

extension _SortByDepth on Iterable<RenderBox> {
  Iterable<RenderBox> get sortedByDepth =>
      sortedBy((child) => (child.parentData as CanvasObjectParentData).depth!);
  Iterable<RenderBox> get sortedByReverseDepth => sortedBy(
    (child) => (child.parentData as CanvasObjectParentData).depth!,
  ).reversed;
}
