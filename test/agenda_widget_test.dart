import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_dashboard/models/models.dart';
import 'package:nexus_dashboard/providers/agenda_provider.dart';
import 'package:nexus_dashboard/widgets/agenda_widget.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows empty state and opens add event dialog', (tester) async {
    final provider = AgendaProvider(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 700, height: 360, child: AgendaWidget()),
          ),
        ),
      ),
    );

    expect(find.text('Your next seven days are clear'), findsOneWidget);
    await tester.tap(find.byTooltip('Add event'));
    await tester.pumpAndSettle();
    expect(find.text('Add event'), findsWidgets);
    expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
  });

  testWidgets('renders an upcoming event', (tester) async {
    final provider = AgendaProvider(await SharedPreferences.getInstance());
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await provider.add(
      AgendaEvent(
        id: 'tomorrow',
        title: 'Team review',
        startsAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 700, height: 360, child: AgendaWidget()),
          ),
        ),
      ),
    );

    expect(find.text('Team review'), findsOneWidget);
    expect(find.textContaining('TOMORROW'), findsOneWidget);
  });
}
