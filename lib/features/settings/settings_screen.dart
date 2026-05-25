import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/typography.dart';
import 'package:push_app/providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _goalController = TextEditingController();
  String _themeMode = 'dark';
  var _isSavingGoal = false;
  var _isExporting = false;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final colors = context.colors;

    ref.listen(profileProvider, (previous, next) {
      final value = next.valueOrNull;
      if (value == null) {
        return;
      }
      if (_goalController.text.isEmpty) {
        _goalController.text = value.currentGoal.toString();
      }
      if (_themeMode != value.themeMode) {
        setState(() => _themeMode = value.themeMode);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                profile.when(
                  data: (value) {
                    if (value != null && _goalController.text.isEmpty) {
                      _goalController.text = value.currentGoal.toString();
                      _themeMode = value.themeMode;
                    }
                    return _SettingsSection(
                      title: 'Goal',
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _goalController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: PushTypography.monoNumber(
                                color: colors.textPrimary,
                                fontSize: 18,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Daily goal',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isSavingGoal ? null : _saveGoal,
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                  },
                  error: (error, stackTrace) => Text(error.toString()),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
                const SizedBox(height: 24),
                _SettingsSection(
                  title: 'Theme',
                  child: SegmentedButton<String>(
                    selected: {_themeMode},
                    onSelectionChanged: (selection) {
                      unawaited(_saveTheme(selection.single));
                    },
                    segments: const [
                      ButtonSegment(value: 'dark', label: Text('Dark')),
                      ButtonSegment(value: 'light', label: Text('Light')),
                      ButtonSegment(value: 'system', label: Text('System')),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SettingsSection(
                  title: 'Data',
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _exportJson,
                    icon: const Icon(Icons.ios_share_outlined),
                    label: const Text('Export JSON'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _seedDemoData,
                  icon: const Icon(Icons.auto_graph_outlined),
                  label: const Text('Seed demo data'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveGoal() async {
    final goal = int.tryParse(_goalController.text);
    if (goal == null || goal <= 0) {
      return;
    }

    setState(() => _isSavingGoal = true);
    final repository = await ref.read(profileRepositoryProvider.future);
    await repository.updateGoal(goal);
    ref.invalidate(profileProvider);
    if (mounted) {
      setState(() => _isSavingGoal = false);
    }
  }

  Future<void> _saveTheme(String themeMode) async {
    setState(() => _themeMode = themeMode);
    final repository = await ref.read(profileRepositoryProvider.future);
    await repository.updateThemeMode(themeMode);
    ref.invalidate(profileProvider);
  }

  Future<void> _exportJson() async {
    setState(() => _isExporting = true);
    final exportJson = await ref.read(exportJsonProvider)();
    await Clipboard.setData(ClipboardData(text: exportJson));
    if (!mounted) {
      return;
    }

    setState(() => _isExporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export copied')),
    );
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export JSON'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                exportJson,
                style: PushTypography.monoNumber(
                  color: context.colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _seedDemoData() async {
    await ref.read(seedDemoDataProvider)();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo data seeded')),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
