import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_dashboard/widgets/particle_background.dart';

void main() {
  test('low resource mode disables particle rendering', () {
    expect(shouldRenderParticles(lowResourceMode: false), isTrue);
    expect(shouldRenderParticles(lowResourceMode: true), isFalse);
  });

  test('custom image backgrounds disable particle rendering', () {
    expect(
      shouldRenderParticles(lowResourceMode: false, hasBackgroundImage: true),
      isFalse,
    );
  });

  testWidgets('inactive particle background builds without ticking', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ParticleBackground(active: false)),
      ),
    );

    expect(find.byType(ParticleBackground), findsOneWidget);
  });
}
