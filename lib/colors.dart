import 'dart:async';
import 'dart:convert' as conv;
import 'package:flutter/material.dart';
import 'package:nhnk/API/api_coms.dart';
import 'package:nhnk/storage.dart';
import 'package:provider/provider.dart';
import 'Pages/startup_page.dart';
import 'main.dart';

/// One radius scale, because the UI had grown fifteen different corner values and
/// cards sitting next to each other did not match.
class AppRadius{
  static const double small = 8;
  static const double medium = 12;
  static const double large = 20;
  static const double xlarge = 30;
  static const double pill = 90;
}

class AppColors{
  static bool _hasInit = false;
  static List<AppPalette> _appColors = [];
  static List<AppPalette> _downloadedAppColors = [];
  static int _themeBatchSelectedIdx = 0;

  static List<VoidCallback> _onThemeChangeCallbacks = [];
  static void clearThemeChangeCallbacks(){_onThemeChangeCallbacks.clear();}
  static void subThemeChangeCallback(VoidCallback callback){_onThemeChangeCallbacks.add(callback);}

  static bool _isDark = false;

  static bool isDarktheme(){
    if(_themeBatchSelectedIdx == -1){
      return _isDark;
    }
    return getAllThemes()[_themeBatchSelectedIdx].basedOnDark;
  }

  /// Light and Dark track the system brightness. Anything else was chosen on
  /// purpose, so a day/night flip must not quietly replace it.
  static bool followsSystemBrightness(String? themeName) =>
      themeName == null || themeName == 'Dark' || themeName == 'Light';

  /// Dimmed body text, clamped to stay legible.
  ///
  /// Measured against each theme background, white text stops meeting WCAG AA below
  /// alpha 0.5 and black text below 0.6, so anything fainter is raised to the floor.
  static Color mutedText(double alpha){
    final theme = getTheme();
    final floor = theme.basedOnDark ? 0.5 : 0.6;
    return theme.textColor.withValues(alpha: alpha < floor ? floor : alpha);
  }

