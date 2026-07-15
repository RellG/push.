import 'package:flutter/widgets.dart';
import 'package:push_app/domain/models/pose_sample.dart';
import 'package:push_app/features/capture/pose_engine/pose_engine_unsupported.dart'
    if (dart.library.js_interop) 'package:push_app/features/capture/pose_engine/pose_engine_web.dart'
    as impl;

typedef PoseSampleCallback = void Function(PoseSample sample);
typedef PoseErrorCallback = void Function(String code);

/// Platform-agnostic contract for the camera + pose-detection pipeline.
///
/// On the web this is backed by MediaPipe running entirely in JS (see
/// `web/motion/pose_capture.js`); on native it is a stub until the native
/// ML Kit implementation lands with the store builds. The engine owns the
/// camera preview and emits one [PoseSample] per analyzed frame — video
/// frames themselves never cross into Dart.
abstract interface class PoseEngine {
  /// Whether this platform can run camera capture at all.
  bool get isSupported;

  /// The live camera preview (with the skeleton overlay drawn by the
  /// engine). Must be in the tree before [start] can complete.
  Widget buildPreview();

  /// Opens the camera and starts streaming samples. [onReady] fires once
  /// the camera and model are live; [onError] reports a failure code
  /// ('camera-permission-denied', 'camera-not-found', …) and means the
  /// session is dead.
  Future<void> start({
    required PoseSampleCallback onSample,
    required VoidCallback onReady,
    required PoseErrorCallback onError,
  });

  /// Stops the camera and releases the model. Safe to call repeatedly.
  Future<void> stop();
}

/// Creates the pose engine for the current platform.
PoseEngine createPoseEngine() => impl.createPoseEngine();
