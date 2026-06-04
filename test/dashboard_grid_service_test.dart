import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_dashboard/services/dashboard_grid_service.dart';

void main() {
  test('small deliberate resize drags snap to one grid step', () {
    expect(snapDragDeltaToGrid(18, 128), 1);
    expect(snapDragDeltaToGrid(-18, 128), -1);
  });

  test('tiny pointer movement is ignored', () {
    expect(snapDragDeltaToGrid(4, 128), 0);
    expect(snapDragDeltaToGrid(-4, 128), 0);
  });

  test('larger drags snap to multiple grid steps', () {
    expect(snapDragDeltaToGrid(270, 128), 3);
    expect(snapDragDeltaToGrid(-270, 128), -3);
  });
}