  static void initialize() {
    if (_hasInit) {
      return;
    }
    _appColors.add(AppPalette('Light',
        primary: Color.fromRGBO(0x6C, 0x8F, 0x96, 1.0),
        onPrimary: Color.fromRGBO(0x00, 0x00, 0x00, 1.0),
        // Contrast measured against rootBackground. secondary was 1.43:1 as link and
        // label text, which is barely visible; these all sit at 4.5:1 or better now.
        onPrimaryContainer: Color.fromRGBO(0x44, 0x6B, 0x74, 1.0),
        secondary: Color.fromRGBO(0x46, 0x6B, 0x71, 1.0),
        onSecondary: Color.fromRGBO(0x1B, 0x1B, 0x1B, 1.0),
        onSecondaryContainer: Color.fromRGBO(0x6C, 0x8F, 0x96, 1.0),
        grade1: Color.fromRGBO(0xBD, 0x2E, 0x2E, 1.0),
        grade2: Color.fromRGBO(0x95, 0x51, 0x51, 1.0),
        grade3: Color.fromRGBO(0x6B, 0x66, 0x39, 1.0),
        grade4: Color.fromRGBO(0x59, 0x6A, 0x46, 1.0),
        grade5: Color.fromRGBO(0x4C, 0x6C, 0x4D, 1.0),
        navbarStatusBarColor: Color.fromRGBO(0xF0, 0xF0, 0xF0, 1.0),
        navbarNavibarColor: Color.fromRGBO(0xE0, 0xE0, 0xE0, 1.0),
        rootBackground: Color.fromRGBO(0xE2, 0xE2, 0xE2, 1.0),
        textColor: Color.fromRGBO(0x00, 0x00, 0x00, 1.0),
        buttonEnabled: Color.fromRGBO(0xA7, 0xC4, 0xC8, 1.0),
        buttonDisabled: Color.fromRGBO(0xD3, 0xDD, 0xDD, 1.0),
        errorRed: Color.fromRGBO(0xCD, 0x00, 0x00, 1.0),
        currentClassGreen: Color.fromRGBO(0x35, 0x72, 0x26, 1.0),
        basedOnDark: false
    ));

    _appColors.add(AppPalette('Dark',
        primary: Color.fromRGBO(0x6C, 0x8F, 0x96, 1.0),
        onPrimary: Color.fromRGBO(0xFF, 0xFF, 0xFF, 1.0),
        onPrimaryContainer: Color.fromRGBO(0x8A, 0xB6, 0xBF, 1.0),
        // Was 2.71:1 against rootBackground, and it is used for link and label text.
        secondary: Color.fromRGBO(0x6C, 0x8E, 0x95, 1.0),
        onSecondary: Color.fromRGBO(0xB6, 0xB6, 0xB6, 1.0),
        onSecondaryContainer: Color.fromRGBO(0x6C, 0x8F, 0x96, 1.0),
        grade1: Color.fromRGBO(0xFF, 0x52, 0x52, 1.0),
        grade2: Color.fromRGBO(0xEF, 0x9A, 0x9A, 1.0),
        grade3: Color.fromRGBO(0xFF, 0xF5, 0x9D, 1.0),
        grade4: Color.fromRGBO(0xC5, 0xE1, 0xA5, 1.0),
        grade5: Color.fromRGBO(0xA5, 0xD6, 0xA7, 1.0),
        navbarStatusBarColor: Color.fromRGBO(0x0C, 0x0C, 0x0C, 1.0),
        navbarNavibarColor: Color.fromRGBO(0x1A, 0x1A, 0x1A, 1.0),
        rootBackground: Color.fromRGBO(0x22, 0x22, 0x22, 1.0),
        textColor: Color.fromRGBO(0xFF, 0xFF, 0xFF, 1.0),
        buttonEnabled: Color.fromRGBO(0x31, 0x42, 0x42, 1.0),
        buttonDisabled: Color.fromRGBO(0x22, 0x2B, 0x2B, 1.0),
        errorRed: Color.fromRGBO(0xFF, 0xB0, 0xB0, 1.0),
        currentClassGreen: Color.fromRGBO(0x8B, 0xD4, 0x81, 1.0),
        basedOnDark: true
    ));

    // True black so OLED panels can switch the pixels off. The accents are lifted
    // from the Dark palette, which was tuned against #222222 and loses contrast here.
    _appColors.add(AppPalette('OLED',
        primary: Color.fromRGBO(0x7E, 0xA6, 0xAE, 1.0),
        onPrimary: Color.fromRGBO(0xFF, 0xFF, 0xFF, 1.0),
        onPrimaryContainer: Color.fromRGBO(0x9C, 0xC7, 0xD0, 1.0),
        secondary: Color.fromRGBO(0x8C, 0xB4, 0xBC, 1.0),
        onSecondary: Color.fromRGBO(0xC8, 0xC8, 0xC8, 1.0),
        onSecondaryContainer: Color.fromRGBO(0x8C, 0xB4, 0xBC, 1.0),
        grade1: Color.fromRGBO(0xFF, 0x6B, 0x6B, 1.0),
        grade2: Color.fromRGBO(0xEF, 0x9A, 0x9A, 1.0),
        grade3: Color.fromRGBO(0xFF, 0xF5, 0x9D, 1.0),
        grade4: Color.fromRGBO(0xC5, 0xE1, 0xA5, 1.0),
        grade5: Color.fromRGBO(0xA5, 0xD6, 0xA7, 1.0),
        navbarStatusBarColor: Color.fromRGBO(0x00, 0x00, 0x00, 1.0),
        navbarNavibarColor: Color.fromRGBO(0x00, 0x00, 0x00, 1.0),
        rootBackground: Color.fromRGBO(0x00, 0x00, 0x00, 1.0),
        textColor: Color.fromRGBO(0xFF, 0xFF, 0xFF, 1.0),
        buttonEnabled: Color.fromRGBO(0x2A, 0x3A, 0x3A, 1.0),
        buttonDisabled: Color.fromRGBO(0x16, 0x1C, 0x1C, 1.0),
        errorRed: Color.fromRGBO(0xFF, 0xB0, 0xB0, 1.0),
        currentClassGreen: Color.fromRGBO(0x8B, 0xD4, 0x81, 1.0),
        basedOnDark: true
    ));

    final target = DataCache.getPreferredAppTheme()!;
    for(var item in getAllThemes()){
      if(item.paletteName == target){
        _themeBatchSelectedIdx = getAllThemes().indexOf(item);
        break;
      }
    }
    _hasInit = true;
  }

