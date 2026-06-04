import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class TrayService {
  TrayService._();

  static final TrayService instance = TrayService._();

  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  bool _initialized = false;
  bool _exiting = false;

  bool get isExiting => _exiting;

  Future<void> initialize() async {
    if (_initialized || !Platform.isWindows) return;

    try {
      await _systemTray.initSystemTray(iconPath: _trayIconPath);
      await _systemTray.setToolTip('Nexus Dashboard');
      await _menu.buildFrom([
        MenuItemLabel(label: 'Show Nexus', onClicked: (_) => showWindow()),
        MenuItemLabel(label: 'Hide Nexus', onClicked: (_) => hideWindow()),
        MenuSeparator(),
        MenuItemLabel(label: 'Exit', onClicked: (_) => exitApp()),
      ]);
      await _systemTray.setContextMenu(_menu);
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          showWindow();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });
      _initialized = true;
    } catch (e) {
      debugPrint('Could not initialize system tray: $e');
    }
  }

  Future<void> showWindow() async {
    await windowManager.setSkipTaskbar(false);
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideWindow() async {
    await windowManager.hide();
  }

  Future<void> exitApp() async {
    _exiting = true;
    await _systemTray.destroy();
    await windowManager.destroy();
  }

  String get _trayIconPath =>
      Platform.isWindows ? 'assets/icons/logo.ico' : 'assets/icons/logo.png';
}
