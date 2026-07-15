// Capture-session providers live with the feature rather than in
// app_providers.dart: the pose engine is platform-conditional and only
// exists while the capture screen is open (autoDispose releases the camera
// the moment the user leaves).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:push_app/features/capture/capture_session_controller.dart';
import 'package:push_app/features/capture/pose_engine/pose_engine.dart';

final AutoDisposeProvider<PoseEngine> poseEngineProvider =
    Provider.autoDispose<PoseEngine>((ref) {
  final engine = createPoseEngine();
  ref.onDispose(() => unawaited(engine.stop()));
  return engine;
});

final AutoDisposeStateNotifierProvider<CaptureSessionController,
        CaptureSessionState> captureSessionProvider =
    StateNotifierProvider.autoDispose<CaptureSessionController,
        CaptureSessionState>((ref) {
  return CaptureSessionController(ref.watch(poseEngineProvider));
});