  static AppPalette? _cachedPalette;
  static AppPalette getTheme(){
    if(_themeBatchSelectedIdx == -1){
      if(_isDark){
        return _appColors[1];
      }
      else{
        return _appColors[0];
      }
    }
    if(_cachedPalette == null){
      _cachedPalette = getAllThemes()[_themeBatchSelectedIdx];
    }
    return _cachedPalette!;
  }

  static void setCurrentSystemTheme(bool isDark) {
    _isDark = isDark;
    for(var item in _onThemeChangeCallbacks){
      Future.delayed(Duration.zero,(){
        item();
      });
    }
  }

  static bool hasThemeDownloaded(String name){
    for(var item in getAllThemes()){
      if(item.paletteName == name){
        return true;
      }
    }
    return false;
  }

  static void setUserTheme(BuildContext context){
    _cachedPalette = null;
    refreshThemeIndexing();
    Provider.of<ThemeNotifier>(context, listen: false).createNewThemeData();
  }

  static void setUserThemeByName(String name, BuildContext context){
    _cachedPalette = null;
    refreshThemeIndexingWithPrefered(name);
    Provider.of<ThemeNotifier>(context, listen: false).createNewThemeData();
  }

  static List<AppPalette> getAllThemes(){
    final List<AppPalette> list = [];
    list.addAll(_appColors);
    list.addAll(_downloadedAppColors);
    return list;
  }

  static int appThemeToIdx(String name){
    for(var item in getAllThemes()){
      if(item.paletteName == name){
        return getAllThemes().indexOf(item);
      }
    }
    return -1;
  }

  static void refreshThemeIndexing(){
    final List<AppPalette> batch = getAllThemes();
    final userPreference = DataCache.getPreferredAppTheme();
    var idx = -1;
    for(var item in batch){
      if(item.paletteName == userPreference){
        idx = batch.indexOf(item);
        break;
      }
    }
    _themeBatchSelectedIdx = idx;
    for(var item in _onThemeChangeCallbacks){
      Future.delayed(Duration.zero,(){
        item();
      });
    }
  }

  static void refreshThemeIndexingWithPrefered(String prefered){
    final List<AppPalette> batch = getAllThemes();
    final userPreference = prefered;
    var idx = -1;
    for(var item in batch){
      if(item.paletteName == userPreference){
        idx = batch.indexOf(item);
        break;
      }
    }
    _themeBatchSelectedIdx = idx;
    for(var item in _onThemeChangeCallbacks){
      Future.delayed(Duration.zero,(){
        item();
      });
    }
  }

  static void saveDownloadedPaletteData(){
    List<String> saveList = [];
    for(var item in _downloadedAppColors){
      saveList.add(AppPalette.toJson(item));
    }
    DataCache.setAllDownloadedAppThemes(saveList);
  }

  static Timer _loadDownloadColorTimer = Timer(Duration.zero, () {});

  static Future<void> loadDownloadedPaletteData(BuildContext context)async{
    final downloadedPalattesJson = DataCache.getAllDownloadedAppThemes();
    for(var item in downloadedPalattesJson){
      await Future.delayed(Duration.zero, (){
        AppPalette.fromJson(item, ()async{
          if(!DataCache.getHasNetwork()){
            return;
          }
          //await Language.getLanguagePackById(await Language.getAllLanguages(), downloadedSupportedLanguages[i]); // redownload language
          _loadDownloadColorTimer.cancel();
          _loadDownloadColorTimer = Timer(const Duration(seconds: 3), (){
            saveDownloadedPaletteData(); // save after all colors have been fetched
          });
          Navigator.popUntil(context, (route) => route.willHandlePopInternally);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Splitter()),
          );
        });
      });
    }
    refreshThemeIndexing();
  }

  static List<String> getThemesOnline(){
    final List<String> list = [];
    final List<ThemePackMap>? themes = Coloring.getAllThemesCache();
    final obtainedList = getAllThemes();
    for(var item in obtainedList){
      list.add(item.paletteName);
    }
    if(themes == null){
      return list;
    }
    for(var item in themes){
      if(list.contains(item.themeName)){
        continue;
      }
      list.add(item.themeName);
    }
    return list;
  }
  
  static Color getThemePopupAccentByName(String name){
    if(name == _appColors[0].paletteName){
      return Colors.white;
    }
    if(name == _appColors[1].paletteName){
      return Colors.black;
    }
    final onlineThemes = Coloring.getAllThemesCache();
    if(onlineThemes == null){
      return Colors.transparent;
    }
    for(var item in onlineThemes){
      if(item.themeName == name){
        return item.themepackAccent;
      }
    }
    return Colors.transparent;
  }
}

