/// Manages A-B loop state.
/// The player polls [shouldLoop] and calls [maybeSeekBack] every position update.
class AbLoopController {
  Duration? pointA;
  Duration? pointB;

  bool get isActive => pointA != null && pointB != null;
  bool get hasA => pointA != null;
  bool get hasB => pointB != null;

  void setA(Duration pos) {
    pointA = pos;
    if (pointB != null && pointB! <= pos) pointB = null;
  }

  void setB(Duration pos) {
    if (pointA == null || pos <= pointA!) return;
    pointB = pos;
  }

  void clear() {
    pointA = null;
    pointB = null;
  }

  /// Returns the A point if position has passed B (so caller can seek back to A).
  Duration? maybeSeekBack(Duration current) {
    if (!isActive) return null;
    if (current >= pointB!) return pointA;
    return null;
  }

  String get aLabel => pointA == null ? '--:--' : _fmt(pointA!);
  String get bLabel => pointB == null ? '--:--' : _fmt(pointB!);

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
