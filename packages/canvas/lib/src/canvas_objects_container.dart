import 'package:canvas/canvas.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:structial/structial.dart';

final class CanvasObjectsContainer extends MultiChildRenderObjectWidget {
  final ValueListenable<double> zoom;
  final ValueListenable<Offset> offset;

  final double cellSize;

  const CanvasObjectsContainer({
    super.key,
    required super.children,
    required this.zoom,
    required this.offset,
    required this.cellSize,
  });

  @override
  RenderCanvasObjectsContainer createRenderObject(BuildContext context) =>
      RenderCanvasObjectsContainer(
        zoom: zoom,
        offset: offset,
        cellSize: cellSize,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderCanvasObjectsContainer renderObject,
  ) {
    renderObject
      ..zoom = zoom
      ..offset = offset
      ..cellSize = cellSize;
  }
}

final class RenderCanvasObjectsContainer extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CanvasObjectParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CanvasObjectParentData> {
  RenderCanvasObjectsContainer({
    required ValueListenable<double> zoom,
    required ValueListenable<Offset> offset,
    required double cellSize,
    List<RenderBox>? children,
  }) : _zoom = zoom,
       _offset = offset,
       _cellSize = cellSize,
       _positionedChildren = SpatialHashGrid(cellSize: cellSize) {
    addAll(children);

    zoom.addListener(_markViewportChanged);
    offset.addListener(_markViewportChanged);
    _markViewportChanged();
  }

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

  SpatialHashGrid<RenderBox> _positionedChildren;

  @override
  bool get isRepaintBoundary => true;

  ValueListenable<double> _zoom;
  ValueListenable<double> get zoom => _zoom;
  set zoom(ValueListenable<double> newZoom) {
    if (identical(_zoom, newZoom)) return;

    _zoom.removeListener(_markViewportChanged);
    _zoom = newZoom;
    _zoom.addListener(_markViewportChanged);

    _markViewportChanged();
  }

  ValueListenable<Offset> _offset;
  ValueListenable<Offset> get offset => _offset;
  set offset(ValueListenable<Offset> newOffset) {
    if (identical(_offset, newOffset)) return;

    _offset.removeListener(_markViewportChanged);
    _offset = newOffset;
    _offset.addListener(_markViewportChanged);

    _markViewportChanged();
  }

  void _markViewportChanged() {
    __worldToView = null;
    __viewToWorld = null;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CanvasObjectParentData) {
      child.parentData = CanvasObjectParentData();
    }
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

  void _visitChildrenAndData(
    void Function(RenderBox child, CanvasObjectParentData childData) visitor,
  ) => visitChildren(
    (childObj) => visitor(
      // it's always a RenderBox thanks to ContainerRenderObjectMixin<RenderBox, ...>
      childObj as RenderBox,
      childObj.parentData as CanvasObjectParentData,
    ),
  );

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

  Matrix4? __worldToView;
  Matrix4 get _worldToView => __worldToView ??= Matrix4.identity()
    ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
    ..scaleByDouble(zoom.value, zoom.value, zoom.value, 1)
    ..translateByDouble(offset.value.dx, offset.value.dy, 0, 1);

  Matrix4? __viewToWorld;
  Matrix4 get _viewToWorld => __viewToWorld ??= Matrix4.inverted(_worldToView);

  void _applyViewportTransform(Matrix4 transform) =>
      transform.multiply(_worldToView);

  @override
  void applyPaintTransform(covariant RenderObject child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    _applyViewportTransform(transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) => context.pushTransform(
    needsCompositing,
    offset,
    _worldToView,
    _paintInWorld,
  );

  void _paintInWorld(PaintingContext context, Offset offset) {
    var viewport = Rect.fromLTRB(0, 0, size.width, size.height);
    var visibleChildren = _positionedChildren.queryArea(viewport);

    for (var child in visibleChildren.sortedByReverseDepth) {
      var childPosition = (child.parentData as CanvasObjectParentData).offset;
      child.paint(context, offset + childPosition);
    }
  }

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

  // todo: implement hitTestSelf and add HitTestBehavior parameter to Canvas

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      // transform the hit position from global/view coords to our world coord
      result.addWithRawTransform(
        transform: _viewToWorld,
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
