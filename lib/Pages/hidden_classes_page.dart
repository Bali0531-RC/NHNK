import 'package:flutter/material.dart';

import '../API/api_coms.dart' as api;
import '../colors.dart';
import '../haptics.dart';
import '../hidden_classes.dart';
import '../language.dart';
import '../storage.dart' as storage;

/// Lists what the user hid and lets them bring it back.
class HiddenClassesPage extends StatefulWidget {
  const HiddenClassesPage({super.key});

  @override
  State<HiddenClassesPage> createState() => _HiddenClassesPageState();
}

class _HiddenClassesPageState extends State<HiddenClassesPage> {
  List<String> _hidden = [];
  List<String> _completedToHide = [];
  bool _loading = true;

  String _t(String hu, String en) => AppStrings.getCurrentLangCode() == 'hu' ? hu : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await HiddenClasses.load();
    final completed = <String>[];
    final len = await storage.getInt('CachedMarkbookLength') ?? 0;
    for (var i = 0; i < len; i++) {
      final raw = await storage.getString('CachedMarkbook_$i');
      if (raw == null) continue;
      final subject = api.Subject(false, 0, 'NULL', 0, 0, 0).fillWithExisting(raw);
      if (subject.name != 'ERROR' && subject.completed && !HiddenClasses.isTitleHidden(subject.name)) {
        completed.add(subject.name);
      }
    }
    if (!mounted) return;
    setState(() {
      _hidden = HiddenClasses.titles;
      _completedToHide = completed;
      _loading = false;
    });
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
          tooltip: _t('Vissza', 'Back'),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          _t('Elrejtett órák', 'Hidden classes'),
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: theme.secondary))
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  _t('Az elrejtett órák nem jelennek meg az órarendben és nem kapsz róluk emlékeztetőt. A vizsgák mindig látszanak.',
                      'Hidden classes disappear from the timetable and get no reminders. Exams always stay visible.'),
                  style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 13),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_t('Megjelenítés a widgeten', 'Show on the widget'),
                      style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      _t('Alapból az elrejtett órák a widgeten sem látszanak.',
                          'Hidden classes are left off the widget unless you turn this on.'),
                      style: TextStyle(color: AppColors.mutedText(0.5), fontSize: 12)),
                  activeThumbColor: theme.secondary,
                  value: HiddenClasses.showInWidget,
                  onChanged: (value) async {
                    AppHaptics.lightImpact();
                    await HiddenClasses.setShowInWidget(value);
                    if (mounted) setState(() {});
                  },
                ),
                if (_completedToHide.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _section(theme, _t('Teljesített tárgyak', 'Completed subjects')),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: theme.secondary),
                    icon: const Icon(Icons.visibility_off_rounded),
                    label: Text(_t('Óráik elrejtése (${_completedToHide.length})',
                        'Hide their classes (${_completedToHide.length})')),
                    onPressed: () async {
                      AppHaptics.lightImpact();
                      await HiddenClasses.hide(_completedToHide);
                      await _load();
                    },
                  ),
                ],
                const SizedBox(height: 22),
                _section(theme, _t('Elrejtve', 'Hidden')),
                const SizedBox(height: 8),
                if (_hidden.isEmpty)
                  Text(_t('Nincs elrejtett óra.', 'No hidden classes.'),
                      style: TextStyle(color: AppColors.mutedText(0.5), fontSize: 13))
                else
                  ..._hidden.map((title) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.only(left: 14),
                        decoration: BoxDecoration(
                          color: theme.textColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(title,
                                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                            ),
                            TextButton(
                              onPressed: () async {
                                AppHaptics.lightImpact();
                                await HiddenClasses.unhide(title);
                                await _load();
                              },
                              child: Text(_t('Visszaállítás', 'Unhide'), style: TextStyle(color: theme.secondary)),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
    );
  }

  Widget _section(AppPalette theme, String text) => Text(text,
      style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16));
}
