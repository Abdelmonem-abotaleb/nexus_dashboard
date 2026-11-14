import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import 'tray_service.dart';

class HotkeyService {
  HotkeyService._();

  static final HotkeyService instance = HotkeyService._();

  bool _initialized = false;
  HotKey? _currentHotKey;
  VoidCallback? onTriggered;

  Future<void> initialize({VoidCallback? onAction}) async {
    if (!Platform.isWindows) return;
    if (onAction != null) onTriggered = onAction;
    if (_initialized) return;

    try {
      _initialized = true;
      // Default hotkey: Ctrl + Alt + Space
      _currentHotKey = HotKey(
        key: PhysicalKeyboardKey.space,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      );

      await hotKeyManager.register(
        _currentHotKey!,
        keyDownHandler: (_) => _handleHotKey(),
      );
    } catch (e) {
      debugPrint('Could not register global hotkey: $e');
    }
  }

  Future<void> _handleHotKey() async {
    // Bring window to front
    await TrayService.instance.showWindow();
    onTriggered?.call();
  }

  Future<void> updateHotKey(HotKey newHotKey) async {
    if (!Platform.isWindows) return;
    try {
      if (_currentHotKey != null) {
        await hotKeyManager.unregister(_currentHotKey!);
      }
      _currentHotKey = newHotKey;
      await hotKeyManager.register(
        newHotKey,
        keyDownHandler: (_) => _handleHotKey(),
      );
    } catch (e) {
      debugPrint('Failed to update hotkey: $e');
    }
  }

  Future<void> dispose() async {
    if (!Platform.isWindows) return;
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {}
  }
}
