import 'package:nhnk/platform_support.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:nhnk/Pages/main_page.dart';
import 'package:open_filex/open_filex.dart';
import '../API/api_coms.dart';
import '../API/totp.dart';
import '../background_worker.dart';
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';
import '../local_file_actions.dart';
import '../power_settings.dart';
import '../storage.dart';
import '../Misc/emojirich_text.dart';
import '../Pages/startup_page.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// Section headers were hardcoded Hungarian, so they stayed Hungarian in every
  /// other language. Compiled in rather than taken from a downloadable pack.
  String _t(String hu, String en) => AppStrings.getCurrentLangCode() == 'hu' ? hu : en;

  late String _languageCurrSelect;
  late String _themesCurrSelect;
  late double _currentFontScale;
  bool _hasTotpSecret = false;
  bool _batteryExempt = true;
  bool _hasOemPowerScreen = false;

  @override
  void initState() {
    super.initState();

    // loading defaults
    _currentFontScale = DataCache.getFontScale();
    _themesCurrSelect = AppColors.getTheme().paletteName;
    _hasTotpSecret = DataCache.getTotpSecret()?.isNotEmpty ?? false;

    PowerSettings.isExempt().then((v){
      if(!mounted) return;
      setState(() => _batteryExempt = v);
    });

    PowerSettings.hasOemSettings().then((v){
      if(!mounted) return;
      setState(() => _hasOemPowerScreen = v);
    });

    final lIdx = DataCache.getUserSelectedLanguage()!;
    if (lIdx <= -1) {
      final langCodeIdx = AppStrings.getAllLangCodes().indexOf(AppPlatform.localeName.split('_')[0].toLowerCase());
      _languageCurrSelect = AppStrings.getLanguageNamesWithFlag()[langCodeIdx];
    } else {
      _languageCurrSelect = AppStrings.getLanguageNamesWithFlag()[lIdx];
    }
  }

  /// The background job serves both alert types, so it stays relevant while either is on.
  bool get _wantsAnyAlert =>
      (DataCache.getNeedGradeNotifications() ?? true) || (DataCache.getNeedMailNotifications() ?? true);

  int _backgroundIntervalIndex(){
    final idx = BackgroundWorker.intervalSteps.indexOf(DataCache.getBackgroundGradeCheckMinutes());
    return idx < 0 ? BackgroundWorker.intervalSteps.indexOf(60) : idx;
  }

  String _backgroundIntervalLabel(int minutes){
    final lang = AppStrings.getLanguagePack();
    if(minutes <= 0) return lang.settings_BackgroundCheckOff;
    if(minutes < 60) return AppStrings.getStringWithParams(lang.settings_BackgroundCheckMinutes, [minutes]);
    if(minutes == 60) return _t("óránként", "every hour");
    return AppStrings.getStringWithParams(lang.settings_BackgroundCheckHours, [minutes ~/ 60]);
  }

  Future<void> _exportCalendar() async{
    final lang = AppStrings.getLanguagePack();
    List<dynamic>? entries;
    try{
      entries = await CalendarRequest.fetchFullTimetable();
    }
    catch(_){ }

    final path = entries == null ? null : await IcsExportHelper.writeExport(entries);
    if(path == null){
      Fluttertoast.showToast(msg: lang.settings_ExportCalendarFailed);
      return;
    }

    Fluttertoast.showToast(msg: lang.settings_ExportCalendarDone);
    await OpenFilex.open(path);
  }

  void _showTotpSecretDialog() {
    final controller = TextEditingController();
    String? parsed;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final preview = parsed == null ? null : Totp.generate(parsed!);
          return AlertDialog(
            backgroundColor: AppColors.getTheme().rootBackground,
            title: Text(_t("2FA titkos kulcs", "Two-factor secret key"), style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    "Ez az a kulcs, amit a hitelesítő alkalmazás beállításakor kaptál a Neptuntól. Beillesztheted magát a kulcsot, vagy a teljes otpauth:// linket is.",
                    "This is the key Neptun gave you when you set up your authenticator app. Paste either the key itself or the full otpauth:// link.",
                  ),
                  style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.7), fontSize: 12),
                ),
                const SizedBox(height: 10),
                Text(
                  _t(
                    "Ha elmented, a kétlépcsős védelem ezen a készüléken gyakorlatilag egylépcsőssé válik.",
                    "Saving it makes two-factor protection effectively single-factor on this device.",
                  ),
                  style: TextStyle(color: AppColors.getTheme().errorRed.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: _t("pl. JBSWY3DPEHPK3PXP", "e.g. JBSWY3DPEHPK3PXP"),
                    hintStyle: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.3), fontSize: 12),
                    filled: true,
                    fillColor: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setDialogState(() => parsed = Totp.extractSecret(val)),
                ),
                const SizedBox(height: 10),
                // Showing the live code lets the user check it against their authenticator before saving.
                if (controller.text.trim().isNotEmpty)
                  Text(
                    preview == null
                        ? _t("Érvénytelen kulcs", "Invalid key")
                        : _t("Jelenlegi kód: $preview", "Current code: $preview"),
                    style: TextStyle(
                      color: preview == null ? AppColors.getTheme().errorRed : AppColors.getTheme().secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            actions: [
              if (_hasTotpSecret)
                TextButton(
                  onPressed: () async {
                    AppHaptics.lightImpact();
                    await DataCache.setTotpSecret(null);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    setState(() => _hasTotpSecret = false);
                  },
                  child: Text(_t("Törlés", "Delete"), style: TextStyle(color: AppColors.getTheme().errorRed)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_t("Mégse", "Cancel"), style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.7))),
              ),
              TextButton(
                onPressed: parsed == null
                    ? null
                    : () async {
                        AppHaptics.lightImpact();
                        await DataCache.setTotpSecret(parsed);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        setState(() => _hasTotpSecret = true);
                      },
                child: Text(
                  _t("Mentés", "Save"),
                  style: TextStyle(
                    color: parsed == null
                        ? AppColors.getTheme().textColor.withValues(alpha: 0.3)
                        : AppColors.getTheme().secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // header helpers
  Widget _buildSectionHeader(String title, IconData icon) {    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.getTheme().secondary, size: 20),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
                color: AppColors.getTheme().secondary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.2
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getTheme().rootBackground,
      appBar: AppBar(
        backgroundColor: AppColors.getTheme().rootBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.getTheme().textColor),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: EmojiRichText(
          text: AppStrings.getLanguagePack().topmenu_buttons_Settings,
          defaultStyle: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold, fontSize: 20),
          emojiStyle: TextStyle(color: AppColors.getTheme().textColor, fontSize: 20, fontFamily: "Noto Color Emoji"),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          // --- 1. appearance and language ---
          _buildSectionHeader(_t("Megjelenés és Nyelv", "Appearance and language"), Icons.palette_rounded),

          ListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption9_ThemeSwap, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Container(
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _themesCurrSelect,
                  dropdownColor: AppColors.getTheme().rootBackground,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.getTheme().textColor),
                  isExpanded: true,
                  style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600),
                  items: AppColors.getThemesOnline().map((String value) {
                    return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: AppColors.getThemePopupAccentByName(value), size: 16),
                            const SizedBox(width: 10),
                            Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
                          ],
                        )
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value == null) return;
                    AppHaptics.lightImpact();
                    DataCache.setPreferredAppTheme(value);
                    if(!AppColors.hasThemeDownloaded(value)){
                      // download logic from old popup
                      Future.delayed(Duration.zero, ()async{
                        final pack = await Coloring.getAllThemes();
                        await Coloring.getThemePackById(pack, value).then((val)async{
                          if(val != null){
                            AppColors.saveDownloadedPaletteData();
                            AppColors.setUserThemeByName(val.paletteName, context);
                            AppColors.refreshThemeIndexing();
                            setState(() { _themesCurrSelect = value; });
                          }
                        });
                      });
                    } else {
                      setState(() {
                        _themesCurrSelect = value;
                        AppColors.setUserTheme(context);
                        AppColors.refreshThemeIndexing();
                      });
                    }
                  },
                ),
              ),
            ),
          ),

          ListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption8_LangaugeSelection, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Container(
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _languageCurrSelect,
                  dropdownColor: AppColors.getTheme().rootBackground,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.getTheme().textColor),
                  isExpanded: true,
                  items: AppStrings.getLanguageNamesWithFlag().map((String value) {
                    return DropdownMenuItem<String>(
                        value: value,
                        child: EmojiRichText(
                          text: value,
                          defaultStyle: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600, fontSize: 14),
                          emojiStyle: TextStyle(color: AppColors.getTheme().textColor, fontSize: 18, fontFamily: "Noto Color Emoji"),
                        )
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value == null) return;
                    AppHaptics.lightImpact();
                    // language logic from old popup
                    final flagWeLookFor = value.split(' ')[0];
                    final languageIdx = AppStrings.getAllLangFlags().indexOf(flagWeLookFor);
                    DataCache.setUserSelectedLanguage(languageIdx <= -1 ? AppStrings.getAllLangFlags().length : languageIdx);

                    Navigator.popUntil(context, (route) => route.isFirst);
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const Splitter()));
                  },
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t("App betűméret skálázás", "App text size"), style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600, fontSize: 16)),
                Slider(
                  value: _currentFontScale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  label: "${(_currentFontScale * 100).toInt()}%",
                  activeColor: AppColors.getTheme().secondary,
                  inactiveColor: AppColors.getTheme().textColor.withValues(alpha: 0.1),
                  onChanged: (val) {
                    setState(() { _currentFontScale = val; });
                  },
                  onChangeEnd: (val) {
                    AppHaptics.lightImpact();
                    DataCache.setFontScale(val);
                    // ui update!
                    setState((){});
                  },
                ),
              ],
            ),
          ),

          // --- 2. notifications ---
          _buildSectionHeader(_t("Értesítések", "Notifications"), Icons.notifications_active_rounded),

          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption2_ExamNotifications, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedExamNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedExamNotifications(b ? 1 : 0);
              b ? HomePageState.setupExamNotifications() : HomePageState.cancelExamNotifications();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption3_ClassNotifications, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedClassNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedClassNotifications(b ? 1 : 0);
              b ? HomePageState.setupClassesNotifications() : HomePageState.cancelClassesNotifications();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption4_PaymentNotifications, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedPaymentsNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedPaymentsNotifications(b ? 1 : 0);
              b ? HomePageState.setupPaymentsNotifications() : HomePageState.cancelPaymentsNotifications();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption5_PeriodsNotifications, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedPeriodsNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedPeriodsNotifications(b ? 1 : 0);
              b ? HomePageState.setupPeriodsNotifications() : HomePageState.cancelPeriodsNotifications();
              setState(() {});
            },
          ),

          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().settings_GradeNotifications, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            subtitle: Text(AppStrings.getLanguagePack().settings_GradeNotificationsDescription, style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: .6), fontSize: 12)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedGradeNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedGradeNotifications(b ? 1 : 0);
              BackgroundWorker.sync();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().settings_MailNotifications, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            subtitle: Text(AppStrings.getLanguagePack().settings_MailNotificationsDescription, style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: .6), fontSize: 12)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedMailNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedMailNotifications(b ? 1 : 0);
              BackgroundWorker.sync();
              setState(() {});
            },
          ),
          if(BackgroundWorker.isSupported)
            ListTile(
              enabled: _wantsAnyAlert,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(AppStrings.getLanguagePack().settings_BackgroundGradeCheck, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600))),
                  Text(
                    _backgroundIntervalLabel(DataCache.getBackgroundGradeCheckMinutes()),
                    style: TextStyle(color: AppColors.getTheme().secondary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.getLanguagePack().settings_BackgroundGradeCheckDescription, style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: .6), fontSize: 12)),
                  Slider(
                    value: _backgroundIntervalIndex().toDouble(),
                    min: 0,
                    max: (BackgroundWorker.intervalSteps.length - 1).toDouble(),
                    divisions: BackgroundWorker.intervalSteps.length - 1,
                    activeColor: AppColors.getTheme().secondary,
                    label: _backgroundIntervalLabel(BackgroundWorker.intervalSteps[_backgroundIntervalIndex()]),
                    onChanged: !_wantsAnyAlert ? null : (v) {
                      setState(() {
                        DataCache.setBackgroundGradeCheckMinutes(BackgroundWorker.intervalSteps[v.round()]);
                      });
                    },
                    onChangeEnd: (_) {
                      AppHaptics.lightImpact();
                      BackgroundWorker.sync();
                    },
                  ),
                ],
              ),
            ),

          // Only worth showing when a background check is actually wanted.
          if(BackgroundWorker.isSupported && DataCache.getBackgroundGradeCheckMinutes() > 0 && _wantsAnyAlert)
            ListTile(
              title: Text(AppStrings.getLanguagePack().settings_BatteryOptimisation, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
              subtitle: Text(
                _batteryExempt
                    ? AppStrings.getLanguagePack().settings_BatteryOptimisationOff
                    : AppStrings.getLanguagePack().settings_BatteryOptimisationOn,
                style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: .6), fontSize: 12),
              ),
              trailing: Icon(
                _batteryExempt ? Icons.battery_full_rounded : Icons.battery_alert_rounded,
                color: _batteryExempt ? AppColors.getTheme().secondary : AppColors.getTheme().errorRed,
              ),
              onTap: _batteryExempt ? null : () async {
                AppHaptics.lightImpact();
                await PowerSettings.openSettings();
                // Re-read on return, the user may have changed it.
                final now = await PowerSettings.isExempt();
                if(!mounted) return;
                setState(() => _batteryExempt = now);
              },
            ),

          // Vendor list is separate from Android's; being exempt above does not cover it.
          if(BackgroundWorker.isSupported && _hasOemPowerScreen && DataCache.getBackgroundGradeCheckMinutes() > 0 && _wantsAnyAlert)
            ListTile(
              title: Text(AppStrings.getLanguagePack().settings_OemBackground, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
              subtitle: Text(
                AppStrings.getLanguagePack().settings_OemBackgroundDescription,
                style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: .6), fontSize: 12),
              ),
              trailing: Icon(Icons.open_in_new_rounded, color: AppColors.getTheme().textColor.withValues(alpha: .6)),
              onTap: () async {
                AppHaptics.lightImpact();
                await PowerSettings.openOemSettings();
              },
            ),

          // --- 3. operation and others ---
          _buildSectionHeader(_t("Működés és Egyéb", "Behaviour and other"), Icons.build_circle_rounded),

          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption1_FamilyFriendlyLoadingText, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedFamilyFriendlyComments()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedFamilyFriendlyComments(b ? 1 : 0);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption6_AppHaptics, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            activeThumbColor: AppColors.getTheme().secondary,
            value: DataCache.getNeedsHaptics()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedsHaptics(b ? 1 : 0);
              setState(() {});
            },
          ),

          ListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption7_WeekOffset, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Container(
              width: 120,
              decoration: BoxDecoration(color: AppColors.getTheme().textColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove, color: AppColors.getTheme().textColor, size: 18),
                    onPressed: () { AppHaptics.lightImpact(); HomePageState.settingsUserWeekOffsetAdd(-1); setState((){}); },
                  ),
                  Expanded(
                    child: Text(HomePageState.getUserWeekOffsetTextController().text.isEmpty ? "Auto" : HomePageState.getUserWeekOffsetTextController().text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: Icon(Icons.add, color: AppColors.getTheme().textColor, size: 18),
                    onPressed: () { AppHaptics.lightImpact(); HomePageState.settingsUserWeekOffsetAdd(1); setState((){}); },
                  ),
                ],
              ),
            ),
          ),

          ListTile(
            title: Text(AppStrings.getLanguagePack().settings_ExportCalendar, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            subtitle: Text(
              AppStrings.getLanguagePack().settings_ExportCalendarDescription,
              style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.5), fontSize: 12),
            ),
            trailing: Icon(Icons.event_available_rounded, color: AppColors.getTheme().textColor.withValues(alpha: 0.6)),
            onTap: () {
              AppHaptics.lightImpact();
              _exportCalendar();
            },
          ),

          // --- 4. security ---
          _buildSectionHeader(_t("Biztonság", "Security"), Icons.lock_rounded),
          ListTile(
            title: Text(_t("2FA titkos kulcs", "Two-factor secret key"), style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _hasTotpSecret
                  ? _t("Mentve - az app magától lép be, ha lejár a munkamenet",
                       "Saved - the app signs in by itself when the session expires")
                  : _t("Nincs mentve - újra belépéskor kézzel kell kódot megadni",
                       "Not saved - you will have to type a code when signing in again"),
              style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.5), fontSize: 12),
            ),
            trailing: Icon(
              _hasTotpSecret ? Icons.verified_user_rounded : Icons.key_off_rounded,
              color: _hasTotpSecret ? AppColors.getTheme().secondary : AppColors.getTheme().textColor.withValues(alpha: 0.4),
            ),
            onTap: () {
              AppHaptics.lightImpact();
              _showTotpSecretDialog();
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}