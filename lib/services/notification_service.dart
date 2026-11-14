import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'tray_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final Map<String, Timer> _activeReminders = {};

  Future<void> initialize() async {
    if (_initialized || !Platform.isWindows) return;

    try {
      const initSettingsWindows = WindowsInitializationSettings(
        appName: 'Nexus Dashboard',
        appUserModelId: 'Nexus.Dashboard.App',
        guid: '3F2504E0-4F89-41D3-9A0C-0305E82C3301',
      );

      const initSettings = InitializationSettings(
        windows: initSettingsWindows,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (_) {
          TrayService.instance.showWindow();
        },
      );
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized || !Platform.isWindows) return;
    try {
      const details = NotificationDetails(
        windows: WindowsNotificationDetails(),
      );
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  /// Schedules an in-process timer to trigger a native Windows notification
  void scheduleTodoReminder({
    required String todoId,
    required String title,
    required DateTime dueAt,
  }) {
    cancelReminder(todoId);
    final now = DateTime.now();
    final delay = dueAt.difference(now);
    if (delay.isNegative) return;

    _activeReminders[todoId] = Timer(delay, () {
      _activeReminders.remove(todoId);
      showNotification(
        id: todoId.hashCode,
        title: 'Nexus To-Do Due',
        body: title,
      );
    });
  }

  void cancelReminder(String todoId) {
    _activeReminders[todoId]?.cancel();
    _activeReminders.remove(todoId);
  }
}
