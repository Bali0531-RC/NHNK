import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../haptics.dart';
import '../../language.dart';

/// The visual language for first run only. The rest of the app keeps its own look,
/// so nothing here reaches for the shared page widgets on purpose.
class OnboardingShell extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Widget? secondary;
  final bool showBack;

  /// Search style steps set this false, otherwise the heading slides up and down
  /// as results appear and disappear under it.
  final bool centerContent;

  const OnboardingShell({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.subtitle,
    this.secondary,
    this.showBack = true,
    this.centerContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final canGoBack = showBack && Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: theme.rootBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  if (canGoBack)
                    _CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.of(context).pop();
                      },
                    )
                  else
                    const SizedBox(width: 40, height: 40),
                  const SizedBox(width: 14),
                  Expanded(child: OnboardingStepBar(step: step, total: totalSteps)),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                    child: ConstrainedBox(
                      // Steps carry very different amounts of text. Short ones centre
                      // instead of leaving the screen empty below them; long ones
                      // outgrow this and scroll from the top as usual.
                      constraints: BoxConstraints(
                          minHeight: centerContent ? constraints.maxHeight - 44 : 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: AppColors.mutedText(0.7),
                                fontSize: 14.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 26),
                          child,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
              child: Column(
                children: [
                  if (secondary != null) ...[
                    secondary!,
                    const SizedBox(height: 12),
                  ],
                  OnboardingPrimaryButton(label: primaryLabel, onTap: onPrimary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const OnboardingPrimaryButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: enabled
              ? () {
                  AppHaptics.lightImpact();
                  onTap!();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 54,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled ? theme.buttonEnabled : theme.buttonDisabled,
              borderRadius: const BorderRadius.all(Radius.circular(AppRadius.medium)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? theme.onPrimary : AppColors.mutedText(0.6),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A flat text action for the option that is not the expected one.
class OnboardingQuietButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const OnboardingQuietButton({super.key, required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () {
            AppHaptics.lightImpact();
            onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: theme.secondary),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.secondary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable option card. Used for the things a first run actually has to choose.
class OnboardingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool highlighted;

  const OnboardingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    return Semantics(
      button: true,
      label: '$title, $body',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () {
            AppHaptics.lightImpact();
            onTap();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: highlighted
                  ? theme.secondary.withValues(alpha: 0.10)
                  : theme.textColor.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.all(Radius.circular(AppRadius.large)),
              border: Border.all(
                color: highlighted
                    ? theme.secondary.withValues(alpha: 0.55)
                    : theme.textColor.withValues(alpha: 0.14),
                width: highlighted ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.secondary.withValues(alpha: 0.14),
                    borderRadius: const BorderRadius.all(Radius.circular(AppRadius.medium)),
                  ),
                  child: Icon(icon, size: 22, color: theme.secondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          color: AppColors.mutedText(0.68),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingStepBar extends StatelessWidget {
  final int step;
  final int total;
  const OnboardingStepBar({super.key, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    return Semantics(
      label: AppStrings.getCurrentLangCode() == 'hu'
          ? '$step. lépés, összesen $total'
          : 'Step $step of $total',
      child: ExcludeSemantics(
        child: Row(
          children: List.generate(total, (i) {
            final done = i < step;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  height: 4,
                  decoration: BoxDecoration(
                    color: done ? theme.secondary : theme.textColor.withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: theme.textColor),
      ),
    );
  }
}
