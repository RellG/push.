import 'dart:math' as math;

import 'package:push_app/domain/models/pose_sample.dart';

/// A normalized pushup depth (0 = top, 1 = bottom) plus the landmark
/// confidence it was derived from. Consumed by `RepCounter`.
class DepthReading {
  const DepthReading({required this.depth, required this.confidence});

  final double depth;
  final double confidence;
}

/// Depth from the interior elbow angle — for cameras that see the body from
/// the side (a laptop webcam, a propped-up phone). A straight arm (~180°)
/// is the top of the rep; a folded arm (~85° or less) is the bottom.
///
/// Uses whichever arm is more visible each frame; the angle is absolute, so
/// no calibration is needed and switching sides is safe.
class ElbowAngleDepthExtractor {
  const ElbowAngleDepthExtractor({
    this.upAngleDegrees = 160,
    this.downAngleDegrees = 85,
    this.minVisibility = 0.5,
  });

  final double upAngleDegrees;
  final double downAngleDegrees;
  final double minVisibility;

  DepthReading? extract(PoseSample sample) {
    final left = _armConfidence(
      sample.leftShoulder,
      sample.leftElbow,
      sample.leftWrist,
    );
    final right = _armConfidence(
      sample.rightShoulder,
      sample.rightElbow,
      sample.rightWrist,
    );

    final useLeft = left >= right;
    final confidence = useLeft ? left : right;
    if (confidence < minVisibility) {
      return null;
    }

    final angle = useLeft
        ? _angleDegrees(sample.leftElbow, sample.leftShoulder, sample.leftWrist)
        : _angleDegrees(
            sample.rightElbow,
            sample.rightShoulder,
            sample.rightWrist,
          );
    if (angle == null) {
      return null;
    }

    final range = upAngleDegrees - downAngleDegrees;
    final depth = ((upAngleDegrees - angle) / range).clamp(0.0, 1.0);
    return DepthReading(depth: depth, confidence: confidence);
  }

  double _armConfidence(PosePoint shoulder, PosePoint elbow, PosePoint wrist) {
    return math.min(
      shoulder.visibility,
      math.min(elbow.visibility, wrist.visibility),
    );
  }

  /// Interior angle at [vertex] between rays toward [a] and [b], in degrees.
  /// Null when either ray is degenerate (coincident points).
  double? _angleDegrees(PosePoint vertex, PosePoint a, PosePoint b) {
    final v1x = a.x - vertex.x;
    final v1y = a.y - vertex.y;
    final v2x = b.x - vertex.x;
    final v2y = b.y - vertex.y;
    final n1 = math.sqrt(v1x * v1x + v1y * v1y);
    final n2 = math.sqrt(v2x * v2x + v2y * v2y);
    if (n1 == 0 || n2 == 0) {
      return null;
    }

    final cosine = ((v1x * v2x + v1y * v2y) / (n1 * n2)).clamp(-1.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }
}

/// Depth from apparent body scale — for a phone lying on the floor facing
/// up, where arms are out of frame but the face/shoulders loom larger as
/// the body descends toward the lens.
///
/// The signal is the shoulder-to-shoulder distance (or the inter-eye
/// distance when shoulders are out of frame; the source is locked at the
/// first valid frame so the two scales never mix). Because apparent size
/// depends on the person and the phone position, the extractor calibrates a
/// "top of rep" baseline from the first valid frames — callers should tell
/// the user to hold the up position while [isCalibrating] is true — and
/// keeps healing the baseline downward if a smaller width is seen later.
class ProximityDepthExtractor {
  ProximityDepthExtractor({
    this.calibrationSampleCount = 15,
    this.expansionRange = 0.35,
    this.minVisibility = 0.4,
  });

  /// Valid frames collected before the baseline locks in.
  final int calibrationSampleCount;

  /// Fraction of growth over the baseline width that maps to full depth:
  /// with 0.35, a 35% larger apparent width reads as the bottom of the rep.
  final double expansionRange;

  final double minVisibility;

  final List<double> _calibrationWidths = [];
  double? _baseline;
  _ProximitySource? _source;

  bool get isCalibrating => _baseline == null;

  DepthReading? extract(PoseSample sample) {
    final measured = _measure(sample);
    if (measured == null) {
      return null;
    }

    final baseline = _baseline;
    if (baseline == null) {
      _calibrationWidths.add(measured.width);
      if (_calibrationWidths.length >= calibrationSampleCount) {
        _baseline = _median(_calibrationWidths);
        _calibrationWidths.clear();
      }
      return null;
    }

    // The top of the rep is the smallest width there is; if we ever see a
    // smaller one the calibration caught the user mid-rep, so ease the
    // baseline down toward it (gently — a single noisy frame must not
    // permanently inflate every later depth).
    if (measured.width < baseline) {
      _baseline = baseline * 0.75 + measured.width * 0.25;
    }

    final depth =
        ((measured.width / _baseline! - 1) / expansionRange).clamp(0.0, 1.0);
    return DepthReading(depth: depth, confidence: measured.confidence);
  }

