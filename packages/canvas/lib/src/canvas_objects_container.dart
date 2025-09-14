import 'package:canvas/src/canvas_objects_parent_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:structial/structial.dart';

final class CanvasObjectsContainer extends MultiChildRenderObjectWidget {
  final ValueListenable<double> zoom;
  final ValueListenable<Offset> offset;

  const CanvasObjectsContainer({
    super.key,
    required super.children,
    required this.zoom,
    required this.offset,
  });

  @override
  RenderCanvasObjectsContainer createRenderObject(BuildContext context) =>
      RenderCanvasObjectsContainer(zoom: zoom, offset: offset);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderCanvasObjectsContainer renderObject,
  ) {
    renderObject
      ..zoom = zoom
      ..offset = offset;
  }
}

final class RenderCanvasObjectsContainer extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CanvasObjectParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CanvasObjectParentData> {
  RenderCanvasObjectsContainer({
    required ValueListenable<double> zoom,
    required ValueListenable<Offset> offset,
    List<RenderBox>? children,
  }) : _zoom = zoom,
       _offset = offset {
    addAll(children);

    zoom.addListener(_markViewportChanged);
    offset.addListener(_markViewportChanged);
    _markViewportChanged();
  }

  final SpatialHashGrid<RenderBox> _positionedChildren = SpatialHashGrid(
    // todo: wtf do we do for the cell size???
    cellSize: 1024.0,
  );

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

  bool _offsetsDirty = true;
  void _markViewportChanged() {
    __worldToView = null;
    _offsetsDirty = true;
    markNeedsPaint();
  }

  void _updateChildOffsets() {
    assert(
      _offsetsDirty,
      "[updateChildOffsets] was called but offsets weren't marked dirty",
    );

    _visitChildrenAndData((child, childData) {
      var bounds = _positionedChildren.boundsOf(child);

      // this child hasn't been sized/bounded yet
      if (bounds == null) return;

      // todo: maybe this transform should be done in applyPaintTransform? not sure
      childData.offset = worldToBoxCoord(bounds.topLeft);
    });

    _offsetsDirty = false;
  }

  Offset worldToBoxCoord(Offset worldOffset) => worldOffset;

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

    _visitChildrenAndData((child, childData) {
      _debugAssertIsPositioned(child, childData);

      // todo: avoid laying out child if it is outside viewport/constraints

      var constraints = childData.computeConstraints();

      child.layout(constraints, parentUsesSize: true);

      assert(child.size.isFinite);

      var bounds = childData.computeBounds(child.size);

      _positionedChildren.update(child, bounds);
    });

    // we updated our size and the position of every child, so we also need to
    // recompute the offsets now
    _markViewportChanged();
  }

  Matrix4? __worldToView;
  Matrix4 get _worldToView => __worldToView ??= Matrix4.identity()
    ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
    ..scaleByDouble(zoom.value, zoom.value, zoom.value, 1)
    ..translateByDouble(offset.value.dx, offset.value.dy, 0, 1);

  Matrix4 get _viewToWorld => Matrix4.inverted(_worldToView);

  void _applyViewportTransform(Matrix4 transform) =>
      transform.multiply(_worldToView);

  @override
  void applyPaintTransform(covariant RenderObject child, Matrix4 transform) {
    assert(
      !_offsetsDirty,
      "applyPaintTransform called before updating child offsets",
    );

    super.applyPaintTransform(child, transform);
    _applyViewportTransform(transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_offsetsDirty) _updateChildOffsets();

    Matrix4 transform = _worldToView;

    context.pushTransform(needsCompositing, offset, transform, _paintCore);
  }

  void _paintCore(PaintingContext context, Offset offset) =>
      _visitChildrenAndData((child, childData) {
        if (paintsChild(child)) child.paint(context, offset + childData.offset);
      });

  static void _debugAssertIsPositioned(
    RenderBox child,
    CanvasObjectParentData childData,
  ) {
    assert(() {
      if (childData.isPositioned) return true;

      throw FlutterError.fromParts([
        ErrorSummary(
          "Every canvas object has to be wrapped in a Positioned widget with an xy position",
        ),
        ErrorDescription(
          "Canvas objects need to wrapped in a Positioned widget with both "
          "a vertical (top/bottom) and horizontal (left/right) position.",
        ),
        DiagnosticsProperty("Position data", childData, expandableValue: true),
        ErrorHint(
          "Wrap the canvas object in a Positioned widget with its top and "
          "left properties set to the object's xy coordinates. If you did, "
          "make sure the path from the Positioned widget to its enclosing "
          "Canvas only contains StatelessWidgets or StatefulWidgets (not other "
          "kinds of widgets, like RenderObjectWidgets)",
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

          // then hit test each child
          for (var child in childrenAtPosition) {
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
