import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Quaternion;

typedef ZoomUpdateHandler = void Function(double zoom);
typedef OffsetUpdateHandler = void Function(Offset offset);

final class ZoomDragDetector extends StatefulWidget {
  final ZoomUpdateHandler onZoomUpdate;
  final OffsetUpdateHandler onOffsetUpdate;

  const ZoomDragDetector({
    super.key,
    required this.onZoomUpdate,
    required this.onOffsetUpdate,
  });

  @override
  State<ZoomDragDetector> createState() => _ZoomDragDetectorState();
}

class _ZoomDragDetectorState extends State<ZoomDragDetector> {
  final TransformationController _transformController =
      TransformationController();

  _ZoomDragDetectorState() {
    _transformController.addListener(_onTransformUpdate);
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    minScale: double.minPositive,
    maxScale: double.maxFinite,
    boundaryMargin: EdgeInsets.all(double.infinity),
    transformationController: _transformController,
    // clipBehavior: Clip.none, // GridBackground already clips itself
    child: SizedBox.fromSize(size: Size.zero),
  );

  double _lastZoom = 1.0;
  Offset _lastOffset = Offset.zero;

  void _onTransformUpdate() {
    var translation = Vector3.zero();
    var rotation = Quaternion.identity();
    var scale = Vector3.zero();

    // todo: inline the code from [decompose] and specialize it to just offset.xy and scale.x
    _transformController.value.decompose(translation, rotation, scale);

    if (_lastZoom != scale.x) {
      assert(
        scale.x == scale.y && scale.y == scale.z,
        "Zoom should be uniform",
      );
      // no setState cause we don't need to rebuild
      _lastZoom = scale.x;
      widget.onZoomUpdate(scale.x);
    }

    // we divide by the zoom because the returned offset is "absolute":
    // it represents the offset you'd need to take into the viewer's child
    // if it was zoomed in by [scale]
    final offset = Offset(translation.x, translation.y) / _lastZoom;
    if (_lastOffset != offset) {
      assert(
        translation.z == 0,
        "We never offset the canvas in the 3rd dimension",
      );
      // no setState cause we don't need to rebuild
      _lastOffset = offset;
      widget.onOffsetUpdate(offset);
    }
  }
}
