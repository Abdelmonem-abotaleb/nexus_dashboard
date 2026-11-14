import 'package:flutter/foundation.dart';

enum ActivityLevel { focused, visibleUnfocused, hidden }

class WindowActivityProvider extends ChangeNotifier {
  bool _visible = true;
  bool _focused = true;

  bool get isActive => _visible && _focused;
  bool get isVisible => _visible;
  bool get isFocused => _focused;

  ActivityLevel get level {
    if (!_visible) return ActivityLevel.hidden;
    if (_focused) return ActivityLevel.focused;
    return ActivityLevel.visibleUnfocused;
  }

  void setFocused(bool value) {
    if (_focused == value) return;
    _focused = value;
    notifyListeners();
  }

  void setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    notifyListeners();
  }
}
