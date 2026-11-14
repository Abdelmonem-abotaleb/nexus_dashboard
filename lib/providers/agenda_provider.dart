import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class AgendaProvider extends ChangeNotifier {
  static const _storageKey = 'agendaEvents';
  final SharedPreferences _prefs;
  List<AgendaEvent> _events = const [];

  AgendaProvider(this._prefs) {
    _events = _loadEvents();
  }

  List<AgendaEvent> get events => _events;

  List<AgendaEvent> eventsBetween(DateTime start, DateTime end) => _events
      .where(
        (event) =>
            !event.startsAt.isBefore(start) && event.startsAt.isBefore(end),
      )
      .toList(growable: false);

  Future<String?> add(AgendaEvent event) async {
    final error = event.validate();
    if (error != null) return error;
    _events = _sorted([..._events, event]);
    await _save();
    notifyListeners();
    return null;
  }

  Future<String?> update(AgendaEvent event) async {
    final error = event.validate();
    if (error != null) return error;
    final index = _events.indexWhere((candidate) => candidate.id == event.id);
    if (index < 0) return 'Event no longer exists.';
    final updated = [..._events]..[index] = event;
    _events = _sorted(updated);
    await _save();
    notifyListeners();
    return null;
  }

  Future<void> remove(String id) async {
    final updated = _events.where((event) => event.id != id).toList();
    if (updated.length == _events.length) return;
    _events = List.unmodifiable(updated);
    await _save();
    notifyListeners();
  }

  String generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  List<AgendaEvent> _loadEvents() {
    final events = <AgendaEvent>[];
    for (final encoded in _prefs.getStringList(_storageKey) ?? const []) {
      try {
        final json = jsonDecode(encoded);
        if (json is Map<String, dynamic>) {
          events.add(AgendaEvent.fromJson(json));
        }
      } catch (_) {
        // A malformed item should not prevent the dashboard from starting.
      }
    }
    return _sorted(events);
  }

  List<AgendaEvent> _sorted(Iterable<AgendaEvent> source) {
    final events = source.toList()
      ..sort((a, b) {
        final date = a.startsAt.compareTo(b.startsAt);
        if (date != 0) return date;
        if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    return List.unmodifiable(events);
  }

  Future<void> _save() => _prefs.setStringList(
    _storageKey,
    _events.map((event) => jsonEncode(event.toJson())).toList(),
  );
}
