import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<void> saveString(String key, String value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<void> saveInt(String key, int value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setInt(key, value);
}

Future<void> saveFloat(String key, double value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(key, value);
}

Future<void> saveStringList(String key, List<String> value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(key, value);
}

Future<String?> getString(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Future<int?> getInt(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getInt(key);
}

Future<double?> getFloat(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getDouble(key);
}

Future<List<String>?> getStringList(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(key);
}

class DataCache{
  static Future<void> dataWipe() async{
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.reload();
    _instance._localWipe();
  }

  static Future<void> dataWipeNoKeep()async{
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.reload();
  }

  void _localWipe(){
    _username = '';
    _password = '';
    _instituteUrl = '';
    _instituteFallbackUrls = [];
    _accessToken = '';
    _refreshToken = '';
    _sessionCookie = '';
    _icsExportUrl = '';
    _totpSecret = '';
    _hasNetwork = false;
    _hasLogin = false;
    _hasCachedCalendar = false;
    _hasCachedMarkbook = false;
    _hasCachedPayments = false;
    _hasCachedFirstWeekEpoch = false;
    _hasCachedPeriods = false;
    _firstweekOfSemesterEpoch = 0;
    _isDemoAccount = false;
    _icsLocationPath = '';
    _icsIsUploaded = false;
    setNeedFamilyFriendlyComments(_persistentSetting_familyFriendlyLoadingComments! ? 1 : 0);
    setNeedExamNotifications(_persistentSetting_showExamNotifications! ? 1 : 0);
    setNeedClassNotifications(_persistentSetting_showClassNotifications! ? 1 : 0);
    setNeedClassNotifications(_persistentSetting_showPaymentsNotifications! ? 1 : 0);
    setNeedClassNotifications(_persistentSetting_showPeriodsNotifications! ? 1 : 0);
    setUserWeekOffset(_persistentSetting_weekOffset!);
    setUserSelectedLanguage(_persistentSetting_userSelectedLanguage!);
    setNeedsHaptics(_persistentSetting_needBetterHaptics! ? 1 : 0);
    setIsInstalledFromGPlay(_permanentConfiguration_isInstalledFromGooglePlay!);
    setDownloadedSupportedLanguages(_languageJsonSupportedLangs);
    setDownloadedSupportedLanguagesData(_languageJsonBatch);
    setPreferredAppTheme(_themePreference!);
    setAllDownloadedAppThemes(_themesJsonBatch);
  }

  static final DataCache _instance = DataCache();

  late String? _username = '';
  late String? _password = '';
  late String? _instituteUrl = '';
  List<String> _instituteFallbackUrls = [];
  late String? _accessToken = ''; //new systems token query
  late String? _refreshToken = '';
  late String? _sessionCookie = '';
  late String? _icsExportUrl = '';
  late String? _totpSecret = '';
  late bool _hasNetwork = false;
  late bool? _hasLogin = false;
  late bool? _hasCachedCalendar = false;
  late bool? _hasCachedMarkbook = false;
  late bool? _hasCachedPayments = false;
  late bool? _hasCachedPeriods = false;
  late bool? _hasCachedMail = false;
  late bool? _hasCachedFirstWeekEpoch = false;
  late int? _firstweekOfSemesterEpoch = 0;
  late bool? _isDemoAccount = false;

  bool _isModernApi = false;

  static bool getIsModernApi() {
    return _instance._isModernApi;
  }

  static Future<void> setIsModernApi(bool value) async {
    _instance._isModernApi = value;
    await saveInt('IsModernApi', value ? 1 : 0);
  }

  Future<void> saveBool(String key, bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }
  static double getFontScale() {
    return _prefs?.getDouble('FontScale') ?? 1.0;
  }

  static Future<void> setFontScale(double scale) async {
    await _prefs?.setDouble('FontScale', scale);
  }

  /// 0 means the student has not told us how long their programme is.
  static int getDegreeCreditTarget() {
    return _prefs?.getInt('DegreeCreditTarget') ?? 0;
  }

  static Future<void> setDegreeCreditTarget(int credits) async {
    await _prefs?.setInt('DegreeCreditTarget', credits);
  }

  late bool? _persistentSetting_familyFriendlyLoadingComments = false;
  late bool? _persistentSetting_showExamNotifications = true;
  late bool? _persistentSetting_showClassNotifications = true;
  late bool? _persistentSetting_showGradeNotifications = true;
  late bool? _persistentSetting_showMailNotifications = true;
  late bool _hasAcceptedTerms = false;
  /// Minutes between background grade checks; 0 disables it.
  late int _persistentSetting_backgroundGradeCheckMinutes = 60;
  late bool? _persistentSetting_showPaymentsNotifications = true;
  late bool? _persistentSetting_showPeriodsNotifications = true;
  late int? _persistentSetting_weekOffset = 0;
  late bool? _persistentSetting_needBetterHaptics = true;
  late int? _persistentSetting_userSelectedLanguage = -1;

  late int? _permanentConfiguration_isInstalledFromGooglePlay = 0;



  late List<String> _languageJsonSupportedLangs = [];
  late List<String> _languageJsonBatch = [];

  late String? _themePreference = '';
  late List<String> _themesJsonBatch = [];

  late String? _icsLocationPath = '';
  late bool? _icsIsUploaded = false;

  static Future<void> loadData() async{return _instance._loadData();}

  Future<void> _loadData() async{
    int? tmp;

    _username = await getString('Username');
    _instituteUrl = await getString('URL');
    _instituteFallbackUrls = await getStringList('URL_Fallbacks') ?? [];

    _password = await _secureStorage.read(key: 'neptun_password');


    if (_password == null) {
      String? oldPassword = await getString('Password');
      if (oldPassword != null && oldPassword.isNotEmpty) {
        _password = oldPassword;
        await _secureStorage.write(key: 'neptun_password', value: oldPassword);

      }
    }

    _accessToken = await _secureStorage.read(key: 'neptun_jwt_token');

    if (_accessToken == null) {
      String? oldToken = await getString('AccessToken');
      if (oldToken != null && oldToken.isNotEmpty) {
        _accessToken = oldToken;
        await _secureStorage.write(key: 'neptun_jwt_token', value: oldToken);
      }
    }

    _refreshToken = await _secureStorage.read(key: 'neptun_refresh_token');
    _sessionCookie = await _secureStorage.read(key: 'neptun_session_cookie');
    _icsExportUrl = await _secureStorage.read(key: 'neptun_ics_url');
    _totpSecret = await _secureStorage.read(key: 'neptun_totp_secret');

    tmp = await getInt('IsModernApi');
    _isModernApi = tmp != null && tmp != 0;

    tmp = await getInt('HasLogin');
    _hasLogin = tmp != null && tmp != 0;

    tmp = await getInt('HasAcceptedTerms');
    _hasAcceptedTerms = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedCalendar');
    _hasCachedCalendar = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedMarkbook');
    _hasCachedMarkbook = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedPayments');
    _hasCachedPayments = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedPeriods');
    _hasCachedPeriods = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedMail');
    _hasCachedMail = tmp != null && tmp != 0;

    // checkConnectivity returns a List since connectivity_plus 4; comparing the list
    // itself to ConnectivityResult.none is always true, which left the app permanently
    // believing it was online.
    _hasNetwork = _isOnline(await Connectivity().checkConnectivity());
    Connectivity().onConnectivityChanged.listen((event) {
      _hasNetwork = _isOnline(event);
    });

    tmp = await getInt('HasCachedFirstWeekEpoch');
    _hasCachedFirstWeekEpoch = tmp != null && tmp != 0;

    tmp = await getInt('FirstWeekOfSemesterEpoch');
    _firstweekOfSemesterEpoch = tmp ?? 0;

    tmp = await getInt('IsDemoAccount');
    _isDemoAccount = tmp != null && tmp != 0;

    final prefs = await SharedPreferences.getInstance();
    // _prefs was declared but never assigned, so getFontScale() always answered 1.0
    // and setFontScale() wrote into a null. The font size slider did nothing at all.
    _prefs = prefs;
    _displayClasses = prefs.getBool('CALENDAR_DisplayClasses') ?? true;
    _displayExams = prefs.getBool('CALENDAR_DisplayExams') ?? true;
    _displayPeriods = prefs.getBool('CALENDAR_DisplayPeriods') ?? true;

    tmp = await getInt('SETTING_IsFamilyFriendlyLoading');
    _persistentSetting_familyFriendlyLoadingComments = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_familyFriendlyLoadingComments = false;  // this is the default value
    }

    tmp = await getInt('SETTING_IsNeedExamNotifications');
    _persistentSetting_showExamNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showExamNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_IsNeedClassNotifications');
    _persistentSetting_showClassNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showClassNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_IsNeedGradeNotifications');
    _persistentSetting_showGradeNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showGradeNotifications = true;
    }

    tmp = await getInt('SETTING_IsNeedMailNotifications');
    _persistentSetting_showMailNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showMailNotifications = true;
    }

    _persistentSetting_backgroundGradeCheckMinutes = await getInt('SETTING_BackgroundGradeCheckMinutes') ?? 60;

    tmp = await getInt('SETTING_IsNeedPaymentsNotifications');
    _persistentSetting_showPaymentsNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showPaymentsNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_IsNeedPeriodsNotifications');
    _persistentSetting_showPeriodsNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showPeriodsNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_NeedHaptics');
    _persistentSetting_needBetterHaptics = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_needBetterHaptics = true;
    }

    tmp = await getInt('SETTING_UserWeekOffset');
    _persistentSetting_weekOffset = tmp ?? 0;

    tmp = await getInt('SETTING_UserSelectedLanguage');
    _persistentSetting_userSelectedLanguage = tmp ?? -1;

    tmp = await getInt('CONFIG_IsInstalledFromGPlay');
    _permanentConfiguration_isInstalledFromGooglePlay = tmp ?? 0;


    _languageJsonSupportedLangs = await getStringList('LANGUAGE_DownloadedSupportedLangs') ?? [];
    _languageJsonBatch = await getStringList('LANGUAGE_DownloadedLanguagesJsonBatch') ?? [];

    _icsLocationPath = await getString('ICS_FileLocation') ?? '';

    tmp = await getInt('ICS_HasIcsUpload');
    _icsIsUploaded = tmp != null && tmp != 0;
  }

  static Future<void> loadThemeOnly()async{
    _instance._themePreference = await getString('THEME_AppTheme') ?? 'Dark';
    _instance._themesJsonBatch = await getStringList('THEME_ThemesJsonBatch') ?? [];
  }

  static String? getUsername(){return _instance._username;}
  static Future<void> setUsername(String? value) async{
    _instance._username = value;
    await saveString('Username', value.toString());
  }

  // A sima dolgoknak (pl. beállítások, isModernApi, stb.) marad a SharedPreferences
  static SharedPreferences? _prefs;

  // A kritikus dolgoknak (jelszó, token) létrehozzuk a Secure Storage-ot
  static const _secureStorage = FlutterSecureStorage();
  // PASSWORD HANDLING:



