import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors.dart';
import '../language.dart';
import '../storage.dart';

/// Shown once, before the login flow. Compiled in rather than read from a language
/// pack: packs are downloaded at runtime and must not be able to reword a disclaimer.
String _t(String hu, String en) => AppStrings.getCurrentLangCode() == 'hu' ? hu : en;

class DisclosurePage extends StatelessWidget {
  final VoidCallback onAccepted;
  const DisclosurePage({super.key, required this.onAccepted});

  static const String privacyUrl = 'https://nhnk.bali0531.hu/adatvedelem';
  static const String termsUrl = 'https://nhnk.bali0531.hu/felhasznalasi-feltetelek';

  static Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _point(IconData icon, String title, String body) {
    final theme = AppColors.getTheme();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 3),
                Text(body, style: TextStyle(color: theme.textColor.withValues(alpha: 0.65), fontSize: 12.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    return Scaffold(
      backgroundColor: theme.rootBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Mielőtt belépsz', 'Before you sign in'),
                      style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w900, fontSize: 26),
                    ),
                    const SizedBox(height: 24),
                    _point(
                      Icons.info_outline_rounded,
                      _t('Ez nem a hivatalos Neptun app', 'This is not the official Neptun app'),
                      _t(
                        'Az NHNK független fejlesztés. Nem áll kapcsolatban a Campus Codeworks Zrt.-vel, sem az intézményeddel, és ők nem támogatják.',
                        'NHNK is an independent project. It is not affiliated with or endorsed by Campus Codeworks Zrt. or your institution.',
                      ),
                    ),
                    _point(
                      Icons.lock_outline_rounded,
                      _t('A belépési adataid a készülékeden maradnak', 'Your login stays on your device'),
                      _t(
                        'A felhasználóneved és jelszavad közvetlenül az intézményed Neptun-kiszolgálójára megy. Nincs saját szerverünk, ami látná őket.',
                        'Your username and password go straight to your institution\'s Neptun server. We run no server that could see them.',
                      ),
                    ),
                    _point(
                      Icons.visibility_off_outlined,
                      _t('Nem gyűjtünk rólad adatot', 'We collect nothing about you'),
                      _t(
                        'Nincs analitika, nincs hirdetés, nincs követés. Az adataid a telefonodon tárolódnak.',
                        'No analytics, no ads, no tracking. Your data is stored on your phone.',
                      ),
                    ),
                    _point(
                      Icons.gpp_maybe_outlined,
                      _t('Garancia nélkül', 'No warranty'),
                      _t(
                        'Az app "ahogy van" állapotban érhető el. Fontos határidőt vagy hivatalos ügyet mindig ellenőrizz a hivatalos Neptunban is.',
                        'The app is provided as is. Always double-check deadlines and official matters in Neptun itself.',
                      ),
                    ),
                    Wrap(
                      spacing: 18,
                      children: [
                        TextButton(
                          onPressed: () => _open(termsUrl),
                          child: Text(_t('Felhasználási feltételek', 'Terms of service'),
                              style: TextStyle(color: theme.secondary, fontSize: 12.5, decoration: TextDecoration.underline)),
                        ),
                        TextButton(
                          onPressed: () => _open(privacyUrl),
                          child: Text(_t('Adatvédelmi tájékoztató', 'Privacy policy'),
                              style: TextStyle(color: theme.secondary, fontSize: 12.5, decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: Column(
                children: [
                  Text(
                    _t(
                      'A folytatással elfogadod a felhasználási feltételeket és az adatvédelmi tájékoztatót.',
                      'By continuing you accept the terms of service and the privacy policy.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textColor.withValues(alpha: 0.55), fontSize: 11.5, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        await DataCache.setHasAcceptedTerms(1);
                        onAccepted();
                      },
                      child: Text(
                        _t('Megértettem, folytatom', 'I understand, continue'),
                        style: TextStyle(color: theme.onPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
