import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../haptics.dart';
import '../language.dart';

String _t(String hu, String en) => AppStrings.getCurrentLangCode() == 'hu' ? hu : en;

/// Works out the average still needed over the remaining credits to reach a target.
/// Weighted the same way the markbook page computes the displayed average.
double? requiredAverage({
  required double currentAverage,
  required int currentCredits,
  required double target,
  required int remainingCredits,
}) {
  if (remainingCredits <= 0) return null;
  // With no usable average there is nothing earned yet, so past credits must not
  // count against the target -- otherwise they read as credits scored at zero.
  final hasAverage = !currentAverage.isNaN && currentAverage > 0 && currentCredits > 0;
  final priorCredits = hasAverage ? currentCredits : 0;
  final earned = hasAverage ? currentAverage * currentCredits : 0;
  return (target * (priorCredits + remainingCredits) - earned) / remainingCredits;
}

Future<void> showAverageCalculator(BuildContext context, double currentAverage, int currentCredits) {
  final targetController = TextEditingController(text: '4.00');
  final creditsController = TextEditingController(text: '30');

  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final theme = AppColors.getTheme();
        final target = double.tryParse(targetController.text.replaceAll(',', '.'));
        final remaining = int.tryParse(creditsController.text);
        final needed = (target == null || remaining == null)
            ? null
            : requiredAverage(
                currentAverage: currentAverage,
                currentCredits: currentCredits,
                target: target,
                remainingCredits: remaining,
              );

        String verdict;
        Color verdictColor;
        if (needed == null) {
          verdict = _t('Adj meg egy célátlagot és a hátralévő krediteket.', 'Enter a target average and remaining credits.');
          verdictColor = theme.textColor.withValues(alpha: 0.6);
        } else if (needed > 5) {
          verdict = _t('Ez már nem érhető el ennyi kreditből.', 'Not reachable with that many credits.');
          verdictColor = theme.errorRed;
        } else if (needed <= 1) {
          verdict = _t('Ez már megvan, bármit is kapsz.', 'Already secured, whatever you get.');
          verdictColor = theme.secondary;
        } else {
          verdict = _t(
            'A hátralévő kreditekre ${needed.toStringAsFixed(2)} átlag kell.',
            'You need a ${needed.toStringAsFixed(2)} average on the remaining credits.',
          );
          verdictColor = theme.secondary;
        }

        Widget field(String label, TextEditingController controller, bool decimal) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
                    style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: theme.textColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.small), borderSide: BorderSide.none),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            );

        return AlertDialog(
          backgroundColor: theme.rootBackground,
          title: Text(_t('Átlagszámító', 'Average calculator'),
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  'Jelenleg ${currentAverage.isNaN || currentAverage <= 0 ? "-" : currentAverage.toStringAsFixed(2)} az átlagod $currentCredits kreditből.',
                  'You are at ${currentAverage.isNaN || currentAverage <= 0 ? "-" : currentAverage.toStringAsFixed(2)} across $currentCredits credits.',
                ),
                style: TextStyle(color: theme.textColor.withValues(alpha: 0.7), fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  field(_t('Célátlag', 'Target'), targetController, true),
                  const SizedBox(width: 12),
                  field(_t('Hátralévő kredit', 'Credits left'), creditsController, false),
                ],
              ),
              const SizedBox(height: 18),
              Text(verdict, style: TextStyle(color: verdictColor, fontWeight: FontWeight.w700, fontSize: 13, height: 1.3)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppHaptics.lightImpact();
                Navigator.pop(ctx);
              },
              child: Text(_t('Bezár', 'Close'), style: TextStyle(color: theme.secondary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );
}
