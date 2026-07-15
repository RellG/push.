import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:push_app/domain/models/pose_sample.dart';
import 'package:push_app/domain/services/depth_estimator.dart';
import 'package:push_app/domain/services/rep_counter.dart';

const _hidden = PosePoint(x: 0, y: 0, z: 0, visibility: 0);

PoseSample _sample({
  int ms = 0,
  PosePoint nose = _hidden,
  PosePoint leftEye = _hidden,
  PosePoint rightEye = _hidden,
  PosePoint leftShoulder = _hidden,
  PosePoint rightShoulder = _hidden,
  PosePoint leftElbow = _hidden,
  PosePoint rightElbow = _hidden,
  PosePoint leftWrist = _hidden,
  PosePoint rightWrist = _hidden,
}) {
  return PoseSample(
    elapsed: Duration(milliseconds: ms),
    nose: nose,
    leftEye: leftEye,
    rightEye: rightEye,
    leftShoulder: leftShoulder,
    rightShoulder: rightShoulder,
    leftElbow: leftElbow,
    rightElbow: rightElbow,
    leftWrist: leftWrist,
    rightWrist: rightWrist,
  );
}

PosePoint _at(double x, double y, {double visibility = 0.9}) {
  return PosePoint(x: x, y: y, z: 0, visibility: visibility);
}

/// A side-view frame with the left arm bent to [angleDegrees] at the elbow.
PoseSample _sideView(double angleDegrees, {int ms = 0}) {
  const elbowX = 0.5;
  const elbowY = 0.5;
  // Shoulder straight above the elbow; the wrist ray is rotated
  // [angleDegrees] away from the elbow→shoulder ray.
  final radians = angleDegrees * math.pi / 180;
  final wristX = elbowX + 0.3 * math.sin(radians);
  final wristY = elbowY - 0.3 * math.cos(radians);

  return _sample(
    ms: ms,
    leftShoulder: _at(elbowX, elbowY - 0.3),
    leftElbow: _at(elbowX, elbowY),
    leftWrist: _at(wristX, wristY),
  );
}

/// A floor-facing frame showing only the eyes, [width] apart.
PoseSample _floorView(double width, {int ms = 0}) {
  return _sample(
    ms: ms,
    leftEye: _at(0.5 - width / 2, 0.4),
    rightEye: _at(0.5 + width / 2, 0.4),
  );
}

