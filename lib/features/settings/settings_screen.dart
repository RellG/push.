import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/typography.dart';
import 'package:push_app/data/repositories/date_key.dart';
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
  var _isAuthBusy = false;

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
                  error: (error, stackTrace) =>
                      const Text('Unable to load — check your connection.'),
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
                  title: 'Profile',
                  child: _buildAccountSection(colors),
                ),
                const SizedBox(height: 24),
                _SettingsSection(
                  title: 'Data',
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _exportJson,
                    icon: const Icon(LucideIcons.share),
                    label: const Text('Export JSON'),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _seedDemoData,
                    icon: const Icon(LucideIcons.barChart3),
                    label: const Text('Seed demo data'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSection(PushColorTokens colors) {
    final authUser = ref.watch(authUserChangesProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final user = authUser.valueOrNull;
    if (user == null) {
      return Text(
        'Connecting…',
        style: TextStyle(color: colors.textMuted),
      );
    }

    final name = profile?.name ?? 'Unnamed';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final providerEmails =
        user.providerData.map((info) => info.email).whereType<String>();
    final email = user.email ??
        (providerEmails.isEmpty ? null : providerEmails.first);
    final subtitle = user.isAnonymous
        ? 'Anonymous account — this device only'
        : (email ?? 'Google account');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceAlt,
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: PushTypography.monoNumber(
                    color: colors.textPrimary,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: profile == null ? null : _editName,
                        iconSize: 16,
                        tooltip: 'Edit name',
                        icon: Icon(
                          LucideIcons.pencil,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (!user.isAnonymous) ...[
                        Icon(
                          LucideIcons.checkCircle2,
                          size: 14,
                          color: colors.accentMid,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (profile != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.calendar, size: 14, color: colors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Member since ',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
              Text(
                localDateKey(profile.createdAt),
                style: PushTypography.monoNumber(
                  color: colors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
        if (user.isAnonymous) ...[
          const SizedBox(height: 16),
          Text(
            'Link a Google account to keep your data if this device is '
            'lost, and to use Push. on other devices.',
            style: TextStyle(color: colors.textMuted),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isAuthBusy ? null : _linkGoogle,
            icon: const Icon(LucideIcons.link),
            label: const Text('Link Google account'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isAuthBusy ? null : _signInWithGoogle,
            icon: const Icon(LucideIcons.logIn),
            label: const Text('Sign in with Google (existing account)'),
          ),
        ],
      ],
    );
  }

  Future<void> _editName() async {
    final profile = ref.read(profileProvider).valueOrNull;
    final controller = TextEditingController(text: profile?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) {
      return;
    }

    final repository = await ref.read(profileRepositoryProvider.future);
    await repository.updateName(name);
    ref.invalidate(profileProvider);
  }

  Future<void> _linkGoogle() async {
    setState(() => _isAuthBusy = true);
    final result = await ref.read(linkGoogleAccountProvider)();
    if (!mounted) {
      return;
    }

    setState(() => _isAuthBusy = false);
    final message = switch (result) {
      GoogleAuthResult.success =>
        'Google account linked — your data now follows you across devices.',
      GoogleAuthResult.accountAlreadyLinked =>
        'That Google account already has Push. data. '
            'Use "Sign in with Google" instead.',
      GoogleAuthResult.failed => 'Could not link the Google account.',
      GoogleAuthResult.canceled => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch account?'),
        content: const Text(
          'Pushups logged on this device before signing in will not '
          'follow you to the Google account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isAuthBusy = true);
    final result = await ref.read(signInWithGoogleProvider)();
    if (!mounted) {
      return;
    }

    setState(() => _isAuthBusy = false);
    final message = switch (result) {
      GoogleAuthResult.success => 'Signed in with Google.',
      GoogleAuthResult.failed => 'Google sign-in failed.',
      _ => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
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
                style: PushTypography.monoCode(
                  color: context.colors.textPrimary,
                  fontSize: 12,
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
