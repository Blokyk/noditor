import 'dart:ui';

import 'package:canvas/src/grid_theme.dart';
import 'package:canvas/src/utils/signal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

/// A widget that allows a child to be displayed over a configurable
/// infinite grid background. This acts like [GridPaper], but it draws
/// the grid underneath the child instead of above it, and allows one
/// to efficiently animate the zoom and offset of the grid.
///
/// The grid's appearance can be customized by inserting a [GridTheme] widget
/// as a parent.
///
/// For best performance in expected scenarios, this widget wraps
/// *itself* in a [RepaintBoundary], to avoid repainting the whole app
/// every time the grid is animated; thus, there is no need to wrap
/// this in a separate [RepaintBoundary].
final class GridBackground extends StatefulWidget {
  /// The number of units to offset the grid by, in the x and y direction.
  /// This offset is applied before the zoom, but at zoom = 1.0, a unit
  /// is equivalent to a logical pixel.
  final ValueListenable<Offset> offset;

  /// How zoomed-in the grid should be. By default,
  final ValueListenable<double> zoom;

  final Size size;

  /// The widget drawn over the grid background.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget? child;

  const GridBackground({
    super.key,
    required this.child,
    this.offset = const AlwaysStoppedAnimation(Offset.zero),
    this.zoom = const AlwaysStoppedAnimation(1.0),
  }) : size = Size.zero;

  const GridBackground.empty({
    super.key,
    required this.size,
    this.offset = const AlwaysStoppedAnimation(Offset.zero),
    this.zoom = const AlwaysStoppedAnimation(1.0),
  }) : child = null;

  @override
  State<GridBackground> createState() => _GridBackgroundState();
}

Future<FragmentProgram> _gridProg = FragmentProgram.fromAsset(
  'assets/grid.frag',
);

final class _GridBackgroundState extends State<GridBackground> {
  late final _GridPainter _gridPainter;

  @override
  void initState() {
    super.initState();

    _gridPainter = _GridPainter(
      offset: widget.offset,
      zoom: widget.zoom,
      theme: const GridThemeData(),
    );
  }

  @override
  void didUpdateWidget(covariant GridBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    _gridPainter.offset = widget.offset;
    _gridPainter._zoom = widget.zoom;
  }

  @override
  Widget build(BuildContext context) {
    // todo: this feels wrong... there has to be another way to do this :thunk:
    _gridPainter.theme = GridTheme.of(context);

    return RepaintBoundary(
      child: CustomPaint(
        painter: _gridPainter,
        isComplex: true,
        size: widget.size,
        child: widget.child,
      ),
    );
  }
}

final class _GridPainter extends CustomPainter {
  FragmentShader? _gridShader;

  ValueListenable<Offset> _offset;
  ValueListenable<Offset> get offset => _offset;
  set offset(ValueListenable<Offset> newOffsetListenable) {
    // we need ref-equality because we *have* to make sure
    // the listeners are the same, and it's possible that
    // an implementation of `ValueListenable` implements
    // value equality without considering listeners
    if (identical(_offset, newOffsetListenable)) return;

    _offset.removeListener(_onViewportChange);
    _offset = newOffsetListenable;
    _offset.addListener(_onViewportChange);
  }

  ValueListenable<double> _zoom;
  ValueListenable<double> get zoom => _zoom;
  set zoom(ValueListenable<double> newZoomListenable) {
    // cf comment in offset setter
    if (identical(_zoom, newZoomListenable)) return;

    _zoom.removeListener(_onViewportChange);
    _zoom = newZoomListenable;
    _zoom.addListener(_onViewportChange);
  }

  GridThemeData _theme;
  GridThemeData get theme => _theme;
  set theme(GridThemeData newTheme) {
    if (_theme == newTheme) return;

    _onThemeChange(newTheme);
    _theme = newTheme;
  }

  _GridPainter({
    required ValueListenable<Offset> offset,
    required ValueListenable<double> zoom,
    required GridThemeData theme,
  }) : _offset = offset,
       _zoom = zoom,
       _theme = theme {
    () async {
      _gridShader = (await _gridProg).fragmentShader();
      repaintSignal.raise();
    }();

    // setup the listeners for the offset and zoom listenables
    offset.addListener(_onViewportChange);
    zoom.addListener(_onViewportChange);

    // setup initial theme and viewport
    _onThemeChange(theme);
    _onViewportChange();
  }

  void _onThemeChange(GridThemeData newTheme) {
    if (_gridShader == null) return;

    final shader =
        _gridShader!; // avoids extraneous null-checks because dart is dumb

    // uniform vec2 gridSpacing
    shader.setFloat(0, newTheme.cellSize.width);
    shader.setFloat(1, newTheme.cellSize.height);

    // uniform float lineWidth
    shader.setFloat(2, newTheme.lineWidth);

    // uniform vec4 lineColor
    shader.setFloat(3, newTheme.lineColor.r * newTheme.lineColor.a);
    shader.setFloat(4, newTheme.lineColor.g * newTheme.lineColor.a);
    shader.setFloat(5, newTheme.lineColor.b * newTheme.lineColor.a);
    shader.setFloat(6, newTheme.lineColor.a);

    // uniform float intersectionRadius
    shader.setFloat(7, newTheme.intersectionSize);

    // uniform vec4 intersectionColor
    shader.setFloat(
      8,
      newTheme.intersectionColor.r * newTheme.intersectionColor.a,
    );
    shader.setFloat(
      9,
      newTheme.intersectionColor.g * newTheme.intersectionColor.a,
    );
    shader.setFloat(
      10,
      newTheme.intersectionColor.b * newTheme.intersectionColor.a,
    );
    shader.setFloat(11, newTheme.intersectionColor.a);

    repaintSignal.raise();
  }

  void _onViewportChange() => repaintSignal.raise();

  @override
  void paint(Canvas canvas, Size size) {
    if (_gridShader == null) return;

    // 1. offset to the desired coordinates/offset
    // 2. zoom into that point
    // 3. offset the canvas by half its size (simplifies the shader)
    Matrix4 viewportTransform = Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height / 2, 0, 1.0)
      ..scaleByDouble(zoom.value, zoom.value, 0, 1.0)
      ..translateByDouble(offset.value.dx, offset.value.dy, 0, 1.0);

    canvas.transform(viewportTransform.storage);

    canvas.drawPaint(Paint()..shader = _gridShader);
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      // the only times we need to rebuild are when the `repaint` signal
      // is fired, [_GridBackgroundState] only ever passes the same instance
      // to [CustomPaint]
      false;

  final Signal repaintSignal = Signal();

  // We override [addListener] and [removeListener] because DART SUCKS >:|
  //
  // (we can't just pass [this.repaint] to the [CustomPainter.new().repaint]
  // argument, so instead we completely bypass it by replacing the previous
  // implementation (which forwarded to [CustomPainter._repaint]) to *our*
  // our [repaint] field
  @override
  void addListener(VoidCallback listener) =>
      repaintSignal.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      repaintSignal.removeListener(listener);
}