class AppPalette{
  final String paletteName;
  final bool basedOnDark;

  final Color primary;
  final Color onPrimary;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color onSecondaryContainer;
  final Color grade1;
  final Color grade2;
  final Color grade3;
  final Color grade4;
  final Color grade5;

  final Color navbarNavibarColor;
  final Color navbarStatusBarColor;

  final Color rootBackground;
  final Color textColor;

  final Color buttonEnabled;
  final Color buttonDisabled;

  final Color errorRed;

  final Color currentClassGreen;

  const AppPalette(this.paletteName, {required this.basedOnDark, required this.currentClassGreen, required this.errorRed, required this.buttonDisabled, required this.buttonEnabled, required this.textColor, required this.rootBackground, required this.navbarNavibarColor, required this.navbarStatusBarColor, required this.primary, required this.onPrimary, required this.onPrimaryContainer, required this.secondary, required this.onSecondary, required this.onSecondaryContainer, required this.grade1, required this.grade2, required this.grade3, required this.grade4, required this.grade5});

  static AppPalette fromJson(String json, VoidCallback onColorOutdated){
    AppPalette decodedColorPack;
    try{
      final color = conv.json.decode(json);
      decodedColorPack = AppPalette(
        color['paletteName'],
        primary: Color(color['primary']),
        onPrimary: Color(color['onPrimary']),
        onPrimaryContainer: Color(color['onPrimaryContainer']),
        secondary: Color(color['secondary']),
        onSecondary: Color(color['secondary']),
        onSecondaryContainer: Color(color['onSecondaryContainer']),
        grade1: Color(color['grade1']),
        grade2: Color(color['grade2']),
        grade3: Color(color['grade3']),
        grade4: Color(color['grade4']),
        grade5: Color(color['grade5']),
        navbarNavibarColor: Color(color['navbarNavibarColor']),
        navbarStatusBarColor: Color(color['navbarStatusBarColor']),
        rootBackground: Color(color['rootBackground']),
        textColor:Color(color['textColor']),
        buttonDisabled: Color(color['buttonDisabled']),
        buttonEnabled: Color(color['buttonEnabled']),
        errorRed: Color(color['errorRed']),
        currentClassGreen: Color(color['currentClassGreen']),
        basedOnDark: color['basedOnDark'],
      );
      for(var item in AppColors._downloadedAppColors){
        if(item.paletteName == decodedColorPack.paletteName){
          AppColors._downloadedAppColors.removeAt(AppColors._downloadedAppColors.indexOf(item)); // remove duplicate
          break;
        }
      }
      AppColors._downloadedAppColors.add(decodedColorPack);
    }
    catch(error){
      Future.delayed(Duration.zero,(){
        onColorOutdated();
      });
      return AppColors.getTheme();
    }
    return decodedColorPack;
  }

  static String toJson(AppPalette palette){
    final json = conv.json.encode({
      'paletteName':palette.paletteName,
      'primary':palette.primary.toARGB32(),
      'onPrimary':palette.onPrimary.toARGB32(),
      'onPrimaryContainer':palette.onPrimaryContainer.toARGB32(),
      'secondary':palette.secondary.toARGB32(),
      'onSecondary':palette.onSecondary.toARGB32(),
      'onSecondaryContainer':palette.onSecondaryContainer.toARGB32(),
      'grade1':palette.grade1.toARGB32(),
      'grade2':palette.grade2.toARGB32(),
      'grade3':palette.grade3.toARGB32(),
      'grade4':palette.grade4.toARGB32(),
      'grade5':palette.grade5.toARGB32(),
      'navbarNavibarColor':palette.navbarNavibarColor.toARGB32(),
      'navbarStatusBarColor':palette.navbarStatusBarColor.toARGB32(),
      'rootBackground':palette.rootBackground.toARGB32(),
      'textColor':palette.textColor.toARGB32(),
      'buttonEnabled':palette.buttonEnabled.toARGB32(),
      'buttonDisabled':palette.buttonDisabled.toARGB32(),
      'errorRed':palette.errorRed.toARGB32(),
      'currentClassGreen':palette.currentClassGreen.toARGB32(),
      'basedOnDark':palette.basedOnDark
    });
    return json;
  }
}