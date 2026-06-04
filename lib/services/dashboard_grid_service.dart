import 'dart:math' as math;

int snapDragDeltaToGrid(double dragDelta, double gridStep) {
  if (gridStep <= 0) return 0;
  if (dragDelta.abs() < 12) return 0;
  final steps = (dragDelta.abs() / gridStep).ceil();
  return dragDelta.isNegative ? -steps : steps;
}

double clampPreviewDelta(double dragDelta, double minDelta, double maxDelta) {
  return math.min(math.max(dragDelta, minDelta), maxDelta);
}
