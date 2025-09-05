import 'package:flutter/foundation.dart';

/// An empty [Listenable] that simply allows notifying listeners by
/// calling the [raise] method, instead of having to manage a
/// [ValueNotifier] for no other reason than to just raise an
/// event once in a while.
final class Signal with ChangeNotifier implements Listenable {
  /// Notifies all listeners of this [Listenable]
  void raise() => notifyListeners();
}
