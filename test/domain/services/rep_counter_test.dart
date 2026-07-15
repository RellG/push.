import 'package:flutter_test/flutter_test.dart';
import 'package:push_app/domain/services/rep_counter.dart';

void main() {
  // Alpha 1 disables smoothing so phase transitions map directly to the fed
  // depths; smoothing behavior gets its own tests below.
  RepCounter rawCounter() => RepCounter(
        config: const RepCounterConfig(smoothingAlpha: 1),
      );

  bool feed(RepCounter counter, double depth, int ms, {double confidence = 1}) {
    return counter.addSample(
      depth: depth,
      confidence: confidence,
      elapsed: Duration(milliseconds: ms),
    );
  }

  group('RepCounter', () {
    test('counts one rep per full up-down-up cycle', () {
      final counter = rawCounter();

      feed(counter, 0, 0);
      expect(counter.phase, RepPhase.up);

      feed(counter, 0.9, 600);
      expect(counter.phase, RepPhase.down);
      expect(counter.repCount, 0);

      final counted = feed(counter, 0.1, 1200);
      expect(counted, isTrue);
      expect(counter.phase, RepPhase.up);
      expect(counter.repCount, 1);
    });

    test('counts consecutive reps', () {
      final counter = rawCounter();
      var time = 0;
      for (var rep = 0; rep < 5; rep += 1) {
        feed(counter, 0.9, time += 600);
        feed(counter, 0.1, time += 600);
      }

      expect(counter.repCount, 5);
    });

    test('ignores a half rep that never reaches the bottom', () {
      final counter = rawCounter();
      feed(counter, 0, 0);
      feed(counter, 0.5, 600); // below downThreshold — not deep enough
      feed(counter, 0.1, 1200);

      expect(counter.repCount, 0);
      expect(counter.phase, RepPhase.up);
    });

    test('hovering between thresholds cannot oscillate the phase', () {
      final counter = rawCounter();
      feed(counter, 0.9, 0);
      expect(counter.phase, RepPhase.down);

      // Noise in the hysteresis band: stays down, counts nothing.
      feed(counter, 0.5, 100);
      feed(counter, 0.69, 200);
      feed(counter, 0.4, 300);
      expect(counter.phase, RepPhase.down);
      expect(counter.repCount, 0);
    });

    test('drops samples below the confidence floor', () {
      final counter = rawCounter();
      feed(counter, 0.9, 0, confidence: 0.2);
      feed(counter, 0.1, 600, confidence: 0.2);

      expect(counter.phase, RepPhase.up);
      expect(counter.repCount, 0);
      expect(counter.smoothedDepth, isNull);
    });

    test('suppresses a cycle faster than minRepInterval', () {
      final counter = rawCounter();
      feed(counter, 0.9, 0);
      feed(counter, 0.1, 600); // rep 1 at 600ms
      feed(counter, 0.9, 700);
      final tooFast = feed(counter, 0.1, 800); // 200ms later — jitter

      expect(tooFast, isFalse);
      expect(counter.repCount, 1);

      // A later, plausible cycle counts again.
      feed(counter, 0.9, 1400);
      expect(feed(counter, 0.1, 2000), isTrue);
      expect(counter.repCount, 2);
    });

    test('smoothing absorbs a single-frame depth spike', () {
      final counter = RepCounter(
        config: const RepCounterConfig(smoothingAlpha: 0.4),
      );
      feed(counter, 0, 0);
      feed(counter, 1, 33); // one glitched frame: EMA reaches only 0.4

      expect(counter.phase, RepPhase.up);
    });

    test('reset returns to a clean slate', () {
      final counter = rawCounter();
      feed(counter, 0.9, 0);
      feed(counter, 0.1, 600);
      expect(counter.repCount, 1);

      counter.reset();

      expect(counter.repCount, 0);
      expect(counter.phase, RepPhase.up);
      expect(counter.smoothedDepth, isNull);

      // Debounce state is also cleared: an immediate rep counts.
      feed(counter, 0.9, 650);
      expect(feed(counter, 0.1, 700), isTrue);
    });
  });
}
