import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/motion.dart';
import 'package:push_app/app/theme/typography.dart';

class QuickAddRow extends StatefulWidget {
  const QuickAddRow({
    required this.onAdd,
    super.key,
  });

  final Future<void> Function(int reps) onAdd;

  @override
  State<QuickAddRow> createState() => _QuickAddRowState();
}

class _QuickAddRowState extends State<QuickAddRow> {
  final _customController = TextEditingController();
  int? _activeReps;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final reps in const [5, 10, 20]) ...[
              Expanded(
                child: _QuickAddButton(
                  reps: reps,
                  isActive: _activeReps == reps,
                  onPressed: () => _add(reps),
                ),
              ),
              if (reps != 20) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: PushTypography.monoNumber(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: 'Custom reps',
                ),
                onSubmitted: (_) => _addCustom(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addCustom,
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _add(int reps) async {
    setState(() => _activeReps = reps);
    unawaited(HapticFeedback.lightImpact());
    await widget.onAdd(reps);
    await Future<void>.delayed(PushMotion.fast);
    if (mounted) {
      setState(() => _activeReps = null);
    }
  }

  Future<void> _addCustom() async {
    final reps = int.tryParse(_customController.text);
    if (reps == null || reps <= 0) {
      return;
    }

    _customController.clear();
    await _add(reps);
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({
    required this.reps,
    required this.isActive,
    required this.onPressed,
  });

  final int reps;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isActive ? PushMotion.pressedScale : 1,
      duration: PushMotion.fast,
      curve: PushMotion.defaultCurve,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text('+$reps'),
      ),
    );
  }
}
