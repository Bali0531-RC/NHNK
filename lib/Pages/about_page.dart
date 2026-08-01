import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';

/// Legal copy lives here rather than in LanguagePack on purpose: downloaded
/// community language packs can override any LanguagePack string, and a
/// third party must not be able to rewrite the disclaimer or the licence.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const String websiteUrl = 'https://nhnk.bali0531.hu';
  static const String privacyUrl = 'https://nhnk.bali0531.hu/adatvedelem';
  static const String termsUrl = 'https://nhnk.bali0531.hu/felhasznalasi-feltetelek';
  static const String donateUrl = 'https://nhnk.bali0531.hu/tamogatas';
  static const String repoUrl = 'https://github.com/Bali0531-RC/NHNK';

  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _version = '${info.version} (${info.buildNumber})');
    });
  }

  bool get _hu => AppStrings.getCurrentLangCode() == 'hu';

  String _t(String hu, String en) => _hu ? hu : en;

  Future<void> _open(String url) async {
    AppHaptics.lightImpact();
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();

    return Scaffold(
      backgroundColor: theme.rootBackground,
      appBar: AppBar(
        backgroundColor: theme.rootBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textColor),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          AppStrings.getLanguagePack().topmenu_buttons_About,
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _header(theme),
          const SizedBox(height: 28),
          _disclaimer(theme),
          const SizedBox(height: 24),
          _sectionTitle(theme, _t('Készítők', 'Credits'), Icons.people_alt_rounded),
          _credit(theme, 'Bali0531 (Turi Balázs)', _t('NHNK — jelenlegi fejlesztő', 'NHNK — current developer')),
          _credit(theme, 'Kurucz Zoltán (zoligamer)', _t('Neptun Mobile — köztes fork', 'Neptun Mobile — intermediate fork')),
          _credit(theme, 'Dömötör Dávid (domedav)', _t('Neptun 2 — eredeti projekt', 'Neptun 2 — original project')),
          const SizedBox(height: 24),
          _sectionTitle(theme, _t('Licenc', 'Licence'), Icons.gavel_rounded),
          _body(
            theme,
            _t(
              'Az NHNK szabad szoftver, MIT licenc alatt. A forráskód nyilvános, '
                  'és a korábbi szerzők copyright-értesítései a licenc előírása szerint megmaradtak.',
              'NHNK is free software under the MIT licence. The source code is public, and the '
                  'copyright notices of the earlier authors are retained as the licence requires.',
            ),
          ),
          const SizedBox(height: 12),
          _licenceBox(theme),
          const SizedBox(height: 12),
          _linkTile(
            theme,
            Icons.description_outlined,
            _t('Harmadik féltől származó licencek', 'Third-party licences'),
            () {
              AppHaptics.lightImpact();
              showLicensePage(
                context: context,
                applicationName: 'NHNK',
                applicationVersion: _version,
                applicationLegalese: '© 2026 Bali0531 — MIT',
              );
            },
          ),
          const SizedBox(height: 24),
          _sectionTitle(theme, _t('Linkek', 'Links'), Icons.link_rounded),
          _linkTile(theme, Icons.public_rounded, _t('Weboldal', 'Website'), () => _open(websiteUrl)),
          _linkTile(theme, Icons.privacy_tip_outlined, _t('Adatvédelmi tájékoztató', 'Privacy policy'), () => _open(privacyUrl)),
          _linkTile(theme, Icons.article_outlined, _t('Felhasználási feltételek', 'Terms of service'), () => _open(termsUrl)),
          _linkTile(theme, Icons.code_rounded, _t('Forráskód (GitHub)', 'Source code (GitHub)'), () => _open(repoUrl)),
          _linkTile(theme, Icons.bug_report_outlined, _t('Hibabejelentés', 'Report a bug'), () => _open('$repoUrl/issues/new/choose')),
          _linkTile(theme, Icons.favorite_rounded, _t('Támogatás', 'Donate'), () => _open(donateUrl), tint: Colors.pinkAccent),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© 2026 Bali0531',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.4), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(AppPalette theme) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset('assets/nhnk_logo.png', width: 88, height: 88),
        ),
        const SizedBox(height: 14),
        Text(
          'NHNK',
          style: TextStyle(color: theme.textColor, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 1.5),
        ),
        const SizedBox(height: 4),
        Text(
          'Nem Hivatalos Neptun Kliens',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.textColor.withValues(alpha: 0.65), fontSize: 14, fontWeight: FontWeight.w500),
        ),
        if (_version.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.textColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'v$_version',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  Widget _disclaimer(AppPalette theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.errorRed.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.errorRed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('Fontos jogi tájékoztatás', 'Important legal notice'),
                  style: TextStyle(color: theme.errorRed, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _disclaimerPoint(
            theme,
            _t(
              'Az NHNK egy független, nem hivatalos alkalmazás. Nem áll kapcsolatban a Campus Codeworks Zrt.-vel '
                  '(korábban SDA Informatika Zrt., a Neptun rendszer fejlesztője), és egyetlen felsőoktatási '
                  'intézménnyel sem, illetve azok nem támogatják és nem hagyták jóvá.',
              'NHNK is an independent, unofficial application. It is not affiliated with, endorsed by, or approved by '
                  'Campus Codeworks Zrt. (formerly SDA Informatika Zrt., the developer of the Neptun system) or any '
                  'higher education institution.',
            ),
          ),
          _disclaimerPoint(
            theme,
            _t(
              'A „Neptun" név és védjegy a jogosultja tulajdona. Itt kizárólag leíró jelleggel szerepel, annak '
                  'jelzésére, hogy az alkalmazás mely rendszerrel működik együtt.',
              'The "Neptun" name and trademark are the property of their respective owner. They are used here purely '
                  'descriptively, to indicate which system this application interoperates with.',
            ),
          ),
          _disclaimerPoint(
            theme,
            _t(
              'A belépési adataid közvetlenül az általad választott intézmény Neptun-kiszolgálójára mennek, '
                  'titkosított kapcsolaton. Az NHNK nem üzemeltet saját szervert, és nem gyűjt felhasználói adatokat.',
              'Your login details are sent directly to the Neptun server of the institution you select, over an '
                  'encrypted connection. NHNK operates no server of its own and collects no user data.',
            ),
          ),
          _disclaimerPoint(
            theme,
            _t(
              'Hivatalos, kötelező érvényű adatnak minden esetben a webes Neptun felületén megjelenő információ '
                  'számít. Határidőkért, jegyekért és befizetésekért ne kizárólag erre az alkalmazásra támaszkodj.',
              'The information shown in the official Neptun web interface is always the authoritative source. Do not '
                  'rely solely on this application for deadlines, grades or payments.',
            ),
          ),
          _disclaimerPoint(
            theme,
            _t(
              'Az alkalmazás „AHOGY VAN" állapotban érhető el, mindenféle garancia nélkül, a MIT licencben '
                  'foglaltak szerint. A használatából eredő károkért a szerzők nem vállalnak felelősséget.',
              'The application is provided "AS IS", without warranty of any kind, as set out in the MIT licence. The '
                  'authors accept no liability for any damage arising from its use.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _disclaimerPoint(AppPalette theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: theme.errorRed.withValues(alpha: 0.7), shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.85), fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppPalette theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: theme.textColor.withValues(alpha: 0.6), size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _body(AppPalette theme, String text) {
    return Text(
      text,
      style: TextStyle(color: theme.textColor.withValues(alpha: 0.75), fontSize: 13, height: 1.45),
    );
  }

  Widget _credit(AppPalette theme, String name, String role) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_outline_rounded, color: theme.textColor.withValues(alpha: 0.45), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(role, style: TextStyle(color: theme.textColor.withValues(alpha: 0.55), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _licenceBox(AppPalette theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'MIT License\n\n'
            'Copyright (c) 2023 domedav (Dömötör Dávid) — Neptun 2\n'
            'Copyright (c) 2026 Kurucz Zoltán (zoligamer) — Neptun Mobile\n'
            'Copyright (c) 2026 Bali0531 (Turi Balázs) — NHNK',
        style: TextStyle(
          color: theme.textColor.withValues(alpha: 0.7),
          fontSize: 11.5,
          height: 1.5,
          fontFamily: Platform.isAndroid ? 'monospace' : null,
        ),
      ),
    );
  }

  Widget _linkTile(AppPalette theme, IconData icon, String label, VoidCallback onTap, {Color? tint}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: tint ?? theme.textColor.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: theme.textColor, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.textColor.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
