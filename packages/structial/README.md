# structial

Data structures for accelerating spatial lookup.

Used by [`package:canvas`](../canvas/).

## Features

Currently implemented structures:

- Spatial hash grid

## Prerequisites

This library depends on `dart:ui` (mainly for `Rect` and `Offset`), so you will
need to be using Flutter.

No other dependencies right now!

## Usage

### Spatial hash grid

A spatial hash grid is a structure to speed up looking up 2D objects in a given
area or at a certain point. It stores a sparse list of "cells" that objects get
mapped to based on their bounding box.

Here's an example where the grid is initialized with a list of particles, and
then it is used to detect all the particles around a mouse click (and turn
them green):

```dart
final particles = randomParticles(count: 1000);
var grid = SpatialHashGrid<Particle>.of(
  particles,
  cellSize: 10.0,
  boundsOf: (particle) => particle.bounds,
);

void onMouseClick(Offset clickPosition) {
  var neighborhood = Rect.fromCircle(center: clickPosition, radius: 5.0);
  var particlesNearClick = grid.queryArea(neighborhood);
  for (var particle in particlesNearClick) {
    particle.color = Colors.green;
  }
}
```

You can insert and remove objects, but you can also update the position/bounds
of any already-inserted item. It is also possible to retrieve the stored bounds
of a given object with `SpatialHashGrid<T>.boundsOf`.