void main() {
  group('PoseSample.fromFlat', () {
    test('parses the wire format and applies aspect correction', () {
      final flat = List<double>.filled(PoseSample.flatLength, 0)
        ..[0] = 1250 // elapsed ms
        ..[1] = 1.5; // aspect ratio
      // Landmark 3 (leftShoulder) at x=0.4, y=0.6, z=0.1, visibility=0.8.
      const base = 2 + 3 * 4;
      flat[base] = 0.4;
      flat[base + 1] = 0.6;
      flat[base + 2] = 0.1;
      flat[base + 3] = 0.8;

      final sample = PoseSample.fromFlat(flat);

      expect(sample, isNotNull);
      expect(sample!.elapsed, const Duration(milliseconds: 1250));
      expect(sample.leftShoulder.x, closeTo(0.4 * 1.5, 1e-9));
      expect(sample.leftShoulder.y, closeTo(0.6, 1e-9));
      expect(sample.leftShoulder.visibility, closeTo(0.8, 1e-9));
    });

    test('rejects a truncated frame instead of throwing', () {
      expect(PoseSample.fromFlat(List<double>.filled(10, 0)), isNull);
    });
  });

  group('ElbowAngleDepthExtractor', () {
    const extractor = ElbowAngleDepthExtractor();

    test('reads a straight arm as the top of the rep', () {
      final reading = extractor.extract(_sideView(175));

      expect(reading, isNotNull);
      expect(reading!.depth, 0);
    });

    test('reads a folded arm as the bottom of the rep', () {
      final reading = extractor.extract(_sideView(80));

      expect(reading!.depth, 1);
    });

    test('maps intermediate angles proportionally', () {
      // Halfway between up (160°) and down (85°) is 122.5°.
      final reading = extractor.extract(_sideView(122.5));

      expect(reading!.depth, closeTo(0.5, 0.01));
    });

    test('returns null when the arm chain is not visible', () {
      expect(extractor.extract(_floorView(0.2)), isNull);
    });

    test('uses the more visible arm', () {
      // Left arm barely visible and straight; right arm clearly visible
      // and folded — the folded (right) reading must win.
      final sample = _sample(
        leftShoulder: _at(0.5, 0.2, visibility: 0.3),
        leftElbow: _at(0.5, 0.5, visibility: 0.3),
        leftWrist: _at(0.5, 0.8, visibility: 0.3),
        rightShoulder: _at(0.7, 0.2),
        rightElbow: _at(0.7, 0.5),
        rightWrist: _at(0.95, 0.4),
      );

      final reading = const ElbowAngleDepthExtractor().extract(sample);

      expect(reading!.depth, greaterThan(0.5));
    });
  });

  group('ProximityDepthExtractor', () {
    test('calibrates a baseline then reads growth as depth', () {
      final extractor = ProximityDepthExtractor();

      for (var i = 0; i < extractor.calibrationSampleCount; i += 1) {
        expect(extractor.extract(_floorView(0.2)), isNull);
        expect(
          extractor.isCalibrating,
          i < extractor.calibrationSampleCount - 1,
        );
      }

      // Baseline width: depth 0 at the top.
      expect(extractor.extract(_floorView(0.2))!.depth, 0);
      // 35% growth (the full expansionRange) reads as the bottom.
      expect(extractor.extract(_floorView(0.27))!.depth, 1);
      // Halfway growth reads as mid-rep.
      expect(
        extractor.extract(_floorView(0.235))!.depth,
        closeTo(0.5, 0.01),
      );
    });

    test('heals the baseline when a smaller width appears later', () {
      final extractor = ProximityDepthExtractor();
      for (var i = 0; i < extractor.calibrationSampleCount; i += 1) {
        extractor.extract(_floorView(0.24)); // calibrated slightly mid-rep
      }

      // Repeatedly seeing the true top eases the baseline down to it.
      for (var i = 0; i < 30; i += 1) {
        extractor.extract(_floorView(0.2));
      }

      // The old calibration width now reads as real depth, not zero.
      expect(extractor.extract(_floorView(0.24))!.depth, greaterThan(0.3));
    });

    test('locks the measurement source for the whole session', () {
      // First contact via eyes locks the source to eyes…
      final extractor = ProximityDepthExtractor()
        ..extract(_floorView(0.2));

      // …so a shoulders-only frame is unusable rather than mixing scales.
      final shouldersOnly = _sample(
        leftShoulder: _at(0.3, 0.5),
        rightShoulder: _at(0.7, 0.5),
      );
      expect(extractor.extract(shouldersOnly), isNull);
      expect(extractor.hasSignalSource(shouldersOnly), isFalse);
    });
  });

  group('DepthEstimator', () {
    test('locks onto elbow-angle mode for a side view', () {
      final estimator = DepthEstimator();

      for (var i = 0; i < estimator.decisionWindow; i += 1) {
        expect(estimator.process(_sideView(170, ms: i * 33)), isNull);
      }

      expect(estimator.mode, DepthMode.elbowAngle);
      expect(estimator.process(_sideView(85))!.depth, 1);
    });

    test('locks onto proximity mode for a floor-facing view', () {
      final estimator = DepthEstimator();

      for (var i = 0; i < estimator.decisionWindow; i += 1) {
        estimator.process(_floorView(0.2, ms: i * 33));
      }

      expect(estimator.mode, DepthMode.proximity);
      // The proximity baseline warmed up during the decision window, so
      // depth readings are available immediately after the lock.
      expect(estimator.process(_floorView(0.27))!.depth, 1);
    });

    test('reset returns to deciding with fresh calibration', () {
      final estimator = DepthEstimator();
      for (var i = 0; i < estimator.decisionWindow; i += 1) {
        estimator.process(_sideView(170));
      }
      expect(estimator.mode, DepthMode.elbowAngle);

      estimator.reset();

      expect(estimator.mode, DepthMode.deciding);
      expect(estimator.process(_sideView(85)), isNull);
    });

    test('drives RepCounter end to end from side-view frames', () {
      final estimator = DepthEstimator();
      final counter = RepCounter();

      var ms = 0;
      void run(Iterable<double> angles) {
        for (final angle in angles) {
          ms += 66;
          final reading = estimator.process(_sideView(angle, ms: ms));
          if (reading != null) {
            counter.addSample(
              depth: reading.depth,
              confidence: reading.confidence,
              elapsed: Duration(milliseconds: ms),
            );
          }
        }
      }

      // Settle the mode decision at the top position…
      run(List.filled(24, 170));
      // …then three clean reps: down to 80° and back up to 170°.
      for (var rep = 0; rep < 3; rep += 1) {
        run([150, 120, 95, 80, 80, 95, 120, 150, 170, 170]);
      }

      expect(estimator.mode, DepthMode.elbowAngle);
      expect(counter.repCount, 3);
    });
  });
}
