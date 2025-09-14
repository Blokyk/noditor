import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';

final class CanvasObjectParentData extends StackParentData with Diagnosticable {
  /// Whether this child is considered positioned.
  ///
  /// A child is positioned if it has a horizontal (left/right) and
  /// vertical (top/bottom) position.
  @override
  bool get isPositioned => isHorizontallyPositioned && isVerticallyPositioned;

  bool get isHorizontallyPositioned => left != null || right != null;
  bool get isVerticallyPositioned => top != null || bottom != null;

  // try to compute width and height automatically if the [super.width]/[super.height] fields aren't set
  @override
  double? get width =>
      (left != null && right != null ? left! - right! : null) ?? super.width;
  @override
  double? get height =>
      (top != null && bottom != null ? top! - bottom! : null) ?? super.height;

  Size? get size => hasSize ? Size(width!, height!) : null;

  bool get hasSize => width != null && height != null;
  bool get hasAbsoluteBounds => isPositioned && width != null && height != null;

  Rect computeBounds(Size size) {
    assert(isPositioned);

    var width = this.width ?? size.width;
    var height = this.height ?? size.height;

    return switch ((left, top, right, bottom)) {
      // dart format off
      (double left, double top,            _,             _) => Rect.fromLTRB(left, top, left + width, top + height),
      (          _, double top, double right,             _) => Rect.fromLTRB(right - width, top, right, top + height),
      (          _,          _, double right, double bottom) => Rect.fromLTRB(right - width, bottom - height, right, bottom),
      (double left,          _,            _, double bottom) => Rect.fromLTRB(left, bottom - height, left + width, bottom),
      _ => throw Exception()
      // dart format on
    };
  }

  @override
  @visibleForOverriding
  BoxConstraints positionedChildConstraints(Size size) => computeConstraints();

  // obviously canvas objects can't be infinite, but we also don't have any
  // finite bound on the size; so, just give them double.infinity, so the child
  // can decide what size it actually wants to be (and error out if it can't
  // figure out its size when it's unbounded)
  BoxConstraints computeConstraints() => BoxConstraints.loose(
    Size(width ?? double.infinity, height ?? double.infinity),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        DiagnosticsBlock(
          name: "position",
          properties: [
            DoubleProperty("left", left),
            DoubleProperty("top", top),
            DoubleProperty("right", right),
            DoubleProperty("bottom", bottom),
          ],
        ),
      )
      ..add(DoubleProperty("width", width))
      ..add(DoubleProperty("height", height))
      ..add(DiagnosticsProperty("size", size))
      ..add(
        FlagProperty(
          "isPositioned",
          value: isPositioned,
          ifTrue: "Is positioned",
          ifFalse: "Is not positioned",
        ),
      );
  }

  // todo: override toString()
}
