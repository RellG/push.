import 'package:flutter/widgets.dart';
import 'package:push_app/features/capture/pose_engine/pose_engine.dart';

/// Native platforms don't have a pose engine yet — camera counting ships
/// with the native-build milestone (ML Kit pose detection). The capture
/// screen checks [isSupported] and renders an explainer instead of a
/// preview, so [start] is never reached in practice.
class UnsupportedPoseEngine implements PoseEngine {
  @override
  bool get isSupported => false;

  @override
  Widget buildPreview() => const SizedBox.shrink();

  @override
  Future<void> start({
    required PoseSampleCallback onSample,
    required VoidCallback onReady,
    required PoseErrorCallback onError,
  }) async {
    onError('pose-engine-unsupported');
  }

  @override
  Future<void> stop() async {}
}

PoseEngine createPoseEngine() => UnsupportedPoseEngine();
