/// Where the body currently is within a rep, as seen by [RepCounter].
enum RepPhase { up, down }

/// Tuning knobs for [RepCounter]. Depth is a normalized 0..1 signal where 0
/// is the top of a pushup and 1 is the bottom; the two thresholds are
/// deliberately far apart (hysteresis) so noise around a single threshold
/// can never oscillate the phase.
class RepCounterConfig {
  const RepCounterConfig({
    this.downThreshold = 0.7,
    this.upThreshold = 0.35,
    this.minConfidence = 0.5,
    this.smoothingAlpha = 0.5,
    this.minRepInterval = const Duration(milliseconds: 500),
  })  : assert(
          downThreshold > upThreshold,
          'Hysteresis requires downThreshold > upThreshold',
        ),
        assert(
          smoothingAlpha > 0 && smoothingAlpha <= 1,
          'smoothingAlpha must be in (0, 1]',
        );

  /// Smoothed depth the body must exceed to register the bottom of a rep.
  final double downThreshold;

  /// Smoothed depth the body must return below to complete a rep.
  final double upThreshold;

  /// Samples with a lower landmark confidence are ignored entirely.
  final double minConfidence;

  /// Exponential-moving-average weight of the newest sample.
  final double smoothingAlpha;

  /// Minimum time between two counted reps. A "rep" completing faster than
  /// this is treated as tracking jitter and not counted.
  final Duration minRepInterval;
}

/// Counts pushup reps from a stream of normalized depth samples.
///
/// Pure and platform-free: callers feed `(depth, confidence, elapsed)` in
/// session-relative time and read [repCount] / [phase] back. A rep is one
/// full up → down → up cycle through the hysteresis thresholds.
class RepCounter {
  RepCounter({this.config = const RepCounterConfig()});

  final RepCounterConfig config;

  int _repCount = 0;
  RepPhase _phase = RepPhase.up;
  double? _smoothedDepth;
  Duration? _lastRepAt;

  int get repCount => _repCount;
  RepPhase get phase => _phase;

  /// The current exponentially smoothed depth, or null before the first
  /// confident sample. Exposed for HUD/debug readouts.
  double? get smoothedDepth => _smoothedDepth;

  /// Feeds one sample. Returns true when this sample completed a rep.
  bool addSample({
    required double depth,
    required double confidence,
    required Duration elapsed,
  }) {
    if (confidence < config.minConfidence) {
      return false;
    }

    final clamped = depth.clamp(0.0, 1.0);
    final previous = _smoothedDepth;
    final smoothed = previous == null
        ? clamped
        : config.smoothingAlpha * clamped +
            (1 - config.smoothingAlpha) * previous;
    _smoothedDepth = smoothed;

    switch (_phase) {
      case RepPhase.up:
        if (smoothed >= config.downThreshold) {
          _phase = RepPhase.down;
        }
      case RepPhase.down:
        if (smoothed <= config.upThreshold) {
          _phase = RepPhase.up;
          final last = _lastRepAt;
          if (last == null || elapsed - last >= config.minRepInterval) {
            _repCount += 1;
            _lastRepAt = elapsed;
            return true;
          }
        }
    }

    return false;
  }

  void reset() {
    _repCount = 0;
    _phase = RepPhase.up;
    _smoothedDepth = null;
    _lastRepAt = null;
  }
}