// SZINKRON GETTER! Így a többi fájl nem fog pirosodni,
  // mert azonnal a memóriából kapják meg az adatot.
  static String? getPassword() {
    return _instance._password;
  }

  // ASZINKRON SETTER (Ide mentjük el biztonságosan)
  static Future<void> setPassword(String? password) async {
    _instance._password = password; // Frissítjük a memóriában is

    if (password == null) {
      await _secureStorage.delete(key: 'neptun_password');
    } else {
      await _secureStorage.write(key: 'neptun_password', value: password);
    }
  }

  static String? getInstituteUrl(){return _instance._instituteUrl;}

  static Future<void> setInstituteUrl(String? value) async{
    _instance._instituteUrl = value;
    await saveString('URL', value.toString());
  }

  /// Alternate hosts for the same institute, used when the primary stops responding.
  static List<String> getInstituteFallbackUrls(){return _instance._instituteFallbackUrls;}

  static Future<void> setInstituteFallbackUrls(List<String>? value) async{
    _instance._instituteFallbackUrls = value ?? [];
    await saveStringList('URL_Fallbacks', _instance._instituteFallbackUrls);
  }


// ASZINKRON SETTER
  static Future<void> setAccessToken(String? token) async {
    _instance._accessToken = token; // Frissítjük a memóriában

    if (token == null) {
      await _secureStorage.delete(key: 'neptun_jwt_token');
    } else {
      await _secureStorage.write(key: 'neptun_jwt_token', value: token);
    }
  }

  static String? getAccessToken() {
    return _instance._accessToken;
  }

  static String? getRefreshToken() {
    return _instance._refreshToken;
  }

  static Future<void> setRefreshToken(String? token) async {
    _instance._refreshToken = token;
    if (token == null) {
      await _secureStorage.delete(key: 'neptun_refresh_token');
    } else {
      await _secureStorage.write(key: 'neptun_refresh_token', value: token);
    }
  }

  /// Full "name=value" pair; GetNewTokens rejects the request without it.
  static String? getSessionCookie() {
    return _instance._sessionCookie;
  }

  static Future<void> setSessionCookie(String? cookie) async {
    _instance._sessionCookie = cookie;
    if (cookie == null) {
      await _secureStorage.delete(key: 'neptun_session_cookie');
    } else {
      await _secureStorage.write(key: 'neptun_session_cookie', value: cookie);
    }
  }

  /// Self-authenticating timetable export link, so the calendar survives session loss.
  static String? getIcsExportUrl() {
    return _instance._icsExportUrl;
  }

  static Future<void> setIcsExportUrl(String? url) async {
    _instance._icsExportUrl = url;
    if (url == null) {
      await _secureStorage.delete(key: 'neptun_ics_url');
    } else {
      await _secureStorage.write(key: 'neptun_ics_url', value: url);
    }
  }

  /// Opt-in: lets the app answer the 2FA prompt itself instead of asking on every re-login.
  static String? getTotpSecret() {
    return _instance._totpSecret;
  }

  static Future<void> setTotpSecret(String? secret) async {
    _instance._totpSecret = secret;
    if (secret == null) {
      await _secureStorage.delete(key: 'neptun_totp_secret');
    } else {
      await _secureStorage.write(key: 'neptun_totp_secret', value: secret);
    }
  }

  static Future<String?> getDeviceCookie(String username) async {
    return await _secureStorage.read(key: 'devicecookie_${username.toUpperCase()}');
  }
  static Future<void> setDeviceCookie(String username, String? cookieValue) async {
    if (cookieValue == null) {
      await _secureStorage.delete(key: 'devicecookie_${username.toUpperCase()}');
    } else {
      await _secureStorage.write(key: 'devicecookie_${username.toUpperCase()}', value: cookieValue);
    }
  }

