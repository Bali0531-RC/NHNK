import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../API/api_coms.dart' as api;
import '../../Misc/auto_updater.dart';
import '../../colors.dart';
import '../../haptics.dart';
import '../../language.dart';
import '../../storage.dart' as storage;
import '../main_page.dart' as main_page;
import '../setup_page.dart' as setup_page;
import 'institute_search.dart';
import 'onboarding_shell.dart';

/// Compiled in rather than read from a language pack: packs are downloaded at
/// runtime and must not be able to reword a disclaimer.
String _t(String hu, String en) => AppStrings.getCurrentLangCode() == 'hu' ? hu : en;

const int _kTotalSteps = 4;

void _applyOverlayStyle() {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: AppColors.getTheme().rootBackground,
    statusBarColor: AppColors.getTheme().rootBackground,
  ));
}

// ---------------------------------------------------------------- step 1, terms

class OnboardingTermsPage extends StatefulWidget {
  const OnboardingTermsPage({super.key});

  @override
  State<OnboardingTermsPage> createState() => _OnboardingTermsPageState();
}

class _OnboardingTermsPageState extends State<OnboardingTermsPage> {
  static const String privacyUrl = 'https://nhnk.bali0531.hu/adatvedelem';
  static const String termsUrl = 'https://nhnk.bali0531.hu/felhasznalasi-feltetelek';

  @override
  void initState() {
    super.initState();
    _applyOverlayStyle();
    // Without this the native splash stays on top of the first page forever and a
    // fresh install looks frozen.
    FlutterNativeSplash.remove();
    AppColors.clearThemeChangeCallbacks();
    AppColors.subThemeChangeCallback(() {
      if (mounted) setState(() {});
    });
  }

