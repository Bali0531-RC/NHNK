import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:nhnk/colors.dart';
import 'package:nhnk/platform_support.dart';
import 'package:nhnk/storage.dart';
import 'package:provider/provider.dart';
import 'Pages/startup_page.dart';
import 'dev/dev_mode.dart';
import 'dev/proc_stats.dart';
import 'language.dart';
import 'startup_trace.dart';

void main() {
  //DataCache.dataWipeNoKeep();
  StartupTrace.begin();
  ProcStats.markLaunch();
  // Installed before anything else so the developer log does not start halfway
  // through the story it is meant to tell.
  DevLog.install();
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  StartupTrace.mark('binding ready');
  FrameStats.install();
  NetTraceBridge.onClear = NetTrace.clear;
  NetTrace.onNotable = DevLog.record;
  DevMode.load();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  DataCache.prewarmSecureStorage();
  DataCache.loadThemeOnly().whenComplete((){
    StartupTrace.mark('loadThemeOnly');
    AppColors.initialize();
    AppStrings.initialize();
    StartupTrace.mark('colors + strings');
    final app = const NhnkApp();
    final themeNotifier = ThemeNotifier(ThemeNotifier._initialTheme(AppColors.getTheme().basedOnDark));
    runApp(
      ChangeNotifierProvider(
        create: (_) => themeNotifier,
        child: app,
      ),
    );
    StartupTrace.mark('runApp');
    WidgetsBinding.instance.addObserver(app);
  });
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
class NhnkApp extends StatelessWidget with WidgetsBindingObserver {
  const NhnkApp({super.key});

  @override
  void didChangePlatformBrightness(){
    final isDark = MediaQuery.of(navigatorKey.currentContext!).platformBrightness == Brightness.dark;
    AppColors.setCurrentSystemTheme(!isDark);
    if(!AppColors.followsSystemBrightness(DataCache.getPreferredAppTheme())){
      super.didChangePlatformBrightness();
      return;
    }
    final preferedTheme = !isDark ? 'Dark' : 'Light';
    AppColors.setUserThemeByName(preferedTheme, navigatorKey.currentContext!);
    DataCache.setPreferredAppTheme(preferedTheme);
    super.didChangePlatformBrightness();
  }

  static bool _themeSetup = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.getTheme().basedOnDark;
    AppColors.setCurrentSystemTheme(isDark);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    if(!_themeSetup){
      _themeSetup = true;
      WidgetsBinding.instance.addPostFrameCallback((_)async{
        await AppColors.loadDownloadedPaletteData(context);
        final isDark = AppColors.getTheme().basedOnDark;
        AppColors.setCurrentSystemTheme(isDark);
        final userTheme = DataCache.getPreferredAppTheme();
        if(AppColors.followsSystemBrightness(userTheme)){
          AppColors.setUserThemeByName(isDark ? 'Dark' : 'Light', navigatorKey.currentContext!);
        }
        AppColors.setUserThemeByName(userTheme!, navigatorKey.currentContext!);
        AppColors.refreshThemeIndexing();
      });
    }
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'NHNK',
      theme: themeNotifier._themeData,
      // A browser reports no safe area, so SafeArea insets nothing and headers sit
      // hard against the top edge. The web build is shown inside a phone frame on
      // the site, so it stands in for the status bar the layout expects.
      builder: AppPlatform.isWeb
          ? (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(padding: media.padding.copyWith(top: 28)),
                child: child!,
              );
            }
          : null,
      home: const Splitter(),
    );
  }
}

class ThemeNotifier extends ChangeNotifier {

  static ThemeNotifier? _instance;

  ThemeData _themeData;
  ThemeNotifier(this._themeData){
    _instance = this;
  }

  static ThemeNotifier? getInstance(){
    return _instance;
  }

  void createNewThemeData(){
    _themeData = _buildTheme(AppColors.isDarktheme());
    notifyListeners();
  }

  ThemeData _buildTheme(bool isDark) => _themeFor(isDark);

  static ThemeData _initialTheme(bool isDark) => _themeFor(isDark);

  /// Without an explicit surface, Scaffold falls back to Material's own grey and the
  /// palette's background never reaches the biggest area on screen. That is what
  /// stopped the OLED theme from actually being black.
  static ThemeData _themeFor(bool isDark) {
    final palette = AppColors.getTheme();
    final scheme = isDark
        ? ColorScheme.dark(
            primary: palette.primary,
            onPrimary: palette.onPrimary,
            onPrimaryContainer: palette.onSecondaryContainer,
            secondary: palette.secondary,
            onSecondary: palette.onSecondary,
            onSecondaryContainer: palette.onSecondaryContainer,
            surface: palette.rootBackground,
            onSurface: palette.textColor,
            surfaceTint: Colors.transparent,
          )
        : ColorScheme.light(
            primary: palette.primary,
            onPrimary: palette.onPrimary,
            onPrimaryContainer: palette.onSecondaryContainer,
            secondary: palette.secondary,
            onSecondary: palette.onSecondary,
            onSecondaryContainer: palette.onSecondaryContainer,
            surface: palette.rootBackground,
            onSurface: palette.textColor,
            surfaceTint: Colors.transparent,
          );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.rootBackground,
      canvasColor: palette.rootBackground,
      useMaterial3: true,
    );
  }
}