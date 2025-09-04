import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:structial/structial.dart';

/// A small rectangle (10x10), centered around 0
const smallRect = Rect.fromLTRB(-5, -5, 5, 5);

/// A big rectangle (100x100), centered around 0
const bigRect = Rect.fromLTRB(-50, -50, 50, 50);

void main() {
  group("empty grid", () {
    final grid = SpatialHashGrid(cellSize: 5.0);

    test("is empty", () {
      expect(grid.length, 0);
      expect(grid.isEmpty, true);
      expect(grid.isNotEmpty, false);
    });

    test("doesn't contain anything", () {
      expect(grid.queryArea(smallRect), <dynamic>{});
      expect(grid.queryPoint(Offset.zero), <dynamic>{});
    });
  });

  group("grid ctor", () {
    group(".new()", () {
      test("needs positive cellSize", () {
        expect(() => SpatialHashGrid(cellSize: 0.0), throwsA(isArgumentError));
        expect(() => SpatialHashGrid(cellSize: -2.5), throwsA(isArgumentError));
      });

      test("needs finite cellSize", () {
        expect(
          () => SpatialHashGrid(cellSize: double.negativeInfinity),
          throwsA(isArgumentError),
        );
        expect(
          () => SpatialHashGrid(cellSize: double.infinity),
          throwsA(isArgumentError),
        );
        expect(
          () => SpatialHashGrid(cellSize: double.nan),
          throwsA(isArgumentError),
        );
      });
    });

    group(".of()", skip: "SpatialHashGrid doesn't have value-equality yet", () {
      test("works with no items", () {
        final expected = SpatialHashGrid(cellSize: 10.0);

        expect(
          SpatialHashGrid.of([], cellSize: 10.0, boundsOf: (_) => Rect.zero),
          expected,
        );
      });

      test("works with normal items", () {
        Rect boundsOf(int i) => Rect.fromLTRB(
          -(i as double),
          -(i as double),
          i as double,
          i as double,
        );

        final expected = SpatialHashGrid<int>(cellSize: 5.0);

        expected.insert(1, boundsOf(1));
        expected.insert(2, boundsOf(2));
        expected.insert(3, boundsOf(3));

        final items = [1, 2, 3];
        expect(
          SpatialHashGrid<int>.of(items, cellSize: 5.0, boundsOf: boundsOf),
          expected,
        );
      });
    });
  });

  group("grid with one object", () {
    final grid = SpatialHashGrid<int>(cellSize: 5.0);

    final obj = 1;
    final bounds = smallRect;

    setUpAll(() => grid.insert(obj, bounds));

    test("has correct length", () {
      expect(grid.length, 1);
      expect(grid.isEmpty, false);
      expect(grid.isNotEmpty, true);
    });

    test(
      "returns object when querying exact bounds",
      () => expect(grid.queryArea(bounds), {obj}),
    );

    test("returns object when querying offset bounds", () {
      final newBounds = bounds.shift(Offset(2, 2));
      expect(grid.queryArea(newBounds), {obj});
    });

    test("returns object when querying inside points", () {
      expect(grid.queryPoint(Offset.zero), {obj});
      expect(grid.queryPoint(Offset(-3, 4)), {obj});
    });

    test("doesn't return anything when querying outside", () {
      final newBounds = bounds.shift(Offset(12, 34));
      expect(grid.queryArea(newBounds), <int>{});

      expect(grid.queryPoint(Offset(12, 34)), <int>{});
    });
  });

  // todo: add tests for multiple objects
}