  /// Whether this sample carries a usable proximity signal (used by the
  /// mode-selection logic before any baseline exists).
  bool hasSignalSource(PoseSample sample) => _measure(sample) != null;

  _WidthMeasurement? _measure(PoseSample sample) {
    // Lock the measurement source on first contact: shoulder width and eye
    // distance live on different scales, so a session must never mix them.
    final source = _source ??
        (_visible(sample.leftShoulder, sample.rightShoulder)
            ? _ProximitySource.shoulders
            : _visible(sample.leftEye, sample.rightEye)
                ? _ProximitySource.eyes
                : null);
    if (source == null) {
      return null;
    }
    _source = source;

    final (a, b) = switch (source) {
      _ProximitySource.shoulders => (sample.leftShoulder, sample.rightShoulder),
      _ProximitySource.eyes => (sample.leftEye, sample.rightEye),
    };
    if (!_visible(a, b)) {
      return null;
    }

    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final width = math.sqrt(dx * dx + dy * dy);
    if (width <= 0) {
      return null;
    }

    return _WidthMeasurement(
      width: width,
      confidence: math.min(a.visibility, b.visibility),
    );
  }

  bool _visible(PosePoint a, PosePoint b) {
    return a.visibility >= minVisibility && b.visibility >= minVisibility;
  }

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}

class _WidthMeasurement {
  const _WidthMeasurement({required this.width, required this.confidence});

  final double width;
  final double confidence;
}

enum _ProximitySource { shoulders, eyes }

/// How the estimator is reading depth. Exposed so the capture HUD can tell
/// the user what the camera has locked onto.
enum DepthMode { deciding, elbowAngle, proximity }

/// Turns raw [PoseSample]s into [DepthReading]s, automatically picking the
/// extraction strategy for how the user has set the camera up.
///
/// The first [decisionWindow] usable frames are spent watching which signal
/// is present: if the arm chain (shoulder–elbow–wrist) is reliably visible
/// the camera has a side view and the precise elbow-angle strategy wins;
/// otherwise it falls back to face/shoulder proximity (phone on the floor).
/// The mode locks after the window so a mid-session flicker of the other
/// signal can't corrupt depth continuity. Returns null while deciding or
/// calibrating — the UI should show a "hold steady" state.
class DepthEstimator {
  DepthEstimator({
    ElbowAngleDepthExtractor? elbowExtractor,
    ProximityDepthExtractor? proximityExtractor,
    this.decisionWindow = 24,
  })  : _elbow = elbowExtractor ?? const ElbowAngleDepthExtractor(),
        _proximity = proximityExtractor ?? ProximityDepthExtractor();

  /// Usable frames observed before the mode locks.
  final int decisionWindow;

  final ElbowAngleDepthExtractor _elbow;
  ProximityDepthExtractor _proximity;

  DepthMode _mode = DepthMode.deciding;
  int _framesSeen = 0;
  int _elbowHits = 0;

  DepthMode get mode => _mode;

  DepthReading? process(PoseSample sample) {
    switch (_mode) {
      case DepthMode.deciding:
        final elbowReading = _elbow.extract(sample);
        final proximityUsable = _proximity.hasSignalSource(sample);
        // Warm the proximity baseline during the window so a proximity
        // decision doesn't restart calibration from zero.
        _proximity.extract(sample);

        if (elbowReading != null) {
          _elbowHits += 1;
        }
        if (elbowReading != null || proximityUsable) {
          _framesSeen += 1;
        }
        if (_framesSeen >= decisionWindow) {
          _mode = _elbowHits * 2 >= _framesSeen
              ? DepthMode.elbowAngle
              : DepthMode.proximity;
        }
        return null;
      case DepthMode.elbowAngle:
        return _elbow.extract(sample);
      case DepthMode.proximity:
        return _proximity.extract(sample);
    }
  }

  void reset() {
    _mode = DepthMode.deciding;
    _framesSeen = 0;
    _elbowHits = 0;
    _proximity = ProximityDepthExtractor(
      calibrationSampleCount: _proximity.calibrationSampleCount,
      expansionRange: _proximity.expansionRange,
      minVisibility: _proximity.minVisibility,
    );
  }
}
