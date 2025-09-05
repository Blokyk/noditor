import 'package:flutter/widgets.dart';

final class GridTheme extends InheritedTheme {
  const GridTheme({super.key, required this.data, required super.child});

  /// The properties for descendant [GridBackground] widgets
  final GridThemeData data;

  /// Retrieves the [GridThemeData] from the closest [GridTheme] ancestor.
  ///
  /// When a widget uses this method, it is automatically rebuilt if the
  /// grid theme later changes, so that the changes can be applied.
  static GridThemeData of(BuildContext context) {
    final gridTheme = context.dependOnInheritedWidgetOfExactType<GridTheme>();

    assert(
      gridTheme != null,
      "GridTheme.of called on a BuildContext without any GridTheme ancestor",
    );

    return gridTheme!.data;
  }

  @override
  Widget wrap(BuildContext context, Widget child) =>
      GridTheme(data: data, child: child);

  @override
  bool updateShouldNotify(GridTheme oldWidget) => data != oldWidget.data;
}

@immutable
final class GridThemeData {
  /// The size (in pixels) of each grid cell; in other words, the
  /// spacing between each grid line on the X and Y axes.
  final Size cellSize;

  /// The width (in pixel) of the grid lines
  final double lineWidth;

  /// The color of the grid lines
  final Color lineColor;

  /// The size of the dot marking each intersecting grid line
  final double intersectionSize;

  /// The color of the dot marking each intersecting grid line
  final Color intersectionColor;

  const GridThemeData({
    this.lineWidth = 1.0,
    this.lineColor = const Color.fromARGB(64, 100, 100, 100),
    this.cellSize = const Size(64, 64),
    this.intersectionSize = 2.0,
    this.intersectionColor = const Color.fromARGB(128, 150, 150, 150),
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GridThemeData &&
          cellSize == other.cellSize &&
          lineWidth == other.lineWidth &&
          lineColor == other.lineColor &&
          intersectionSize == other.intersectionSize &&
          intersectionColor == other.intersectionColor);

  @override
  int get hashCode => Object.hash(
    cellSize,
    lineWidth,
    lineColor,
    intersectionSize,
    intersectionColor,
  );
}
