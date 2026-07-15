import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:push_app/domain/models/pose_sample.dart';
import 'package:push_app/domain/services/depth_estimator.dart';
import 'package:push_app/domain/services/rep_counter.dart';
import 'package:push_app/features/capture/pose_engine/pose_engine.dart';

enum CaptureStatus {
  /// Explainer shown; camera not yet requested.
  idle,

  /// Camera permission requested, model downloading/warming.
  initializing,

  /// Camera live, but the depth estimator is still picking its mode /
  /// calibrating — the user should hold the top of a pushup.
  calibrating,

  /// Counting reps.
  tracking,

  /// Session dead; [CaptureSessionState.errorCode] says why.
  error,
}

class CaptureSessionState {
  const CaptureSessionState({
    required this.status,
    this.repCount = 0,
    this.phase = RepPhase.up,
    this.mode = DepthMode.deciding,
    this.errorCode,
  });

  final CaptureStatus status;
  final int repCount;
  final RepPhase phase;
  final DepthMode mode;
  final String? errorCode;

  CaptureSessionState copyWith({
    CaptureStatus? status,
    int? repCount,
    RepPhase? phase,
    DepthMode? mode,
    String? errorCode,
  }) {
    return CaptureSessionState(
      status: status ?? this.status,
      repCount: repCount ?? this.repCount,
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      errorCode: errorCode ?? this.errorCode,
    );
  }
}

/// Drives one camera capture session: engine lifecycle, depth estimation,
/// and rep counting. Persisting the result stays with the caller (the
/// screen saves through `logSetProvider`), keeping the
/// widgets → providers → repositories boundary intact.
class CaptureSessionController extends StateNotifier<CaptureSessionState> {
  CaptureSessionController(this._engine)
      : super(const CaptureSessionState(status: CaptureStatus.idle));

  final PoseEngine _engine;
  final _estimator = DepthEstimator();
  final _counter = RepCounter();

  Future<void> start() async {
    if (state.status == CaptureStatus.initializing ||
        state.status == CaptureStatus.calibrating ||
        state.status == CaptureStatus.tracking) {
      return;
    }

    _estimator.reset();
    _counter.reset();
    state = const CaptureSessionState(status: CaptureStatus.initializing);

    await _engine.start(
      onSample: _handleSample,
      onReady: () {
        if (mounted && state.status == CaptureStatus.initializing) {
          state = state.copyWith(status: CaptureStatus.calibrating);
        }
      },
      onError: (code) {
        if (mounted) {
          state = CaptureSessionState(
            status: CaptureStatus.error,
            errorCode: code,
          );
        }
        unawaited(_engine.stop());
      },
    );
  }

  void _handleSample(PoseSample sample) {
    if (!mounted ||
        (state.status != CaptureStatus.calibrating &&
            state.status != CaptureStatus.tracking)) {
      return;
    }

    final reading = _estimator.process(sample);
    if (reading == null) {
      // Still deciding/calibrating — or the body briefly left the frame
      // mid-session, which just pauses counting.
      if (state.mode != _estimator.mode) {
        state = state.copyWith(mode: _estimator.mode);
      }
      return;
    }

    _counter.addSample(
      depth: reading.depth,
      confidence: reading.confidence,
      elapsed: sample.elapsed,
    );
    state = state.copyWith(
      status: CaptureStatus.tracking,
      repCount: _counter.repCount,
      phase: _counter.phase,
      mode: _estimator.mode,
    );
  }

  Future<void> stopEngine() => _engine.stop();

  @override
  void dispose() {
    unawaited(_engine.stop());
    super.dispose();
  }
}
