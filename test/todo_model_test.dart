import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_dashboard/models/models.dart';

void main() {
  group('TodoItem', () {
    test('deserializes legacy JSON without dueAt and priority cleanly', () {
      final legacyJson = {
        'id': '123',
        'text': 'Buy milk',
        'completed': true,
        'createdAt': '2026-11-01T12:00:00.000',
      };

      final todo = TodoItem.fromJson(legacyJson);
      expect(todo.id, '123');
      expect(todo.text, 'Buy milk');
      expect(todo.completed, isTrue);
      expect(todo.dueAt, isNull);
      expect(todo.priority, TodoPriority.none);
      expect(todo.remind, isFalse);
    });

    test('serializes and deserializes rich todo with priority and due date', () {
      final dueDate = DateTime(2026, 11, 8, 15, 30);
      final item = TodoItem(
        id: '456',
        text: 'Finish report',
        completed: false,
        dueAt: dueDate,
        priority: TodoPriority.high,
        remind: true,
      );

      final json = item.toJson();
      final roundtrip = TodoItem.fromJson(json);

      expect(roundtrip.id, '456');
      expect(roundtrip.text, 'Finish report');
      expect(roundtrip.dueAt, dueDate);
      expect(roundtrip.priority, TodoPriority.high);
      expect(roundtrip.remind, isTrue);
    });
  });
}
