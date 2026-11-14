import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_dashboard/models/models.dart';
import 'package:nexus_dashboard/providers/agenda_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('serializes and validates agenda events', () {
    final event = AgendaEvent(
      id: 'event-1',
      title: 'Doctor',
      startsAt: DateTime(2026, 9, 3, 10),
      endsAt: DateTime(2026, 9, 3, 11),
      notes: 'Bring results',
    );

    expect(event.validate(), isNull);
    expect(AgendaEvent.fromJson(event.toJson()).title, 'Doctor');
    expect(
      event.copyWith(endsAt: DateTime(2026, 9, 3, 9)).validate(),
      contains('after'),
    );
    expect(event.copyWith(title: ' ').validate(), contains('required'));
  });

  test(
    'loads valid records, skips malformed records, and sorts events',
    () async {
      SharedPreferences.setMockInitialValues({
        'agendaEvents': [
          'not json',
          jsonEncode({
            'id': 'later',
            'title': 'Later',
            'startsAt': '2026-09-04T12:00:00.000',
            'isAllDay': false,
          }),
          jsonEncode({
            'id': 'all-day',
            'title': 'All day',
            'startsAt': '2026-09-03T00:00:00.000',
            'isAllDay': true,
          }),
        ],
      });
      final provider = AgendaProvider(await SharedPreferences.getInstance());

      expect(provider.events.map((event) => event.id), ['all-day', 'later']);
    },
  );

  test('adds, updates, removes, and persists immutable snapshots', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = AgendaProvider(prefs);
    final firstSnapshot = provider.events;
    final event = AgendaEvent(
      id: 'event-1',
      title: 'Planning',
      startsAt: DateTime(2026, 9, 5, 14),
    );

    expect(await provider.add(event), isNull);
    expect(provider.events, isNot(same(firstSnapshot)));
    expect(prefs.getStringList('agendaEvents'), hasLength(1));

    expect(
      await provider.update(event.copyWith(title: 'Weekly planning')),
      isNull,
    );
    expect(provider.events.single.title, 'Weekly planning');

    await provider.remove(event.id);
    expect(provider.events, isEmpty);
  });
}
