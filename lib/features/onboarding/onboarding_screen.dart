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
}
