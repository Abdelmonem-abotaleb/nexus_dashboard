import '../models/models.dart';

class DashboardGridService {
  static const int maxHeight = 6;

  static const Map<String, ({int width, int height})> minimumSizes = {
    'clock': (width: 3, height: 3),
    'weather': (width: 3, height: 3),
    'agenda': (width: 3, height: 3),
    'apps': (width: 3, height: 2),
    'todos': (width: 3, height: 2),
    'prayerTimes': (width: 3, height: 2),
    'system': (width: 3, height: 2),
    'power': (width: 3, height: 2),
    'websites': (width: 3, height: 2),
  };

  static List<DashboardWidgetPlacement> defaults(LayoutBreakpoint breakpoint) {
    final placements = breakpoint == LayoutBreakpoint.wide
        ? const [
            DashboardWidgetPlacement(
              id: 'clock',
              x: 0,
              y: 0,
              width: 3,
              height: 3,
            ),
            DashboardWidgetPlacement(
              id: 'weather',
              x: 3,
              y: 0,
              width: 3,
              height: 3,
            ),
            DashboardWidgetPlacement(
              id: 'agenda',
              x: 6,
              y: 0,
              width: 6,
              height: 3,
            ),
            DashboardWidgetPlacement(
              id: 'apps',
              x: 0,
              y: 3,
              width: 8,
              height: 3,
            ),
            DashboardWidgetPlacement(
              id: 'todos',
              x: 8,
              y: 3,
              width: 4,
              height: 3,
            ),
            DashboardWidgetPlacement(
              id: 'prayerTimes',
              x: 0,
              y: 6,
              width: 4,
              height: 2,
            ),
            DashboardWidgetPlacement(
              id: 'system',
              x: 4,
              y: 6,
              width: 4,
              height: 2,
            ),
            DashboardWidgetPlacement(
              id: 'power',
              x: 8,
              y: 6,
              width: 4,
              height: 2,
            ),
            DashboardWidgetPlacement(
              id: 'websites',
              x: 0,
              y: 8,
              width: 12,
              height: 2,
            ),
          ]
        : const [
            DashboardWidgetPlacement(
              id: 'clock',
              x: 0,
              y: 0,
              width: 3,
              height: 3,
            ),
            DashboardWidgetPlacement(
              id: 'weather',
              x: 3,
              y: 0,
              width: 3,
              height: 3,
            ),
            DashboardWidgetPlacement(
              id: 'agenda',
              x: 0,
              y: 3,
              width: 6,
              height: 3,
            ),
            DashboardWidgetPlacement(
              id: 'apps',
              x: 0,
              y: 6,
              width: 6,
              height: 3,
            ),
            DashboardWidgetPlacement(
              id: 'todos',
              x: 0,
              y: 9,
              width: 3,
              height: 3,
            ),
            DashboardWidgetPlacement(
              id: 'prayerTimes',
              x: 3,
              y: 9,
              width: 3,
              height: 2,
            ),
            DashboardWidgetPlacement(
              id: 'system',
              x: 0,
              y: 12,
              width: 3,
              height: 2,
            ),
            DashboardWidgetPlacement(
              id: 'power',
              x: 3,
              y: 12,
              width: 3,
              height: 2,
            ),
            DashboardWidgetPlacement(
              id: 'websites',
              x: 0,
              y: 14,
              width: 6,
              height: 2,
            ),
          ];
    return List.unmodifiable(placements);
  }

  static DashboardWidgetPlacement clamp(
    DashboardWidgetPlacement placement,
    LayoutBreakpoint breakpoint,
  ) {
    final minimum = minimumSizes[placement.id] ?? (width: 1, height: 1);
    final width = placement.width.clamp(minimum.width, breakpoint.columns);
    final height = placement.height.clamp(minimum.height, maxHeight);
    return placement.copyWith(
      x: placement.x.clamp(0, breakpoint.columns - width),
      y: placement.y.clamp(0, 200),
      width: width,
      height: height,
    );
  }

  static bool overlaps(
    DashboardWidgetPlacement a,
    DashboardWidgetPlacement b,
  ) => a.x < b.right && a.right > b.x && a.y < b.bottom && a.bottom > b.y;

  static List<DashboardWidgetPlacement> reflow({
    required Iterable<DashboardWidgetPlacement> placements,
    required DashboardWidgetPlacement edited,
    required LayoutBreakpoint breakpoint,
  }) {
    final target = clamp(edited, breakpoint);
    final remaining =
        placements
            .where((placement) => placement.id != target.id)
            .map((placement) => clamp(placement, breakpoint))
            .toList()
          ..sort(compare);
    final placed = <DashboardWidgetPlacement>[target];

    for (final original in remaining) {
      var candidate = original;
      while (true) {
        final collisions = placed.where((item) => overlaps(candidate, item));
        if (collisions.isEmpty) break;
        candidate = candidate.copyWith(
          y: collisions
              .map((item) => item.bottom)
              .reduce((a, b) => a > b ? a : b),
        );
      }
      candidate = _compactUp(candidate, placed);
      placed.add(candidate);
    }

    placed.sort(compare);
    return List.unmodifiable(placed);
  }

  static List<DashboardWidgetPlacement> normalize(
    Iterable<DashboardWidgetPlacement> placements,
    LayoutBreakpoint breakpoint,
  ) {
    final source = placements.map((item) => clamp(item, breakpoint)).toList()
      ..sort(compare);
    final placed = <DashboardWidgetPlacement>[];
    for (final original in source) {
      var candidate = original;
      while (true) {
        final collisions = placed.where((item) => overlaps(candidate, item));
        if (collisions.isEmpty) break;
        candidate = candidate.copyWith(
          y: collisions
              .map((item) => item.bottom)
              .reduce((a, b) => a > b ? a : b),
        );
      }
      placed.add(_compactUp(candidate, placed));
    }
    return List.unmodifiable(placed);
  }

  static DashboardWidgetPlacement _compactUp(
    DashboardWidgetPlacement placement,
    List<DashboardWidgetPlacement> occupied,
  ) {
    var candidate = placement;
    while (candidate.y > 0) {
      final moved = candidate.copyWith(y: candidate.y - 1);
      if (occupied.any((item) => overlaps(moved, item))) break;
      candidate = moved;
    }
    return candidate;
  }

  static int compare(DashboardWidgetPlacement a, DashboardWidgetPlacement b) {
    final row = a.y.compareTo(b.y);
    if (row != 0) return row;
    final column = a.x.compareTo(b.x);
    if (column != 0) return column;
    return a.id.compareTo(b.id);
  }
}
