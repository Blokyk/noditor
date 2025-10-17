import 'package:canvas/src/canvas.dart';
import 'package:flutter/widgets.dart';

class DraggableObject extends StatefulWidget {
  final Widget child;

  // todo: add option to automatically set to top depth when dragged
  final double? depth;

  final ValueNotifier<Offset>? position;

  const DraggableObject({
    super.key,
    this.position,
    this.depth,
    required this.child,
  });

  @override
  State<StatefulWidget> createState() => _DraggableObjectState();
}

class _DraggableObjectState extends State<DraggableObject> {
  late ValueNotifier<Offset> _position;

  @override
  void initState() {
    super.initState();

    _position = widget.position ?? ValueNotifier(Offset.zero);
  }

  @override
  void didUpdateWidget(covariant DraggableObject oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.position != null && widget.position != oldWidget.position) {
      // if the new widget has a *given* position, then override the position
      // we previously had
      _position = widget.position!;
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() => _position.value += details.delta);
  }

  @override
  Widget build(BuildContext context) => CanvasObject(
    position: _position.value,
    depth: widget.depth,
    child: Draggable(
      onDragUpdate: _handleDragUpdate,
      feedback: SizedBox.fromSize(size: Size.zero),
      child: widget.child,
    ),
  );
}
