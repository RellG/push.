import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:push_app/app/theme/motion.dart';
import 'package:push_app/app/theme/theme.dart';
import 'package:push_app/domain/models/pose_sample.dart';
import 'package:push_app/features/capture/capture_providers.dart';
import 'package:push_app/features/capture/capture_screen.dart';
import 'package:push_app/features/capture/pose_engine/pose_engine.dart';
import 'package:push_app/providers/app_providers.dart';

class FakePoseEngine implements PoseEngine {
  late PoseSampleCallback _onSample;
  late VoidCallback _onReady;
  late PoseErrorCallback _onError;
  int stopCount = 0;

  @override
  bool get isSupported => true;

  @override
  Widget buildPreview() => const ColoredBox(color: Color(0xFF000000));

  @override
  Future<void> start({
    required PoseSampleCallback onSample,
    required VoidCallback onReady,
    required PoseErrorCallback onError,
  }) async {
    _onSample = onSample;
    _onReady = onReady;
    _onError = onError;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  void ready() => _onReady();
  void emit(PoseSample sample) => _onSample(sample);
  void fail(String code) => _onError(code);
}

const _hidden = PosePoint(x: 0, y: 0, z: 0, visibility: 0);

/// A side-view frame with the left arm bent to [angleDegrees] at the elbow.
PoseSample _sideView(double angleDegrees, int ms) {
  PosePoint at(double x, double y) =>
      PosePoint(x: x, y: y, z: 0, visibility: 0.9);
  final radians = angleDegrees * math.pi / 180;

  return PoseSample(
    elapsed: Duration(milliseconds: ms),
    nose: _hidden,
    leftEye: _hidden,
    rightEye: _hidden,
    leftShoulder: at(0.5, 0.2),
    rightShoulder: _hidden,
    leftElbow: at(0.5, 0.5),
    rightElbow: _hidden,
    leftWrist: at(0.5 + 0.3 * math.sin(radians), 0.5 - 0.3 * math.cos(radians)),
    rightWrist: _hidden,
  );
}

void main() {
  late FakePoseEngine engine;
  late List<int> savedReps;
  late List<String?> savedNotes;
  var exited = false;

  Future<void> pumpScreen(WidgetTester tester) async {
    engine = FakePoseEngine();
    savedReps = [];
    savedNotes = [];
    exited = false;

    Future<void> fakeLogSet({required int reps, String? note}) async {
      savedReps.add(reps);
      savedNotes.add(note);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poseEngineProvider.overrideWithValue(engine),
          logSetProvider.overrideWithValue(fakeLogSet),
        ],
        child: MaterialApp(
          theme: PushTheme.dark(),
          home: CaptureScreen(onExit: () => exited = true),
        ),
      ),
    );
  }

  /// Feeds enough side-view frames to settle mode decision, then [reps]
  /// clean pushup cycles.
  void performReps(int reps) {
    var ms = 0;
    void run(Iterable<double> angles) {
      for (final angle in angles) {
        ms += 66;
        engine.emit(_sideView(angle, ms));
      }
    }

    run(List.filled(24, 170));
    for (var rep = 0; rep < reps; rep += 1) {
      run([150, 120, 95, 80, 80, 95, 120, 150, 170, 170]);
    }
  }

  testWidgets('shows the intro with privacy note before starting', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Count with the camera'), findsOneWidget);
    expect(find.text('Start camera'), findsOneWidget);
    expect(find.textContaining('No video is uploaded'), findsOneWidget);
  });

  testWidgets('counts reps from pose samples and saves on done', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Start camera'));
    await tester.pump();
    expect(find.text('Starting camera'), findsOneWidget);

    engine.ready();
    await tester.pump();
    expect(find.text('Hold the top of a pushup'), findsOneWidget);

    performReps(3);
    await tester.pump();
    await tester.pump(PushMotion.fast);

    expect(find.text('3'), findsOneWidget);
    expect(find.text('side view'), findsOneWidget);

    await tester.tap(find.textContaining('Done — save 3'));
    await tester.pump();
    await tester.pump();

    expect(savedReps, [3]);
    expect(savedNotes, ['Auto-counted']);
    expect(exited, isTrue);
    expect(engine.stopCount, greaterThan(0));
  });

  testWidgets('shows a friendly error and can retry', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Start camera'));
    await tester.pump();
    engine.fail('camera-permission-denied');
    await tester.pump();

    expect(find.text('Camera session failed'), findsOneWidget);
    expect(find.textContaining('Camera access was denied'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Starting camera'), findsOneWidget);
  });

  testWidgets('asks before discarding counted reps', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Start camera'));
    await tester.pump();
    engine.ready();
    await tester.pump();
    performReps(2);
    await tester.pump();
    await tester.pump(PushMotion.fast);

    // Close (X) with reps on the board → confirm dialog.
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.text('Discard this session?'), findsOneWidget);

    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(exited, isFalse);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(exited, isTrue);
    expect(savedReps, isEmpty);
  });
}
