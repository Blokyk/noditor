// Original version under MIT License (c) 2024-2025 William Karol Di Cioccio
//
// Modified for use in the `noditor` project.

import 'dart:ui';
import 'package:meta/meta.dart';

@immutable
final class _Coords {
  final int x, y;
  const _Coords(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is _Coords && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => "($x, $y)";
}

final class _BoundedObj<T> {
  // [bounds] is not final but [value] is, because [value] is the
  // "base identity" of a [_BoundedObj], but [bounds] is just a
  // property we attached to it.
  //
  // this allows us to optimize slightly and store the same object
  // in every cell, and thus when updating the bounds (which happens
  // potentially very often for objects that can move), we can just
  // update the *one* instance of [_BoundedObj] that represents that
  // value, without iterating through every cell that it overlaps.
  Rect bounds;
  final T value;

  _BoundedObj(this.bounds, this.value);

  // We override equality/hashCode so that using a [T] where a
  // [_BoundedObj<T>] is expected is mostly transparent. This allows us
  // to speed up the different lookups/insertions/removes we'll have to
  // do. This is in part possible because [insert] and [update] make
  // sure no object is inserted twice, and thus there will ever only be
  // one singular [_BoundedObj<T>] instance for each object in the map.
  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      other == value ||
      (other is _BoundedObj && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => "$value w/ bounds $bounds";
}

typedef _Cell<T> = Set<_BoundedObj<T>>;

/// A [SpatialHashGrid] is a kind of spatial lookup acceleration
/// structure that stores objects who have a position and size in 2D
/// space (given as a [Rect] (axis-aligned) bounding box).
///
/// The grid divides the 2D space into cells of consistent size
/// ([cellSize]). Each cell maintains references to objects that
/// overlap with that cell.
class SpatialHashGrid<T> {
  /// The fixed size of each grid cell.
  ///
  /// {@template structial.spatial_grid.cellSize.perf}
  /// Tweaking the value of [cellSize] is important for maximum performance;
  /// ideally, each cell should be big enough to contain the average object
  /// and no more.
  /// {@endtemplate}
  final double cellSize;

  /// The main grid structure that maps grid cell indices to a set of
  /// objects (with their bounding box).
  final Map<_Coords, _Cell<T>> _grid = {};

  /// Maps raw [T] values to their associated bounded object
  final Map<T, _BoundedObj<T>> _valToBounds = {};

  /// Maps each object to the set of grid cells it occupies.
  final Map<T, Set<_Coords>> _objToCoords = {};

  /// Creates a new empty [SpatialHashGrid], with a configurable [cellSize].
  /// {@macro structial.spatial_grid.cellSize.perf}
  SpatialHashGrid({required this.cellSize}) {
    if (cellSize <= 0) {
      throw ArgumentError.value(
        cellSize,
        "cellSize",
        "Must be strictly greater than 0",
      );
    }

    if (!cellSize.isFinite) {
      throw ArgumentError.value(cellSize, "cellSize", "Must be finite");
    }
  }

  factory SpatialHashGrid.of(
    Iterable<T> items, {
    required double cellSize,
    required Rect Function(T) boundsOf,
  }) {
    final grid = SpatialHashGrid<T>(cellSize: cellSize);

    for (var item in items) {
      grid.insert(item, boundsOf(item));
    }

    return grid;
  }

  factory SpatialHashGrid.from(
    SpatialHashGrid<T> otherGrid, {
    double? cellSize,
  }) => SpatialHashGrid.fromEntries(
    otherGrid.entries.entries,
    cellSize: cellSize ?? otherGrid.cellSize,
  );

  factory SpatialHashGrid.fromEntries(
    Iterable<MapEntry<T, Rect>> itemsAndBounds, {
    required double cellSize,
  }) {
    final grid = SpatialHashGrid<T>(cellSize: cellSize);

    for (final MapEntry(key: item, value: bounds) in itemsAndBounds) {
      grid.insert(item, bounds);
    }

    return grid;
  }

  /// Calculates the grid coordinates for a given point in 2D space.
  _Coords _getGridCoords(Offset point) {
    return _Coords(
      (point.dx / cellSize).floor(),
      (point.dy / cellSize).floor(),
    );
  }

  /// Determines the set of cell coordinates that intersect with the
  /// given bounding box.
  Set<_Coords> _getCoveredCoords(Rect bounds) {
    final _Coords topLeft = _getGridCoords(bounds.topLeft);
    final _Coords bottomRight = _getGridCoords(bounds.bottomRight);

    // todo: replace this with an iterable, so that it doesn't
    // allocate enormous sets for big areas (this method is called by
    // basically everyone (including queryArea/queryPoint), so it
    // *needs* to be fast)
    final Set<_Coords> cells = {};

    for (int x = topLeft.x; x <= bottomRight.x; x++) {
      for (int y = topLeft.y; y <= bottomRight.y; y++) {
        cells.add(_Coords(x, y));
      }
    }

    return cells;
  }

