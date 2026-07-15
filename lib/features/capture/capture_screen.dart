import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/motion.dart';
import 'package:push_app/app/theme/typography.dart';
import 'package:push_app/domain/services/depth_estimator.dart';
import 'package:push_app/domain/services/rep_counter.dart';
import 'package:push_app/features/capture/capture_providers.dart';
import 'package:push_app/features/capture/capture_session_controller.dart';
import 'package:push_app/providers/app_providers.dart';

/// Camera auto-count: MediaPipe pose landmarks feed the RepCounter state
/// machine, and the finished session saves one set through the normal
/// logSet path. Web-only for now; native shows an explainer until the
/// ML Kit engine ships with the store builds.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, this.onExit});

  /// Called instead of `context.pop()` when the screen wants to close —
  /// injectable for widget tests, mirroring OnboardingScreen.onCompleted.
  final VoidCallback? onExit;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(captureSessionProvider);
    final engine = ref.watch(poseEngineProvider);

    if (!engine.isSupported) {
      return _MessageScaffold(
        icon: LucideIcons.smartphone,
        title: 'Not on this platform yet',
        detail: 'Camera counting arrives with the native app. '
            'Until then it lives in the web app.',
        actions: [
          OutlinedButton(onPressed: _exit, child: const Text('Back')),
        ],
      );
    }

    return switch (session.status) {
      CaptureStatus.idle => _IntroView(onStart: _start, onBack: _exit),
      CaptureStatus.error => _ErrorView(
          code: session.errorCode,
          onRetry: _start,
          onClose: _exit,
        ),
      _ => _ActiveView(
          session: session,
          preview: engine.buildPreview(),
          saving: _saving,
          onClose: _closeActiveSession,
          onDone: _finish,
        ),
    };
  }

  void _exit() {
    final onExit = widget.onExit;
    if (onExit != null) {
      onExit();
    } else {
      context.pop();
    }
  }

  void _start() {
    unawaited(ref.read(captureSessionProvider.notifier).start());
  }

  Future<void> _closeActiveSession() async {
    final session = ref.read(captureSessionProvider);
    if (session.status == CaptureStatus.tracking && session.repCount > 0) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this session?'),
          content: Text(
            '${session.repCount} counted '
            'rep${session.repCount == 1 ? '' : 's'} will not be saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep going'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) {
        return;
      }
    }

    await ref.read(captureSessionProvider.notifier).stopEngine();
    if (mounted) {
      _exit();
    }
  }

  Future<void> _finish() async {
    if (_saving) {
      return;
    }
    final reps = ref.read(captureSessionProvider).repCount;
    await ref.read(captureSessionProvider.notifier).stopEngine();
    if (!mounted) {
      return;
    }
    if (reps <= 0) {
      _exit();
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(logSetProvider)(reps: reps, note: 'Auto-counted');
    } on Exception {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't save the set — check your connection."),
          ),
        );
      }
      return;
    }
    if (mounted) {
      _exit();
    }
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({required this.onStart, required this.onBack});

  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(LucideIcons.arrowLeft, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Text('Auto-count', style: textTheme.headlineMedium),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Count with the camera',
                    style: textTheme.displaySmall,
                  ),
                  const SizedBox(height: 24),
                  const _IntroPoint(
                    icon: LucideIcons.video,
                    text: 'Prop your device up for a side view, or lay it '
                        'flat on the floor under your face.',
                  ),
                  const _IntroPoint(
                    icon: LucideIcons.crosshair,
                    text: 'Hold the top of a pushup for a moment so it can '
                        'calibrate — then just go.',
                  ),
                  const _IntroPoint(
                    icon: LucideIcons.shieldCheck,
                    text: 'Counting runs entirely on this device. '
                        'No video is uploaded, ever.',
                  ),
                  const Spacer(),
                  Text(
                    'The first start downloads a small model (~6 MB).',
                    style: textTheme.labelMedium
                        ?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onStart,
                      icon: const Icon(LucideIcons.camera, size: 16),
                      label: const Text('Start camera'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPoint extends StatelessWidget {
  const _IntroPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ActiveView extends StatelessWidget {
  const _ActiveView({
    required this.session,
    required this.preview,
    required this.saving,
    required this.onClose,
    required this.onDone,
  });

  final CaptureSessionState session;
  final Widget preview;
  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    // The HUD sits on a dimmed camera feed, so it always uses the dark
    // token set for legibility, regardless of app theme.
    final colors = PushColorTokens.dark();

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: preview),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _HudIconButton(
                        colors: colors,
                        icon: LucideIcons.x,
                        onPressed: onClose,
                      ),
                      const Spacer(),
                      _ModeChip(colors: colors, session: session),
                    ],
                  ),
                  const Spacer(),
                  ..._centerContent(colors),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: _bottomContent(colors),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _centerContent(PushColorTokens colors) {
    switch (session.status) {
      case CaptureStatus.initializing:
        return [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 16),
          Text(
            'Starting camera',
            style: PushTypography.monoCode(
              color: colors.textMuted,
              fontSize: 14,
            ),
          ),
        ];
      case CaptureStatus.calibrating:
        return [
          Text(
            'Hold the top of a pushup',
            style: PushTypography.monoCode(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Counting starts automatically',
            style: PushTypography.monoCode(
              color: colors.textMuted,
              fontSize: 12,
            ),
          ),
        ];
      case CaptureStatus.tracking:
        return [
          AnimatedSwitcher(
            duration: PushMotion.fast,
            switchInCurve: PushMotion.defaultCurve,
            switchOutCurve: PushMotion.defaultCurve,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.12, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              '${session.repCount}',
              key: ValueKey(session.repCount),
              style: PushTypography.monoNumber(
                color: colors.textPrimary,
                fontSize: 96,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _PhasePill(colors: colors, phase: session.phase),
        ];
      case CaptureStatus.idle:
      case CaptureStatus.error:
        return const [];
    }
  }

  Widget _bottomContent(PushColorTokens colors) {
    if (session.status != CaptureStatus.tracking) {
      return const SizedBox(height: 48);
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: saving ? null : onDone,
        icon: saving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(LucideIcons.check, size: 16),
        label: Text(
          session.repCount > 0
              ? 'Done — save ${session.repCount}'
              : 'Done',
        ),
      ),
    );
  }
}

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.colors,
    required this.icon,
    required this.onPressed,
  });

  final PushColorTokens colors;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.5),
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: colors.textPrimary),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.colors, required this.session});

  final PushColorTokens colors;
  final CaptureSessionState session;

  @override
  Widget build(BuildContext context) {
    if (session.status != CaptureStatus.calibrating &&
        session.status != CaptureStatus.tracking) {
      return const SizedBox.shrink();
    }

    final label = switch (session.mode) {
      DepthMode.deciding => 'detecting…',
      DepthMode.elbowAngle => 'side view',
      DepthMode.proximity => 'facing camera',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.5),
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: PushTypography.monoCode(
          color: colors.textMuted,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.colors, required this.phase});

  final PushColorTokens colors;
  final RepPhase phase;

  @override
  Widget build(BuildContext context) {
    final isDown = phase == RepPhase.down;

    return AnimatedContainer(
      duration: PushMotion.fast,
      curve: PushMotion.defaultCurve,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDown ? colors.textPrimary : Colors.transparent,
        border: Border.all(
          color: isDown ? colors.textPrimary : colors.border,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isDown ? 'DOWN' : 'UP',
        style: PushTypography.monoCode(
          color: isDown ? colors.background : colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.code,
    required this.onRetry,
    required this.onClose,
  });

  final String? code;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _MessageScaffold(
      icon: LucideIcons.videoOff,
      title: 'Camera session failed',
      detail: _describe(code),
      actions: [
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(LucideIcons.refreshCw, size: 16),
          label: const Text('Try again'),
        ),
        const SizedBox(width: 12),
        OutlinedButton(onPressed: onClose, child: const Text('Close')),
      ],
    );
  }

  String _describe(String? code) {
    return switch (code) {
      'camera-permission-denied' =>
        'Camera access was denied. Allow the camera for this site in your '
            'browser settings, then try again.',
      'camera-not-found' => 'No camera was found on this device.',
      'camera-unsupported' =>
        "This browser can't access the camera. Try a current version of "
            'Chrome or Safari.',
      'pose-engine-script-missing' || 'pose-engine-view-missing' =>
        'The capture engine failed to load. Refresh the app and try again.',
      _ => 'Something went wrong starting the session'
          '${code == null ? '.' : ' ($code).'}',
    };
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({
    required this.icon,
    required this.title,
    required this.detail,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String detail;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 32, color: colors.textMuted),
                  const SizedBox(height: 16),
                  Text(title, style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: actions,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
