/// A single body landmark in aspect-corrected normalized image space.
///
/// `x` has been multiplied by the video's width/height ratio at parse time,
/// so distances and angles computed from these points are isotropic (both
/// axes are in units of image height). `visibility` is the pose model's
/// 0..1 confidence that the landmark is actually in frame.
class PosePoint {
  const PosePoint({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  final double x;
  final double y;
  final double z;
  final double visibility;
}

/// One frame of pose landmarks relevant to pushup counting, as delivered by
/// the platform pose engine.
///
/// The engine ships each frame as a flat list of doubles so the JS↔Dart
/// boundary stays cheap:
///
/// ```text
/// [0]  elapsed milliseconds since the session started
/// [1]  video aspect ratio (width / height)
/// [2…] nine landmarks × (x, y, z, visibility) in this order:
///      nose, leftEye, rightEye, leftShoulder, rightShoulder,
///      leftElbow, rightElbow, leftWrist, rightWrist
/// ```
class PoseSample {
  const PoseSample({
    required this.elapsed,
    required this.nose,
    required this.leftEye,
    required this.rightEye,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftElbow,
    required this.rightElbow,
    required this.leftWrist,
    required this.rightWrist,
  });

  /// Parses the flat wire format described on this class. Returns null if
  /// the list is malformed rather than throwing — a corrupt frame should be
  /// dropped, not crash the session.
  static PoseSample? fromFlat(List<double> values) {
    if (values.length < flatLength) {
      return null;
    }

    final aspect = values[1] > 0 ? values[1] : 1.0;
    PosePoint point(int index) {
      final base = 2 + index * 4;
      return PosePoint(
        x: values[base] * aspect,
        y: values[base + 1],
        z: values[base + 2],
        visibility: values[base + 3].clamp(0, 1),
      );
    }

    return PoseSample(
      elapsed: Duration(milliseconds: values[0].round()),
      nose: point(0),
      leftEye: point(1),
      rightEye: point(2),
      leftShoulder: point(3),
      rightShoulder: point(4),
      leftElbow: point(5),
      rightElbow: point(6),
      leftWrist: point(7),
      rightWrist: point(8),
    );
  }

  /// Number of doubles in the flat wire format: header (elapsed + aspect)
  /// plus nine landmarks of four values each.
  static const int flatLength = 2 + 9 * 4;

  final Duration elapsed;
  final PosePoint nose;
  final PosePoint leftEye;
  final PosePoint rightEye;
  final PosePoint leftShoulder;
  final PosePoint rightShoulder;
  final PosePoint leftElbow;
  final PosePoint rightElbow;
  final PosePoint leftWrist;
  final PosePoint rightWrist;
}
