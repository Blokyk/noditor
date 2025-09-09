import 'dart:ui';

extension DarkenLightenColor on Color {
  /// Make the color lighter based on [amount]. If [amount] is 0.0, it will be the
  /// original color; if it is 1.0, it will be completely (solid) white. Values
  /// outside of [0.0, 1.0] are undefined and might give wrong results.
  Color lighten(double amount) =>
      Color.lerp(this, const Color(0xFFFFFFFF), amount)!;

  /// Make the color darker based on [amount]. If [amount] is 0.0, it will be the
  /// original color; if it is 1.0, it will be completely (solid) black. Values
  /// outside of [0.0, 1.0] are undefined and might give wrong results.
  Color darken(double amount) =>
      Color.lerp(this, const Color(0xFF000000), amount)!;

  /// Either [lighten] or [darken] this color, towards the given [brightness].
  /// See the documentation for [lighten] and [darken] for more info.
  Color adjust(Brightness brightness, double amount) => switch (brightness) {
    Brightness.light => lighten(amount),
    Brightness.dark => darken(amount),
  };

  /// Either [darken] or [lighten] this color, in the opposite direction of
  /// the given [brightness]. See the documentation for [lighten] and [darken]
  /// for more info.
  Color adjustAgainst(Brightness brightness, double amount) =>
      switch (brightness) {
        Brightness.light => lighten(amount),
        Brightness.dark => darken(amount),
      };
}