// --- SECURE DATA clear ---
  static Future<void> clearSecureData() async {
    _instance._password = null;
    _instance._accessToken = null;
    _instance._refreshToken = null;
    _instance._sessionCookie = null;
    _instance._icsExportUrl = null;
    _instance._totpSecret = null;
    await _secureStorage.deleteAll();
  }

  static bool getHasNetwork(){return _instance._hasNetwork;}

  static bool getHasAcceptedTerms(){return _instance._hasAcceptedTerms;}
  static Future<void> setHasAcceptedTerms(int? value) async{
    _instance._hasAcceptedTerms = value != null && value != 0;
    await saveInt('HasAcceptedTerms', value ?? 0);
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  static bool? getHasLogin(){return _instance._hasLogin;}
  static Future<void> setHasLogin(int? value) async {
    _instance._hasLogin = value != null && value != 0;
    await saveInt('HasLogin', value ?? 0);
  }

  static bool? getHasCachedCalendar(){return _instance._hasCachedCalendar;}
  static Future<void> setHasCachedCalendar(int? value) async {
    _instance._hasCachedCalendar = value != null && value != 0;
    await saveInt('HasCachedCalendar', value ?? 0);
  }

  static bool? getHasCachedMarkbook(){return _instance._hasCachedMarkbook;}
  static Future<void> setHasCachedMarkbook(int? value) async {
    _instance._hasCachedMarkbook = value != null && value != 0;
    await saveInt('HasCachedMarkbook', value ?? 0);
  }

  static bool? getHasCachedPayments(){return _instance._hasCachedPayments;}
  static Future<void> setHasCachedPayments(int? value) async{
    _instance._hasCachedPayments = value != null && value != 0;
    await saveInt('HasCachedPayments', value ?? 0);
  }

  static bool? getHasCachedPeriods(){return _instance._hasCachedPeriods;}
  static Future<void> setHasCachedPeriods(int? value) async{
    _instance._hasCachedPeriods = value != null && value != 0;
    await saveInt('HasCachedPeriods', value ?? 0);
  }

  static bool? getHasCachedMail(){return _instance._hasCachedMail;}
  static Future<void> setHasCachedMail(int? value) async{
    _instance._hasCachedMail = value != null && value != 0;
    await saveInt('HasCachedMail', value ?? 0);
  }

  static bool? getHasCachedFirstWeekEpoch(){return _instance._hasCachedFirstWeekEpoch;}
  static Future<void> setHasCachedFirstWeekEpoch(int? value) async{
    _instance._hasCachedFirstWeekEpoch = value != null && value != 0;
    await saveInt('HasCachedFirstWeekEpoch', value ?? 0);
  }

  static int? getFirstWeekEpoch(){return _instance._firstweekOfSemesterEpoch;}
  static Future<void> setFirstWeekEpoch(int? value) async{
    _instance._firstweekOfSemesterEpoch = value ?? 0;
    await saveInt('FirstWeekOfSemesterEpoch', value ?? 0);
  }

  static bool? getIsDemoAccount(){return _instance._isDemoAccount;}
  static Future<void> setIsDemoAccount(int? value) async{
    _instance._isDemoAccount = value != null && value != 0;
    await saveInt('IsDemoAccount', value ?? 0);
  }

  static bool? getNeedFamilyFriendlyComments(){return _instance._persistentSetting_familyFriendlyLoadingComments;}
  static Future<void> setNeedFamilyFriendlyComments(int? value) async{
    _instance._persistentSetting_familyFriendlyLoadingComments = value != null && value != 0;
    await saveInt('SETTING_IsFamilyFriendlyLoading', value ?? 0);
  }

  static bool? getNeedExamNotifications(){return _instance._persistentSetting_showExamNotifications;}
  static Future<void> setNeedExamNotifications(int? value) async{
    _instance._persistentSetting_showExamNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedExamNotifications', value ?? 1);
  }

  static bool? getNeedClassNotifications(){return _instance._persistentSetting_showClassNotifications;}
  static Future<void> setNeedClassNotifications(int? value) async{
    _instance._persistentSetting_showClassNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedClassNotifications', value ?? 1);
  }

  static bool? getNeedGradeNotifications(){return _instance._persistentSetting_showGradeNotifications;}
  static Future<void> setNeedGradeNotifications(int? value) async{
    _instance._persistentSetting_showGradeNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedGradeNotifications', value ?? 1);
  }

  static bool? getNeedMailNotifications(){return _instance._persistentSetting_showMailNotifications;}
  static Future<void> setNeedMailNotifications(int? value) async{
    _instance._persistentSetting_showMailNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedMailNotifications', value ?? 1);
  }

  static int getBackgroundGradeCheckMinutes(){return _instance._persistentSetting_backgroundGradeCheckMinutes;}
  static Future<void> setBackgroundGradeCheckMinutes(int value) async{
    _instance._persistentSetting_backgroundGradeCheckMinutes = value;
    await saveInt('SETTING_BackgroundGradeCheckMinutes', value);
  }

  static bool? getNeedPaymentsNotifications(){return _instance._persistentSetting_showPaymentsNotifications;}
  static Future<void> setNeedPaymentsNotifications(int? value) async{
    _instance._persistentSetting_showPaymentsNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedPaymentsNotifications', value ?? 1);
  }

  static bool? getNeedPeriodsNotifications(){return _instance._persistentSetting_showPeriodsNotifications;}
  static Future<void> setNeedPeriodsNotifications(int? value) async{
    _instance._persistentSetting_showPeriodsNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedPeriodsNotifications', value ?? 1);
  }

  static int? getUserWeekOffset(){return _instance._persistentSetting_weekOffset;}
  static Future<void> setUserWeekOffset(int? value)async{
    _instance._persistentSetting_weekOffset = value ?? 0;
    await saveInt('SETTING_UserWeekOffset', value ?? 0);
  }

  static int? getUserSelectedLanguage(){return _instance._persistentSetting_userSelectedLanguage;}
  static Future<void> setUserSelectedLanguage(int? value)async{
    _instance._persistentSetting_userSelectedLanguage = value ?? -1;
    await saveInt('SETTING_UserSelectedLanguage', value ?? -1);
  }

  static bool? getNeedsHaptics(){return _instance._persistentSetting_needBetterHaptics;}
  static Future<void> setNeedsHaptics(int? value)async{
    _instance._persistentSetting_needBetterHaptics =  value != null && value != 0;
    await saveInt('SETTING_NeedHaptics', value ?? 1);
  }

  static int? getIsInstalledFromGPlay({bool excludeDefaultState = true}){return _instance._permanentConfiguration_isInstalledFromGooglePlay! - (excludeDefaultState ? 1 : 0);}
  static Future<void> setIsInstalledFromGPlay(int? value)async{
    _instance._permanentConfiguration_isInstalledFromGooglePlay = value ?? 0;
    await saveInt('CONFIG_IsInstalledFromGPlay', value ?? 0);
  }

  static List<String> getDownloadedSupportedLanguages(){return _instance._languageJsonSupportedLangs;}
  static Future<void> setDownloadedSupportedLanguages(List<String>? value)async{
    _instance._languageJsonSupportedLangs = value ?? [];
    await saveStringList('LANGUAGE_DownloadedSupportedLangs', value ?? []);
  }

  static List<String> getDownloadedSupportedLanguagesData(){return _instance._languageJsonBatch;}
  static Future<void> setDownloadedSupportedLanguagesData(List<String>? value)async{
    _instance._languageJsonBatch = value ?? [];
    await saveStringList('LANGUAGE_DownloadedLanguagesJsonBatch', value ?? []);
  }

  static String? getPreferredAppTheme(){return _instance._themePreference;}
  static Future<void> setPreferredAppTheme(String? value)async{
    _instance._themePreference = value ?? 'Dark';
    await saveString('THEME_AppTheme', value ?? 'Dark');
  }

  static List<String> getAllDownloadedAppThemes(){return _instance._themesJsonBatch;}
  static Future<void> setAllDownloadedAppThemes(List<String>? value)async{
    _instance._themesJsonBatch = value ?? [];
    await saveStringList('THEME_ThemesJsonBatch', value ?? []);
  }

  static String? getICSFileLocation(){return _instance._icsLocationPath;}
  static Future<void> setICSFileLocation(String? value)async{
    _instance._icsLocationPath = value ?? '';
    await saveString('ICS_FileLocation', value ?? '');
  }

  static bool? getHasICSFile(){return _instance._icsIsUploaded;}
  static Future<void> setHasICSFile(bool? value)async{
    _instance._icsIsUploaded = value ?? false;
    await saveInt('ICS_HasIcsUpload', value != null && value != 0 ? 1 : 0);
  }
  // Saját memóriaváltozók, hogy ne kelljen a _prefs-re támaszkodni
  static bool? _displayClasses = true;
  static bool? _displayExams = true;
  static bool? _displayPeriods = true;

  static bool? getDisplayClasses() => _displayClasses;
  static Future<void> setDisplayClasses(bool? value) async {
    _displayClasses = value ?? true;
    // Saját mentés közvetlenül a SharedPreferences-be (nem kell hozzá saveBool)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('CALENDAR_DisplayClasses', _displayClasses!);
  }

  static bool? getDisplayExams() => _displayExams;
  static Future<void> setDisplayExams(bool? value) async {
    _displayExams = value ?? true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('CALENDAR_DisplayExams', _displayExams!);
  }

  static bool? getDisplayPeriods() => _displayPeriods;
  static Future<void> setDisplayPeriods(bool? value) async {
    _displayPeriods = value ?? true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('CALENDAR_DisplayPeriods', _displayPeriods!);
  }

}