  static Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _legalLink(String label, String url) {
    final theme = AppColors.getTheme();
    return Semantics(
      button: true,
      link: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => _open(url),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: TextStyle(
                  color: theme.secondary,
                  fontSize: 12.5,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _point(IconData icon, String title, String body) {
    final theme = AppColors.getTheme();
    return Semantics(
      container: true,
      label: '$title, $body',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.secondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: theme.textColor, fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 4),
                    Text(body,
                        style: TextStyle(
                            color: AppColors.mutedText(0.68), fontSize: 13, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      step: 1,
      totalSteps: _kTotalSteps,
      showBack: false,
      title: _t('Mielőtt belépsz', 'Before you sign in'),
      subtitle: _t(
        'Egy percbe telik, és utána nem kérdezünk rá többet.',
        'This takes a minute, and you will not be asked again.',
      ),
      primaryLabel: _t('Megértettem, folytatom', 'I understand, continue'),
      onPrimary: () async {
        await storage.DataCache.setHasAcceptedTerms(1);
        if (!context.mounted) return;
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const OnboardingWelcomePage()));
      },
      secondary: Text(
        _t(
          'A folytatással elfogadod a felhasználási feltételeket és az adatvédelmi tájékoztatót.',
          'By continuing you accept the terms of service and the privacy policy.',
        ),
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.mutedText(0.55), fontSize: 11.5, height: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legalLink(_t('Felhasználási feltételek', 'Terms of service'), termsUrl),
              _legalLink(_t('Adatvédelmi tájékoztató', 'Privacy policy'), privacyUrl),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- step 2, welcome

class OnboardingWelcomePage extends StatefulWidget {
  const OnboardingWelcomePage({super.key});

  @override
  State<OnboardingWelcomePage> createState() => _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends State<OnboardingWelcomePage> {
  bool _hasAskedLang = false;

  @override
  void initState() {
    super.initState();
    _applyOverlayStyle();
    AppColors.subThemeChangeCallback(() {
      if (mounted) setState(() {});
    });

    // This step replaced the old login type screen, which was where these ran.
    if (!_hasAskedLang) {
      Future.delayed(const Duration(seconds: 1), () async {
        _hasAskedLang = true;
        if (!mounted) return;
        await LanguageManager.suggestLang(context, null, null);
      });
    }
    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      await AppUpdater.checkAndInstallUpdate(context);
    });
    Future.delayed(const Duration(seconds: 1), () async {
      await LanguageManager.refreshAllDownloadedLangs();
    });
  }

  Widget _feature(IconData icon, String title, String body) {
    final theme = AppColors.getTheme();
    return Semantics(
      container: true,
      label: '$title, $body',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.secondary.withValues(alpha: 0.14),
                  borderRadius: const BorderRadius.all(Radius.circular(AppRadius.medium)),
                ),
                child: Icon(icon, size: 20, color: theme.secondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: theme.textColor, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(body,
                        style: TextStyle(
                            color: AppColors.mutedText(0.68), fontSize: 13, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      step: 2,
      totalSteps: _kTotalSteps,
      title: _t('Üdv az NHNK-ban', 'Welcome to NHNK'),
      subtitle: _t(
        'A Neptun, ahogy egy telefonon működnie kellene.',
        'Neptun, the way it should work on a phone.',
      ),
      primaryLabel: _t('Kezdjük', 'Get started'),
      onPrimary: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const OnboardingConnectPage()));
      },
      secondary: OnboardingQuietButton(
        icon: Icons.play_circle_outline_rounded,
        label: _t('Előbb körülnéznék', 'Just let me look around first'),
        onTap: () => startDemoMode(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _feature(
            Icons.calendar_month_rounded,
            _t('Órarend és jegyek', 'Timetable and grades'),
            _t(
              'Az órarended, a jegyeid és az átlagod egy helyen, offline is.',
              'Your classes, your grades and your average in one place, offline too.',
            ),
          ),
          _feature(
            Icons.notifications_active_outlined,
            _t('Szólunk, ha jön egy jegy', 'We tell you when a grade arrives'),
            _t(
              'Háttérben figyeli az új jegyeket, üzeneteket és időszakokat.',
              'Checks for new grades, messages and periods in the background.',
            ),
          ),
          _feature(
            Icons.phonelink_lock_outlined,
            _t('Szerver nélkül', 'No server in the middle'),
            _t(
              'Nincs közvetítő szolgáltatás. Az app közvetlenül az intézményeddel beszél.',
              'There is no middleman service. The app talks to your institution directly.',
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- step 3, connect

class OnboardingConnectPage extends StatefulWidget {
  const OnboardingConnectPage({super.key});

  @override
  State<OnboardingConnectPage> createState() => _OnboardingConnectPageState();
}

class _OnboardingConnectPageState extends State<OnboardingConnectPage> {
  final TextEditingController _search = TextEditingController();
  List<api.Institute> _institutes = [];
  api.Institute? _selected;
  bool _loading = true;
  bool _failed = false;

  /// Rendering every institution at once makes the step scroll forever, and the
  /// search box is the point of the screen.
  static const int _maxRows = 60;

  @override
  void initState() {
    super.initState();
    _applyOverlayStyle();
    AppColors.subThemeChangeCallback(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // The login step prefills from these, so they have to be populated before it opens.
    setup_page.PageDTO.username = storage.DataCache.getUsername() ?? '';
    setup_page.PageDTO.password = await storage.DataCache.getPassword() ?? '';

    if (!mounted) return;
    if (setup_page.PageDTO.institutes != null && setup_page.PageDTO.institutes!.isNotEmpty) {
      setState(() {
        _institutes = setup_page.PageDTO.institutes!;
        _loading = false;
      });
      return;
    }
    final json = await api.InstitutesRequest.fetchInstitutesJSON();
    if (!mounted) return;
    if (json == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    final data = api.InstitutesRequest.getDataFromInstitutesJSON(json);
    setup_page.PageDTO.institutes = data;
    setState(() {
      _institutes = data;
      _loading = false;
    });
  }

  List<api.Institute> get _matches {
    final q = _search.text;
    return _institutes.where((i) => instituteMatches(i.Name, q)).toList();
  }

  void _continue() {
    if (_selected == null) return;
    setup_page.PageDTO.validatedURL = false;
    setup_page.PageDTO.selected = _selected!.Name;
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const setup_page.SetupPageLogin()));
  }

  Widget _row(api.Institute institute) {
    final theme = AppColors.getTheme();
    final chosen = identical(institute, _selected);
    return Semantics(
      button: true,
      selected: chosen,
      label: institute.Name,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () {
            AppHaptics.lightImpact();
            FocusScope.of(context).unfocus();
            setState(() => _selected = institute);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: chosen
                  ? theme.secondary.withValues(alpha: 0.12)
                  : theme.textColor.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.all(Radius.circular(AppRadius.medium)),
              border: Border.all(
                color: chosen
                    ? theme.secondary.withValues(alpha: 0.6)
                    : theme.textColor.withValues(alpha: 0.10),
                width: chosen ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    institute.Name,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 14,
                      fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (chosen) Icon(Icons.check_circle_rounded, size: 20, color: theme.secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    final theme = AppColors.getTheme();
    final pack = AppStrings.getLanguagePack();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.medium)),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: AppColors.mutedText(0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: theme.textColor, fontSize: 15),
              cursorColor: theme.secondary,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                hintText: pack.instituteSelection_setupPage_Search,
                hintStyle: TextStyle(color: AppColors.mutedText(0.55), fontSize: 15),
              ),
            ),
          ),
          if (_search.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _search.clear();
                setState(() {});
              },
              child: Icon(Icons.close_rounded, size: 18, color: AppColors.mutedText(0.6)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pack = AppStrings.getLanguagePack();
    final matches = _matches;
    final shown = matches.take(_maxRows).toList();

    return OnboardingShell(
      step: 3,
      totalSteps: _kTotalSteps,
      centerContent: false,
      title: _t('Keresd meg az intézményed', 'Find your institution'),
      subtitle: _t(
        'Ez köti össze az appot a saját Neptunoddal.',
        'This is what connects the app to your own Neptun.',
      ),
      primaryLabel: _t('Tovább', 'Continue'),
      onPrimary: _selected == null ? null : _continue,
      secondary: OnboardingQuietButton(
        icon: Icons.link_rounded,
        label: pack.instituteSelection_setupPage_InstituteCantFindHelpText,
        onTap: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const setup_page.SetupPageURLInput()));
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchField(),
          const SizedBox(height: 16),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(pack.instituteSelection_setupPage_LoadingText,
                  style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 14)),
            )
          else if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(pack.instituteSelection_setupPage_NoNetwork,
                  style: TextStyle(color: AppColors.mutedText(0.7), fontSize: 14)),
            )
          else if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(pack.instituteSelection_setupPage_SearchNotFound,
                  style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 14)),
            )
          else ...[
            ...shown.map(_row),
            if (matches.length > shown.length)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _t('Még ${matches.length - shown.length} találat. Írj be többet a szűkítéshez.',
                      '${matches.length - shown.length} more. Keep typing to narrow it down.'),
                  style: TextStyle(color: AppColors.mutedText(0.55), fontSize: 12.5),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Demo mode is reachable from two steps, so the credential setup lives in one place.
Future<void> startDemoMode(BuildContext context) async {
  AppHaptics.lightImpact();
  await api.InstitutesRequest.validateLoginCredentialsUrl('', 'DEMO', 'DEMO');
  await storage.DataCache.setUsername('DEMO');
  await storage.DataCache.setPassword('DEMO');
  await storage.DataCache.setInstituteUrl('');
  await storage.DataCache.setHasLogin(1);
  if (!context.mounted) return;
  Navigator.popUntil(context, (route) => route.willHandlePopInternally);
  Navigator.push(
      context, MaterialPageRoute(builder: (context) => const main_page.HomePage()));
}
