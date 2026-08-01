import 'package:flutter/material.dart';
import '../colors.dart';
import '../language.dart';

/// Compiled in rather than read from a language pack: packs are downloaded at runtime,
/// so a third party must not be able to rewrite what the demo disclaimer says.
String demoModeText(String hu, String en) =>
    AppStrings.getCurrentLangCode() == 'hu' ? hu : en;

/// Persistent strip shown while the sandboxed demo account is active.
class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: theme.primary.withValues(alpha: 0.16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined, size: 16, color: theme.textColor.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              demoModeText(
                'DEMÓ MÓD — kitalált mintaadatok, nincs Neptun-kapcsolat',
                'DEMO MODE — fictional sample data, no Neptun connection',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
