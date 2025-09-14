import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';

// todo: allow having an "alignment" for the position: you can "anchor" the
//       widget either based on its top-left corner, on its center, etc.)
final class CanvasObjectParentData extends ContainerBoxParentData<RenderBox>
    with Diagnosticable {
  /// The xy coordinates of the top-left corner of this object in the canvas
  Offset? position;

  /// The z-axis depth of this object. By default, objects defined later in the
  /// canvas object list will be "above" their earlier depth-less siblings.
  double? depth;

  /// The inherent size of this object, if it has one. Must be finite.
  Size? get size => _size;
  Size? _size;
  set size(Size? newSize) {
    assert(newSize == null || newSize.isFinite);
    _size = newSize;
  }

  /// Whether the bounds of this object can be computed without needing to
  /// compute the size of (i.e. layout) the object. If you override
  /// [computeBounds], you might want to override this.
  bool get hasAbsoluteBounds => position != null && size != null;

  /// Computes the position and bounds of an object, based on [position]
  /// and either [size] or [laidOutSize].
  ///
  /// If [size] is non-null, it takes precedence over [laidOutSize] and
  /// the latter is optional. Otherwise, [laidOutSize] is mandatory.
  ///
  /// If you override this function, you might want to also override
  /// [hasAbsoluteBounds].
  Rect computeBounds({Size? laidOutSize}) {
    assert(position != null);

    assert(
      size != null || (laidOutSize != null && laidOutSize.isFinite),
      "Can't compute the bounds of an object that has neither absolute bounds nor a (finite) computed size.",
    );

    var width = size?.width ?? laidOutSize!.width;
    var height = size?.height ?? laidOutSize!.height;

    return Rect.fromLTWH(position!.dx, position!.dy, width, height);
  }

  // obviously canvas objects can't be infinite, but we also don't have any
  // finite bound on the size; so, just give them double.infinity, so the child
  // can decide what size it actually wants to be (and error out if it can't
  // figure out its size when it's unbounded)
  BoxConstraints computeConstraints() => size == null
      ? const BoxConstraints(
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: double.infinity,
        )
      : BoxConstraints.tight(size!);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty("position", position))
      ..add(DiagnosticsProperty("size", size));
  }

  // todo: override toString()
  // override equality maybe also?
}
