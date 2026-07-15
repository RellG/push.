import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:push_app/app/router.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/typography.dart';
import 'package:push_app/providers/app_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    this.onCompleted,
  });

  final VoidCallback? onCompleted;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _goalController = TextEditingController(text: '100');

  String _themeMode = 'dark';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 32),
                  Text('Push.', style: textTheme.displaySmall),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(LucideIcons.user),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _goalController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: PushTypography.monoNumber(
                      color: colors.textPrimary,
                      fontSize: 18,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Daily goal',
                      prefixIcon: Icon(LucideIcons.target),
                    ),
                    validator: (value) {
                      final goal = int.tryParse(value ?? '');
                      if (goal == null || goal <= 0) {
                        return 'Enter a goal above zero';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'dark',
                        label: Text('Dark'),
                        icon: Icon(LucideIcons.moon),
                      ),
                      ButtonSegment(
                        value: 'light',
                        label: Text('Light'),
                        icon: Icon(LucideIcons.sun),
                      ),
                      ButtonSegment(
                        value: 'system',
                        label: Text('System'),
                        icon: Icon(LucideIcons.monitor),
                      ),
                    ],
                    selected: {_themeMode},
                    onSelectionChanged: (selection) {
                      setState(() => _themeMode = selection.single);
                      ref
                          .read(onboardingThemePreviewProvider.notifier)
                          .state = _themeMode;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.arrowRight),
                    label: const Text('Continue'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: colors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: TextStyle(color: colors.textMuted),
                        ),
                      ),
                      Expanded(child: Divider(color: colors.border)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _signInWithGoogle,
                    icon: const Icon(LucideIcons.logIn),
                    label: const Text('Sign in with Google'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Already used Push. before? Sign in to pick up your '
                    'streak where you left off.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final completeOnboarding = ref.read(completeOnboardingProvider);
    await completeOnboarding(
      name: _nameController.text.trim(),
      currentGoal: int.parse(_goalController.text),
      themeMode: _themeMode,
    );

    if (!mounted) {
      return;
    }

    widget.onCompleted?.call();
    if (widget.onCompleted == null) {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isSubmitting = true);
    final result = await ref.read(signInWithGoogleProvider)();
    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);
    switch (result) {
      case GoogleAuthResult.success:
        final hasProfile =
            await ref.read(onboardingCompleteProvider.future);
        if (!mounted) {
          return;
        }
        if (hasProfile) {
          // Returning user — straight to their data.
          widget.onCompleted?.call();
          if (widget.onCompleted == null) {
            context.go(AppRoutes.home);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed in — finish setup to continue.'),
            ),
          );
        }
      case GoogleAuthResult.canceled:
        break;
      case GoogleAuthResult.failed:
      case GoogleAuthResult.accountAlreadyLinked:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in failed. Try again.')),
        );
    }
  }
}
