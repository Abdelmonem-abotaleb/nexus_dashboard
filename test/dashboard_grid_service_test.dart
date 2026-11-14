import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_dashboard/models/models.dart';
import 'package:nexus_dashboard/services/dashboard_grid_service.dart';

void main() {
  test('placement serializes without losing grid coordinates', () {
    const placement = DashboardWidgetPlacement(
      id: 'agenda',
      x: 2,
      y: 4,
      width: 5,
      height: 3,
    );

    final decoded = DashboardWidgetPlacement.fromJson(placement.toJson());

    expect(decoded.id, placement.id);
    expect(decoded.x, placement.x);
    expect(decoded.y, placement.y);
    expect(decoded.width, placement.width);
    expect(decoded.height, placement.height);
  });

  test('clamps placements to breakpoint and widget minimums', () {
    const placement = DashboardWidgetPlacement(
      id: 'clock',
      x: 20,
      y: -4,
      width: 1,
      height: 1,
    );

    final clamped = DashboardGridService.clamp(
      placement,
      LayoutBreakpoint.medium,
    );

    expect(clamped.x, 3);
    expect(clamped.y, 0);
    expect(clamped.width, 3);
    expect(clamped.height, 3);
  });

  test('reflow keeps edited card and pushes collisions without overlap', () {
    final initial = DashboardGridService.defaults(LayoutBreakpoint.wide);
    const edited = DashboardWidgetPlacement(
      id: 'agenda',
      x: 0,
      y: 0,
      width: 6,
      height: 3,
    );

    final result = DashboardGridService.reflow(
      placements: initial,
      edited: edited,
      breakpoint: LayoutBreakpoint.wide,
    );

    final agenda = result.singleWhere((item) => item.id == 'agenda');
    expect(agenda.x, 0);
    expect(agenda.y, 0);
    for (var i = 0; i < result.length; i++) {
      for (var j = i + 1; j < result.length; j++) {
        expect(DashboardGridService.overlaps(result[i], result[j]), isFalse);
      }
    }
  });

  test('wide and medium defaults use their own column counts', () {
    final wide = DashboardGridService.defaults(LayoutBreakpoint.wide);
    final medium = DashboardGridService.defaults(LayoutBreakpoint.medium);

    expect(wide.every((item) => item.right <= 12), isTrue);
    expect(medium.every((item) => item.right <= 6), isTrue);
    expect(
      wide.singleWhere((item) => item.id == 'apps').width,
      isNot(medium.singleWhere((item) => item.id == 'apps').width),
    );
  });
}