  void _addToCell(_Coords coords, _BoundedObj<T> obj) {
    // look up the cell, or init it to an empty set if it isn't exist
    var cell = _grid.putIfAbsent(coords, () => {});
    // then add the object to it
    cell.add(obj);
  }

  /// Inserts a new object with a given bounding box into the spatial hash grid.
  /// If it is already present, it simply updates the position (see [update]).
  void insert(T obj, Rect bounds) {
    // if we already know about it, update the grid instead of double-inserting this obj
    if (_objToCoords.containsKey(obj)) {
      update(obj, bounds);
      return;
    }

    var boundedObj = _BoundedObj<T>(bounds, obj);
    _valToBounds[obj] = boundedObj;

    final Set<_Coords> cellsCoords = _getCoveredCoords(bounds);

    for (final coords in cellsCoords) {
      _addToCell(coords, boundedObj);
    }

    _objToCoords[obj] = cellsCoords;
  }

  /// Removes a value from the spatial hash grid.
  ///
  /// Returns a boolean indicating whether or not [obj] was actually
  /// contained in the map.
  bool remove(T obj) {
    // removes the node from the 'obj -> cell' map, and gets the set
    // of cells it occupied
    var affectedCellCoords = _objToCoords.remove(obj);

    // (if there was actually nothing to remove, just exit)
    if (affectedCellCoords == null) return false;

    // for each cell we occupied, remove the reference it held to us
    for (final cell in affectedCellCoords) {
      _grid[cell]!.remove(obj);
    }

    // forget about the [_BoundedObj] we made for this object
    _valToBounds.remove(obj);

    return true;
  }

  /// Update the bounds of the given object. If it wasn't already in the
  /// spatial grid, it is inserted (see [insert]).
  void update(T obj, Rect newBounds) {
    var boundedObj = _valToBounds[obj];

    // If we don't know about this object, insert it instead of updating
    if (boundedObj == null) {
      insert(obj, newBounds);
      return;
    }

    // very lightweight check to avoid expensive useless computations
    if (boundedObj.bounds == newBounds) return;

    final oldCoords = _objToCoords[obj]!;
    final newCoords = _getCoveredCoords(newBounds);

    // cells where the object used to be but isn't anymore
    final toRemove = oldCoords.difference(newCoords);
    for (final cell in toRemove) {
      _grid[cell]!.remove(obj);
    }

    // cells the object now overlaps but didn't before
    final toAdd = newCoords.difference(oldCoords);
    for (final cellCoords in toAdd) {
      _addToCell(cellCoords, boundedObj);
    }

    // update the existing [_BoundedObj] instance
    boundedObj.bounds = newBounds;
    // and finally, update the set of coords the new bounds overlap
    _objToCoords[obj] = newCoords;
  }

  /// Find all objects whose bounding box intersects the given [Rect] bounds.
  Set<T> queryArea(Rect bounds) {
    final Set<T> found = {};

    // get all coords of all the cells that *might* intersect with the given bounds
    final Set<_Coords> cellsCoords = _getCoveredCoords(bounds);

    for (final coords in cellsCoords) {
      var cell = _grid[coords];

      // if the coords don't even correspond to any cell in the grid, we can just skip it
      if (cell == null) continue;

      // if these coords *are* inside the grid
      for (final obj in cell) {
        // check that the object *actually* intersects the bounds,
        // and isn't just lumped in the same cell
        if (bounds.overlaps(obj.bounds)) {
          found.add(obj.value);
        }
      }
    }

    return found;
  }

  /// Find all the objects whose bounding box overlaps the 2D point
  Set<T> queryPoint(Offset point) {
    final _Coords coords = _getGridCoords(point);

    var cell = _grid[coords];

    // the point is outside the grid
    if (cell == null) return {};

    // return the values of each objects in the cell
    return cell.map((obj) => obj.value).toSet();
  }

  /// Clears all data from the spatial hash grid
  void clear() {
    _grid.clear();
    _objToCoords.clear();
    _valToBounds.clear();
  }

  /// Whether the spatial grid contains the given object
  bool contains(T obj) => boundsOf(obj) != null;

  /// The bounds of the given object, as specified when inserting/updating it into the grid.
  ///
  /// If the given object isn't contained in the spatial grid, returns null.
  Rect? boundsOf(T obj) => _valToBounds[obj]?.bounds;

  Iterable<T> get objects => _valToBounds.keys;

  Map<T, Rect> get entries => {
    for (final obj in _valToBounds.values) obj.value: obj.bounds,
  };

  /// Computes the total number of objects stored in the grid
  int get length => _valToBounds.length;

  /// Whether there is no object in the spatial grid
  bool get isEmpty => _valToBounds.isEmpty;

  /// Whether there is at least one object in the spatial grid
  bool get isNotEmpty => _valToBounds.isNotEmpty;
}
