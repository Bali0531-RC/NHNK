import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:nhnk/API/ics_calendar.dart';
import 'package:nhnk/MailElements/mail_element_widget.dart';
import 'package:nhnk/Misc/demo_notice.dart';
import 'package:nhnk/colors.dart';
import 'package:nhnk/language.dart';
import 'package:nhnk/notifications.dart';
import 'package:nhnk/Misc/emojirich_text.dart';
import 'package:nhnk/PaymentsElements/payment_element_widget.dart';
import '../API/api_coms.dart' as api;
import '../Misc/auto_updater.dart';
import '../background_worker.dart';
import '../grade_alerts.dart';
import '../haptics.dart';
import '../mail_alerts.dart';
import '../storage.dart' as storage;
import '../TimetableElements/timetable_element_widget.dart' as t_table;
import '../MarkbookElements/markbook_element_widget.dart' as mbook;
import '../PeriodsElements/periods_element_widget.dart' as priods;
import '../Navigator/bottomnavigator.dart' as bottomnav;
import '../Navigator/topnavigator.dart' as topnav;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../Pages/startup_page.dart' as root_page;
import '../Misc/app_drawer.dart';
import '../Misc/average_calculator.dart';
import '../Misc/offline_notice.dart';
import 'package:nhnk/platform_support.dart';

class HomePage extends StatefulWidget{
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with TickerProviderStateMixin{

  final List<Widget> _confettiList = [];
  final List<ConfettiHelper> _confettiHelperList = [];

  late AnimationController _confettiController;
  late Animation<double> _confettiAnimation;

  bool _confettiCanGetFreshAnim = true;
  bool _confettiCanBePlayed = false;
  bool _confettiRefreshRetrigger = true;

  static HomePageState? _instance;
  HomePageState(){
    _instance = this;
  }

  static void showBlurPopup(bool b){
    _instance?.setBlurComplex(b);
  }

  bool _showBlur = false;
  void setBlur(bool state){
    setState(() {
      _showBlur = state;
    });
  }

  late AnimationController blurController;
  late Animation<double> blurAnimation;

  void setBlurComplex(bool state){
    setState(() {
      if(state) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: AppColors.getTheme().navbarNavibarColor, // navigation bar color
            statusBarColor: AppColors.getTheme().navbarStatusBarColor, // status bar color
        ));
        blurController.forward();
        _showBlur = true;
        return;
      }
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: AppColors.getTheme().rootBackground, // navigation bar color
        statusBarColor: AppColors.getTheme().rootBackground, // status bar color
      ));
      blurController.reverse().whenComplete((){
        setState(() {
          _showBlur = false;
        });
      });
    });
  }

  late List<api.CalendarEntry> calendarEntries = <api.CalendarEntry>[].toList();
  late List<api.Subject> markbookEntries = <api.Subject>[].toList();
  late List<api.CashinEntry> paymentsEntries = <api.CashinEntry>[].toList();
  late List<api.PeriodEntry> periodEntries = <api.PeriodEntry>[].toList();
  late List<api.MailEntry> mailEntries = <api.MailEntry>[].toList();

  late final List<Widget> mondayCalendar = <Widget>[].toList();
  late final List<Widget> tuesdayCalendar = <Widget>[].toList();
  late final List<Widget> wednessdayCalendar = <Widget>[].toList();
  late final List<Widget> thursdayCalendar = <Widget>[].toList();
  late final List<Widget> fridayCalendar = <Widget>[].toList();
  late final List<Widget> saturdayCalendar = <Widget>[].toList();
  late final List<Widget> sundayCalendar = <Widget>[].toList();

  late final List<Widget> markbookList = <Widget>[].toList();

  late final List<Widget> paymentsList = <Widget>[].toList();
  late final List<Widget> periodList = <Widget>[].toList();
  late final List<Widget> mailList = <Widget>[].toList();

  late final LinkedScrollControllerGroup bottomnavScrollCntroller;
  late final ScrollController bottomnavController;

  late final TextEditingController settingsUserWeekOffset;
  late int settingsUserWeekOffsetPrev;
  String prevSettingsUserWeekOffset = '';
  static TextEditingController getUserWeekOffsetTextController(){
    return _instance!.settingsUserWeekOffset;
  }
  static Timer? settingsUserWeekOffsetPeriodicLooper = null;

  bool canDoCalendarPaging = false;
  int weeksSinceStart = 1;
  int currentWeekOffset = 1;
  late TabController calendarTabController;
  int currentView = 0;

  /// Cache timestamp per tab, so the offline banner can say how old the figures are.
  final Map<int, DateTime?> _lastUpdated = {};
  StreamSubscription? _connectivitySub;

  static const Map<int, String> _cacheTimeKeys = {
    0: 'CalendarCacheTime',
    1: 'MarkbookCacheTime',
    2: 'PaymentsCacheTime',
    3: 'PeriodsCacheTime',
    4: 'MailCacheTime',
  };

  Future<void> refreshLastUpdated() async{
    for(final entry in _cacheTimeKeys.entries){
      final raw = await storage.getString(entry.value);
      _lastUpdated[entry.key] = raw == null ? null : DateTime.tryParse(raw);
    }
    if(mounted) setState((){});
  }
  String calendarGreetText = "";

  int totalCredits = 0;
  int totalMoney = 0;
  double totalAvg = 0;
  double totalAvg30 = 0;
  /// Credits that carry a grade, which is what the average is weighted over.
  int gradedCredits = 0;

  int currentSemester = -1;
  int countActivePeriods = 0;
  int countFuturePeriods = 0;
  int countExpiredPeriods = 0;

  int unreadMailCount = 0;
  int totalMailCount = 0;
  int allLoadedMailCount = 0;

  double bottomNavSwitchValue = 0.0;
  bool bottomNavCanNavigate = true;
  static const int maxBottomNavWidgets = 5;

  double calendarWeekSwitchValue = 0.0;
  bool calendarWeekCanNavigate = true;

  @override
  void initState() {
    super.initState();

    FlutterNativeSplash.remove();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.getTheme().rootBackground, // navigation bar color
      statusBarColor: AppColors.getTheme().rootBackground, // status bar color
    ));

    api.Generic.setupDaylightSavingsTime();

    if(storage.DataCache.getHasICSFile() ?? false){
      ICSCalendar.initialize();
    }

    Future.delayed(const Duration(seconds: 4), () async {
      // Az új letöltő meghívása
      await AppUpdater.checkAndInstallUpdate(context);
    });

    Future.delayed(Duration(seconds: 4),()async{
      await LanguageManager.suggestLang(context, null, null);
    });
    Future.delayed(Duration(seconds: 1),()async{
      await LanguageManager.refreshAllDownloadedLangs();
    });

    if(AppPlatform.isMobile){
      Future.delayed(Duration.zero, ()async{
        tz.initializeTimeZones();
        final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
        final String timeZone = timeZoneInfo.identifier;
        tz.setLocalLocation(tz.getLocation(timeZone));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppUpdater.checkAndInstallUpdate(context);
      });
    }

    if(AppPlatform.isAndroid && storage.DataCache.getIsInstalledFromGPlay() != 0){
      Future.delayed(const Duration(seconds: 4), ()async{
        final cacheTime = await storage.getInt('UpdateCacheTime') ?? -1;
        if(cacheTime <= 0){ // fresh app version
          storage.saveInt('UpdateCacheTime', DateTime.now().millisecondsSinceEpoch);
          return;
        }

        if((DateTime.now().millisecondsSinceEpoch - cacheTime) > const Duration(hours: 24).inMilliseconds || // once a day update check
        await Connectivity().checkConnectivity() == ConnectivityResult.none) // only check for updates, if there is internet
        {return;}

        final appupdateInfo = await InAppUpdate.checkForUpdate();
        storage.saveInt('UpdateCacheTime', DateTime.now().millisecondsSinceEpoch); // save last checked update time
        if(appupdateInfo.updateAvailability == UpdateAvailability.updateAvailable){ // has new version
          AppHaptics.attentionImpact();
          await InAppUpdate.startFlexibleUpdate().then((value) async { // install update
            await InAppUpdate.completeFlexibleUpdate();
          });
        }
      });
    }

    bottomnavScrollCntroller = LinkedScrollControllerGroup();
    bottomnavController = bottomnavScrollCntroller.addAndGet();

    final userWeekOffserValue = storage.DataCache.getUserWeekOffset()!;
    settingsUserWeekOffset = TextEditingController(text: (userWeekOffserValue == 0 ? '' : userWeekOffserValue.toString()));
    prevSettingsUserWeekOffset = settingsUserWeekOffset.text;
    settingsUserWeekOffsetPrev = storage.DataCache.getUserWeekOffset()!;
    settingsUserWeekOffset.addListener(() {
      if(settingsUserWeekOffset.text != prevSettingsUserWeekOffset){
        _instance!.changedSettingsUserWeekOffset = true;
        _instance!.settingsUserWeekOffsetSetup();
      }
    });

    blurController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
    );
    blurAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: blurController, curve: Curves.linear),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    _confettiAnimation = Tween<double>(begin: -0.2, end: 1.0).animate(
      CurvedAnimation(parent: _confettiController, curve: Curves.linear)
    );

    currentMailPageController = ScrollController();
    currentMailPageController.addListener(() {
      //debug.log(currentMailPageController.position.atEdge.toString() + " " + currentMailPageController.position.userScrollDirection.toString());
      if(currentMailPageController.position.atEdge && currentMailPageController.position.userScrollDirection == ScrollDirection.reverse && allLoadedMailCount < totalMailCount){
        if(currentMailLoadingDebounce){
          return;
        }
        currentMailLoadingDebounce = true;
        Future.delayed(Duration.zero, ()async{
          setState((){
            currentMailPage++;
            mailList.add(Column(
              children: [
                CircularProgressIndicator(
                  color: AppColors.getTheme().textColor,
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 5)),
                Text(
                 api.Generic.randomLoadingCommentMini(storage.DataCache.getNeedFamilyFriendlyComments()!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.getTheme().textColor.withValues(alpha: .4),
                    fontSize: 11,
                    fontWeight: FontWeight.w300
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8)),
              ],
            ),);
          });
          await fetchMails(force: true);
          setupMails(clear: true);
        }).whenComplete((){
          currentMailLoadingDebounce = false;
        });
      }
    });

    AppNotifications.initialize();
    BackgroundWorker.sync();
    refreshLastUpdated();
    // The banner has to react on its own; nothing else rebuilds when the radio drops.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_){
      if(mounted) setState((){});
    });
    Future.delayed(Duration.zero, ()async{
      if(((await storage.getInt('NextFirstWeekCacheTime')) ?? 0) < DateTime.now().millisecondsSinceEpoch){
        storage.DataCache.setHasCachedFirstWeekEpoch(0);
        storage.saveInt('NextFirstWeekCacheTime', DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch);
      }
      if(storage.DataCache.getHasCachedFirstWeekEpoch()!){
        return;
      }
      final firstWeekOfSemester = await api.InstitutesRequest.getFirstStudyweek();
      storage.DataCache.setHasCachedFirstWeekEpoch(1);
      await storage.DataCache.setFirstWeekEpoch(firstWeekOfSemester);
    }).whenComplete((){
      Future.delayed(const Duration(seconds: 1), (){
        setState(() {weeksSinceStart = calcPassedWeeks();});
      });
    });

    Future.delayed(Duration.zero,() async{
      await AppNotifications.cancelScheduledNotifs();
    }).whenComplete((){
      Future.delayed(Duration.zero, () async{
        await fetchCalendar();
      }).then((value) async {
        if(storage.DataCache.getNeedExamNotifications()!){
          Future.delayed(Duration.zero,() async{
            if(!storage.DataCache.getHasNetwork()){
              return;
            }
            await _skimForExams();
          });
        }
        setupCalendar(true);
      });

      Future.delayed(Duration.zero, () async{
        await fetchMarkbook();
      }).then((value) {
        setupMarkbook();
      });

      Future.delayed(Duration.zero, () async{
        await fetchPayments();
      }).then((value) {
        setupPayments();
      });

      Future.delayed(Duration.zero, () async{
        await fetchPeriods();
      }).then((value) {
        setupPeriods();
      });

      Future.delayed(Duration.zero, () async{
        await fetchMails();
      }).then((value) {
        setupMails();
      });
    });

    setupCalendarGreetText();
    setupCalendarController(true, true);

    AppColors.clearThemeChangeCallbacks();
    AppColors.subThemeChangeCallback((){
      if(!mounted){
        return;
      }
      setState(() {

      });
      Future.delayed(Duration.zero, (){
        onCalendarRefresh(false);
        onMarkbookRefresh();
        onPaymentsRefresh();
        onPeriodsRefresh();
        onMailRefresh();
      });
    });
  }

  void userUnavailableAccountLogout(){
    Future.delayed(Duration.zero, ()async{
      await storage.DataCache.dataWipe();
      await AppNotifications.cancelScheduledNotifs();
    }).whenComplete((){
      Navigator.popUntil(context, (route) => route.willHandlePopInternally);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const root_page.Splitter()),
      );
    });
  }

  bool changedSettingsUserWeekOffset = false;

  void settingsUserWeekOffsetSetup(){
    if(settingsUserWeekOffset.text == '-'){
      return;
    }
    var newVal = int.tryParse(settingsUserWeekOffset.text);
    var correctedVal = 0;
    if(newVal == null || newVal == 0){
      settingsUserWeekOffset.text = '';
      prevSettingsUserWeekOffset = settingsUserWeekOffset.text;
      Future.delayed(Duration.zero, ()async{
        await storage.DataCache.setUserWeekOffset(correctedVal);
      });
      return;
    }
    correctedVal = clampDouble(newVal.toDouble(), -51, 51).toInt();
    settingsUserWeekOffset.text = correctedVal.toString();
    settingsUserWeekOffset.text = correctedVal.toString();
    prevSettingsUserWeekOffset = settingsUserWeekOffset.text;
    Future.delayed(Duration.zero, ()async{
      await storage.DataCache.setUserWeekOffset(correctedVal);
    });
  }

  static void settingsUserWeekOffsetAdd(int val){
    _instance!.changedSettingsUserWeekOffset = true;
    final oldVal = storage.DataCache.getUserWeekOffset()!;
    var correctedVal = oldVal + val;
    correctedVal = clampDouble(correctedVal.toDouble(), -51, 51).toInt();
    _instance!.settingsUserWeekOffset.text = correctedVal.toString();
    _instance!.prevSettingsUserWeekOffset = _instance!.settingsUserWeekOffset.text;
    Future.delayed(Duration.zero, ()async{
      await storage.DataCache.setUserWeekOffset(correctedVal);
    });
  }

  static void settingsUserWeekOffsetChangeDetect(){
    _instance?._settingsUserWeekOffsetChangeDetect();
  }
  void _settingsUserWeekOffsetChangeDetect(){
    final currentOffset = storage.DataCache.getUserWeekOffset()!;
    if(settingsUserWeekOffsetPrev != currentOffset){
      settingsUserWeekOffsetPrev = currentOffset;
      Future.delayed(Duration.zero,() async{
        await storage.DataCache.setHasCachedCalendar(0);
        await AppNotifications.cancelScheduledNotifs();
      }).whenComplete(()async{
        await onCalendarRefresh(false);
      });
    }
  }

  void setupCalendarGreetText(){
    final currentTimeHour = DateTime.now().hour;
    if(currentTimeHour > 1 && currentTimeHour <= 6){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_1to6;
      });
    }
    else if(currentTimeHour > 6 && currentTimeHour <= 9){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_6to9;
      });
    }
    else if(currentTimeHour > 9 && currentTimeHour <= 13){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_9to13;
      });
    }
    else if(currentTimeHour > 13 && currentTimeHour <= 17){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_13to17;
      });
    }
    else if(currentTimeHour > 17 && currentTimeHour <= 21){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_17to21;
      });
    }
    else if(currentTimeHour > 21 || currentTimeHour <= 1){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_21to1;
      });
    }
  }

  void clearCalendar(){
    setState(() {
      weeksSinceStart = calcPassedWeeks();
      calendarEntries.clear();
      mondayCalendar.clear();
      tuesdayCalendar.clear();
      wednessdayCalendar.clear();
      thursdayCalendar.clear();
      fridayCalendar.clear();
      saturdayCalendar.clear();
      sundayCalendar.clear();
    });
  }

  void clearMarkbook(){
    setState(() {
      markbookEntries.clear();
      markbookList.clear();
    });
  }

  void clearPayments(){
    setState(() {
      paymentsEntries.clear();
      paymentsList.clear();
    });
  }
  void clearPeriods(){
    setState(() {
      periodEntries.clear();
      periodList.clear();
      currentSemester = -1;
      countActivePeriods = 0;
      countExpiredPeriods = 0;
      countFuturePeriods = 0;
    });
  }

  void clearMails(){
    setState(() {
      mailEntries.clear();
      mailList.clear();
      currentMailPage = 1;
      currentMailLoadingDebounce = false;
      unreadMailCount = 0;
      totalMailCount = 0;
      allLoadedMailCount = 0;
    });
  }

  void setupCalendar(bool thisweekCalendar){
    setState(() {
      _setupCalendar(thisweekCalendar);
      canDoCalendarPaging = true;
      setupCalendarController(false, false);
    });
  }
  void setupMarkbook(){
    setState(() {
      _setupMarkbook();
    });
  }

  void setupPayments(){
    setState(() {
      _setupPayments();
    });
  }

  void setupPeriods(){
    setState(() {
      _setupPeriods();
    });
  }

  void setupMails({bool clear = false}){
    setState(() {
      _setupMails(clearLoader: clear);
    });
  }

  static void setupExamNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupExamNotifications(_instance!._examNotificationList);
    });
  }

  static void cancelExamNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelExamNotifications();
    });
  }

  final _examNotificationList = <api.CalendarEntry>[];
  
  Future<void> _skimForExams()async{
    _examNotificationList.clear();
    for(int i = 0; i < 3; i++){
      final result = await fetchCalendarToList(i);
      _examNotificationList.addAll(result);
    }

    _setupExamNotifications(_examNotificationList);
  }
  
  Future<void> _setupExamNotifications(List<api.CalendarEntry> items)async{
    await _cancelExamNotifications();
    if(_examNotificationList.isEmpty){
      return;
    }
    final now = DateTime.now();
    for(var item in items){ // add notifiers for exams
      if(!item.isExam || now.millisecondsSinceEpoch > item.startEpoch){
        continue;
      }
      await _setupNotificationsForSkimmedExams(item, now);
    }
  }

  Future<void> _setupNotificationsForSkimmedExams(api.CalendarEntry item, DateTime now)async{
    final daysTillExam = (Duration(milliseconds: item.startEpoch) - Duration(milliseconds: now.millisecondsSinceEpoch)).inDays;
    for(int i = 1; i <= daysTillExam + 1; i++){
      if(i == 1){
        await AppNotifications.scheduleNotification('Vizsga emlékeztető!', '"${item.title}" tárgyból vizsgád lesz MA!', DateTime(now.year, now.month, now.day + daysTillExam - i + 2, 06, 00), 0);
        continue;
      }
      else if(i == 2){
        await AppNotifications.scheduleNotification('Vizsga emlékeztető!', '"${item.title}" tárgyból vizsgád lesz HOLNAP!', DateTime(now.year, now.month, now.day + daysTillExam - i + 2, 09, 00), 0);
        continue;
      }
      await AppNotifications.scheduleNotification('Vizsga emlékeztető!', '"${item.title}" tárgyból vizsgád lesz $i nap múlva!', DateTime(now.year, now.month, now.day + daysTillExam - i + 2, 09, 00), 0);
    }
  }

  Future<void> _cancelExamNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(0);
  }

  static void setupClassesNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupClassesNotifications(_instance!._classesNotificationList);
    });
  }

  static void cancelClassesNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelClassesNotifications();
    });
  }

  final List<api.CalendarEntry> _classesNotificationList = <api.CalendarEntry>[].toList();

  Future<void> _setupClassesNotifications(List<api.CalendarEntry> items)async{
    await _cancelClassesNotifications();
    if(!storage.DataCache.getNeedClassNotifications()!){
      return;
    }
    for(var item in items){
      // set up notifications for today
      final now = DateTime.now();
      if(now.millisecondsSinceEpoch < item.startEpoch && !item.isExam){ // did not pass them in time

        String finalRoom = item.location;
        if (item.classInstanceId != null && item.classInstanceId!.isNotEmpty) {
          String? cachedRoom = await storage.getString('room_${item.classInstanceId}');
          if (cachedRoom != null && cachedRoom.isNotEmpty && cachedRoom != "Nincs terem") {
            finalRoom = cachedRoom;
          }
        }
        // -------------------------------------------------------------------------------

        await AppNotifications.scheduleNotification('Óra', '"${item.title}" órád lesz itt: "$finalRoom" 10 perc múlva!', DateTime.fromMillisecondsSinceEpoch((Duration(milliseconds: item.startEpoch) - const Duration(minutes: 10)).inMilliseconds), 1);
        await AppNotifications.scheduleNotification('Óra', '"${item.title}" órád lesz itt: "$finalRoom" 5 perc múlva!', DateTime.fromMillisecondsSinceEpoch((Duration(milliseconds: item.startEpoch) - const Duration(minutes: 5)).inMilliseconds), 1);
        await AppNotifications.scheduleNotification('Óra', '"${item.title}" órád van itt: "$finalRoom"!', DateTime.fromMillisecondsSinceEpoch(item.startEpoch), 1);
      }
    }
  }
  
  Future<void> _cancelClassesNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(1);
  }

  static void setupPaymentsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupPaymentsNotification(_instance!._paymentsNotificationList);
    });
  }

  static void cancelPaymentsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelPaymentsNotifications();
    });
  }

  final List<api.CashinEntry> _paymentsNotificationList = <api.CashinEntry>[].toList();

  Future<void> _setupPaymentsNotification(List<api.CashinEntry> items)async{
    await _cancelPaymentsNotifications();
    if(!storage.DataCache.getNeedPaymentsNotifications()! || _paymentsNotificationList.isEmpty){
      return;
    }
    final now = DateTime.now();
    for(var item in items){
      if(item.dueDateMs == 0){
        for(int i = 0; i <= 31; i++){
          await AppNotifications.scheduleNotification('Befizetés', '${item.ammount}Ft-al lógsz. Fizesd be! (Nincs határidő)', DateTime(now.year, now.month, now.day + i, 11, 00),2 );
        }
        continue;
      }
      final daysRemaining = (Duration(milliseconds: item.dueDateMs) - Duration(milliseconds: now.millisecondsSinceEpoch)).inDays;
      final time = DateTime.fromMillisecondsSinceEpoch(item.dueDateMs);
      for(int i = 0; i <= daysRemaining; i++){
        await AppNotifications.scheduleNotification('Befizetés', '${item.ammount}Ft-al lógsz. Fizesd be: ${daysRemaining > 61 ? "(${time.year})" : ""} ${api.Generic.monthToText(time.month)}. ${time.day}.-ig!', DateTime(now.year, now.month, now.day + i, 11, 00), 2);
      }
    }
  }

  Future<void> _cancelPaymentsNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(2);
  }
  
  static void setupPeriodsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupPeriodsNotification(_instance!._periodsNotificationList);
    });
  }

  static void cancelPeriodsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelPeriodsNotifications();
    });
  }

  final List<api.PeriodEntry> _periodsNotificationList = <api.PeriodEntry>[].toList();
  
  Future<void> _setupPeriodsNotification(List<api.PeriodEntry> items)async{
    await _cancelPeriodsNotifications();
    if(!storage.DataCache.getNeedPeriodsNotifications()! || _periodsNotificationList.isEmpty){
      return;
    }

    for(var item in items){
      final time = DateTime.fromMillisecondsSinceEpoch(item.startEpoch);
      await AppNotifications.scheduleNotification('Időszak', '"${api.Generic.capitalizePeriodText(item.name)}" időszak lesz HOLNAP!', DateTime(time.year, time.month, time.day - 1, 11, 00), 3);
      await AppNotifications.scheduleNotification('Időszak', '"${api.Generic.capitalizePeriodText(item.name)}" időszak van MA!', DateTime(time.year, time.month, time.day, 06, 00), 3);
    }
  }

  Future<void> _cancelPeriodsNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(3);
  }

  void _setupCalendar(bool thisweekCalendar){
    if (thisweekCalendar) {
      _classesNotificationList.clear();
    }
    int idx = 1;
    int prev = 0;
    api.CalendarEntry? prevEntry;
    final currWeekday = DateTime.now().weekday;
    for(var item in calendarEntries){
      if(!item.isExam){
        continue;
      }
      final wkday = DateTime.fromMillisecondsSinceEpoch(item.startEpoch).weekday;
      if(prev != wkday){
        idx = 1;
        prev = wkday;
      }
      switch(wkday){
        case 1:
          mondayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: false, // exam is an exam, not the current class, but even if this is true, nothing would change
          ));
          break;
        case 2:
          tuesdayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: false,
          ));
          break;
        case 3:
          wednessdayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: false,
          ));
          break;
        case 4:
          thursdayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: false,
          ));
          break;
        case 5:
          fridayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: false,
          ));
          break;
        case 6:
          saturdayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: false,
          ));
          break;
        case 7:
          sundayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: false,
          ));
          break;
      }
      idx++;
    }

    final now = DateTime.now();
    for(var item in calendarEntries){
      if(item.isExam){
        continue;
      }
      final wkday = DateTime.fromMillisecondsSinceEpoch(item.startEpoch).weekday;
      if(prev != wkday){
        idx = 1;
        prev = wkday;
        prevEntry = item;
      }
      if(thisweekCalendar && currWeekday == wkday){
        _classesNotificationList.add(item);
      }
      if(idx == 2 && item.startEpoch == prevEntry!.startEpoch){
        idx--;
      }
      final isCurrent = now.millisecondsSinceEpoch >= item.startEpoch && now.millisecondsSinceEpoch <= item.endEpoch && wkday == currWeekday && currentWeekOffset == 1; // if we are on the homepage, and the day is the same as today, and the event is not expired => it is currently active
      switch(wkday){
        case 1:
          mondayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: isCurrent,
          ));
          break;
        case 2:
          tuesdayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: isCurrent,
          ));
          break;
        case 3:
          wednessdayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: isCurrent,
          ));
          break;
        case 4:
          thursdayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: isCurrent,
          ));
          break;
        case 5:
          fridayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: isCurrent,
          ));
          break;
        case 6:
          saturdayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: isCurrent,
          ));
          break;
        case 7:
          sundayCalendar.add(t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: isCurrent,
          ));
          break;
      }
      if(idx == 1 || prevEntry == null || item.startEpoch != prevEntry.startEpoch){
        prevEntry = item;
        idx++;
      }
    }
    calendarTabController.index = currentWeekOffset == 1 ? currWeekday - 1 > 6 ? 0 : currWeekday - 1 : calendarTabController.index;
  }

  List<Widget> calendarTabs = <Widget>[].toList();
  List<Widget> calendarTabViews = <Widget>[].toList();

  void setupCalendarController(bool replaceController, bool isLoading){
    calendarTabs = <Widget>[].toList();
    calendarTabViews = <Widget>[].toList();
    getCalendarTabViews(context, isLoading);
    if(replaceController) {
      calendarTabController = TabController(length: calendarTabs.length, vsync: this);
    }
    setState(() {
      isLoadingCalendar = isLoading;
    });
  }

  void _fillOneCalendarElement(BuildContext context, List<Widget> w, String name, bool isLoading){
    calendarTabs.add(Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Tab(
        child: Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12
          ),
        ),
      ),
    ));
    calendarTabViews.add(RefreshIndicator(
      onRefresh: ()async{AppHaptics.lightImpact(); onCalendarRefresh(false);},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        scrollDirection: Axis.vertical,
        child: Container(
          margin: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: w.isNotEmpty ? AppColors.getTheme().textColor.withValues(alpha: 0.03) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: w.isNotEmpty ? w : isLoading ? <Widget>[
              Center(
                child: CircularProgressIndicator(
                  color: AppColors.getTheme().textColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.getTheme().textColor.withValues(alpha: .2),
                  fontWeight: FontWeight.w300,
                  fontSize: 10
                ),
              )
            ] : <Widget>[const t_table.FreedayElementWidget()],
          ),
        ),
      ),
    ));
  }

  void getCalendarTabViews(BuildContext context, bool isLoading){
    _fillOneCalendarElement(context, mondayCalendar, AppStrings.getLanguagePack().api_dayMon_Universal, isLoading);
    _fillOneCalendarElement(context, tuesdayCalendar, AppStrings.getLanguagePack().api_dayTue_Universal, isLoading);
    _fillOneCalendarElement(context, wednessdayCalendar, AppStrings.getLanguagePack().api_dayWed_Universal, isLoading);
    _fillOneCalendarElement(context, thursdayCalendar, AppStrings.getLanguagePack().api_dayThu_Universal, isLoading);
    _fillOneCalendarElement(context, fridayCalendar, AppStrings.getLanguagePack().api_dayFri_Universal, isLoading);
    _fillOneCalendarElement(context, saturdayCalendar, AppStrings.getLanguagePack().api_daySat_Universal, isLoading);
    _fillOneCalendarElement(context, sundayCalendar, AppStrings.getLanguagePack().api_daySun_Universal, isLoading);
  }

  void _mbookPopupResult(int result, int idx){
    if(result == -1){
      setState(() {
        final e = markbookList[idx] as mbook.MarkbookElementWidget;
        setState(() {
          markbookList[idx] = mbook.MarkbookElementWidget(
            name: e.name,
            credit: e.credit,
            completed: e.completed,
            grade: e.grade,
            isFailed: e.isFailed,
            onPopupResult: e.onPopupResult,
            listIndex: e.listIndex,
            ghostGrade: -1,
          );
          _markbookCalcGhostAvg();
        });
      });
      return;
    }

    final grade = result + 1;
    final e = markbookList[idx] as mbook.MarkbookElementWidget;
    setState(() {
      markbookList[idx] = mbook.MarkbookElementWidget(
        name: e.name,
        credit: e.credit,
        completed: e.completed,
        grade: e.grade,
        isFailed: e.isFailed,
        onPopupResult: e.onPopupResult,
        listIndex: e.listIndex,
        ghostGrade: grade,
      );
      _markbookCalcGhostAvg();
    });
  }
  
  void _setupMarkbook(){
    totalAvg = 5;
    totalAvg30 = 5;
    if(markbookEntries.isEmpty){
      totalCredits = 0;
      markbookList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().markbookPage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
    }

    //order them
    for (int i = 0; i < markbookEntries.length; i++){
      for (int j = i; j < markbookEntries.length; j++){
        if(markbookEntries[j].credit > markbookEntries[i].credit){
          final tmp = markbookEntries[i];
          markbookEntries[i] = markbookEntries[j];
          markbookEntries[j] = tmp;
        }
      }
    }

    // set them up
    totalCredits = 0;
    totalAvg = 0;
    totalAvg30 = 0;
    var hasCompleted = false;
    var hasIncomplete = false;
    int idx = 0;
    for (var item in markbookEntries){
      totalCredits += item.credit;
      if(item.completed){
        hasCompleted = true;
        continue;
      }
      hasIncomplete = true;
      markbookList.add(mbook.MarkbookElementWidget(
        name: item.name,
        credit: item.credit,
        completed: item.completed,
        grade: item.grade,
        isFailed: item.failState == 1,
        onPopupResult: _mbookPopupResult,
        listIndex: idx,
        ghostGrade: -1,
      ));
      idx++;
    }
    if(hasCompleted) {
      if(hasIncomplete){
        markbookList.add(
            _getSeparatorLine(AppStrings.getLanguagePack().markbookPage_CompletedLine)
        );
        idx++;
      }

      for (var item in markbookEntries) {
        if (!item.completed) {
          continue;
        }
        markbookList.add(mbook.MarkbookElementWidget(
          name: item.name,
          credit: item.credit,
          completed: item.completed,
          grade: item.grade,
          isFailed: item.failState == 1,
          onPopupResult: _mbookPopupResult,
          listIndex: idx,
          ghostGrade: -1,
        ));
        idx++;
      }
    }
    _confettiCanBePlayed = !hasIncomplete && hasCompleted; // all finished
    _markbookCalcAvg();
  }

  void _markbookCalcAvg(){
    if(markbookEntries.isEmpty){
      return;
    }
    var currCredits = 0;
    for(var item in markbookEntries){
      if (!item.completed) {
        continue;
      }
      if (item.grade >= 2) {
        currCredits += item.credit;
        totalAvg += item.grade * item.credit;
      }
    }
    totalAvg30 = totalAvg / 30;
    totalAvg /= currCredits;
    gradedCredits = currCredits;
  }

  void _markbookCalcGhostAvg(){
    if(markbookEntries.isEmpty){
      return;
    }
    var currCredits = 0;
    totalAvg = 0;
    totalAvg30 = 0;
    for(var item in markbookList){
      try{
        final itm = item as mbook.MarkbookElementWidget;
        if(!itm.completed && itm.ghostGrade == -1){
          continue;
        }
        if (item.grade >= 2) {
          currCredits += item.credit;
          totalAvg += item.grade * item.credit;
        }
        else if(item.ghostGrade != -1){
          currCredits += item.credit;
          totalAvg += item.ghostGrade * item.credit;
        }
      }
      catch(_){}
    }
    totalAvg30 = totalAvg / 30;
    totalAvg /= currCredits;
    gradedCredits = currCredits;
  }

  void _setupPayments(){
    _paymentsNotificationList.clear();
    totalMoney = 0;
    //order them
    for (int i = 0; i < paymentsEntries.length; i++){
      for (int j = i; j < paymentsEntries.length; j++){
        if(paymentsEntries[j].dueDateMs < paymentsEntries[i].dueDateMs){
          final tmp = paymentsEntries[i];
          paymentsEntries[i] = paymentsEntries[j];
          paymentsEntries[j] = tmp;
        }
      }
    }

    bool isEmpty = true;
    for(var item in paymentsEntries){
      if(item.completed){
        // "Törölt" counts as completed so it stops nagging, but a cancelled
        // transaction is not money the student ever spent.
        if(!item.isCancelled) totalMoney += item.ammount;
        continue;
      }
      isEmpty = false;
      paymentsList.add(PaymentElementWidget(ammount: item.ammount, dueDateMs: item.dueDateMs, ID: item.ID, name: item.comment, completed: item.completed, status: item.statusLabel, isCancelled: item.isCancelled));
      if(item.dueDateMs > DateTime.now().millisecondsSinceEpoch || item.dueDateMs == 0){
        _paymentsNotificationList.add(item);
      }
    }

    if(_paymentsNotificationList.isNotEmpty){
      Future.delayed(Duration.zero,()async{
        await _setupPaymentsNotification(_paymentsNotificationList);
      });
    }

    if(isEmpty){
      paymentsList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().paymentPage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
    }
  }

  Widget _getSeparatorLine(String text, {bool expired = false}){
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 30),
            color: expired ? AppColors.getTheme().errorRed.withValues(alpha: .3) : AppColors.getTheme().textColor.withValues(alpha: .3),
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: expired ? AppColors.getTheme().errorRed.withValues(alpha: .6) : AppColors.getTheme().textColor.withValues(alpha: .6),
              fontWeight: FontWeight.w600,
              fontSize: 14
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 30),
            color: expired ? AppColors.getTheme().errorRed.withValues(alpha: .3) : AppColors.getTheme().textColor.withValues(alpha: .3),
          ),
        ),
      ],
    );
  }

  void _setupPeriods(){
    _periodsNotificationList.clear();
    //order them
    for (int i = 0; i < periodEntries.length; i++){
      for (int j = i; j < periodEntries.length; j++){
        if(periodEntries[j].startEpoch < periodEntries[i].startEpoch){
          final tmp = periodEntries[i];
          periodEntries[i] = periodEntries[j];
          periodEntries[j] = tmp;
        }
      }
    }

    int prevSemester = -1;

    List<api.PeriodEntry> expiredPeriods = [];
    bool hasFuturePeriodLine = false;
    //Map<String, List<api.PeriodType>> values = Map<String, List<api.PeriodType>>.identity();
    for(var item in periodEntries){
      if(item.isActive){
        countActivePeriods++;
      }
      else if(item.endEpoch > DateTime.now().millisecondsSinceEpoch){
        if(!hasFuturePeriodLine){
          hasFuturePeriodLine = true;
          periodList.add(
              const Padding(padding: EdgeInsets.only(top: 10))
          );
          periodList.add(
              _getSeparatorLine(AppStrings.getLanguagePack().topheader_periods_FutureText)
          );
        }
        countFuturePeriods++;
      }
      else{
        countExpiredPeriods++;
      }

      final starttime = DateTime.fromMillisecondsSinceEpoch(item.startEpoch);
      final endtime = DateTime.fromMillisecondsSinceEpoch(item.endEpoch);
      final now = DateTime.now().millisecondsSinceEpoch;
      if(now > endtime.millisecondsSinceEpoch){
        expiredPeriods.add(item);
        continue; // expired
      }
      if(prevSemester == -1 && countActivePeriods != 0){
        prevSemester = item.partofSemester;
        periodList.add(
            const Padding(padding: EdgeInsets.only(top: 10))
        );
        periodList.add(
            _getSeparatorLine(AppStrings.getLanguagePack().topheader_periods_ActiveText)
        );
      }
      else if(item.partofSemester != prevSemester){
        prevSemester = item.partofSemester;
      }
      if(!item.isActive){ // exclude today
        _periodsNotificationList.add(item);
      }
      periodList.add(priods.PeriodsElementWidget(
        displayName: api.Generic.capitalizePeriodText(item.name),
        formattedStartTime: '${api.Generic.monthToText(starttime.month)}. ${starttime.day}.',
        formattedStartTimeYear: '${starttime.year}',
        formattedEndTime: '${api.Generic.monthToText(endtime.month)}. ${endtime.day}.',
        formattedEndTimeYear: '${endtime.year}',
        isActive: item.isActive,
        periodType: item.type,
        startTime: item.startEpoch,
        endTime: (DateTime.fromMillisecondsSinceEpoch(item.endEpoch).millisecondsSinceEpoch),
        expired: false,
      ));
      if(currentSemester == -1) {
        currentSemester = item.partofSemester;
      }
    }

    if(expiredPeriods.isNotEmpty){
      periodList.add(
          const Padding(padding: EdgeInsets.only(top: 10))
      );

      periodList.add(
          _getSeparatorLine(AppStrings.getLanguagePack().topheader_periods_ExpiredText, expired: true)
      );
    }
    
    for(var item in expiredPeriods){
      final starttime = DateTime.fromMillisecondsSinceEpoch(item.startEpoch);
      final endtime = DateTime.fromMillisecondsSinceEpoch(item.endEpoch);
      periodList.add(priods.PeriodsElementWidget(
        displayName: api.Generic.capitalizePeriodText(item.name),
        formattedStartTime: '${api.Generic.monthToText(starttime.month)}. ${starttime.day}.',
        formattedStartTimeYear: '${starttime.year}',
        formattedEndTime: '${api.Generic.monthToText(endtime.month)}. ${endtime.day}.',
        formattedEndTimeYear: '${endtime.year}',
        isActive: item.isActive,
        periodType: item.type,
        startTime: item.startEpoch,
        endTime: (DateTime.fromMillisecondsSinceEpoch(item.endEpoch).millisecondsSinceEpoch),
        expired: true,
      ));
    }

    if(_periodsNotificationList.isNotEmpty){
      Future.delayed(Duration.zero,()async{
        await _setupPeriodsNotification(_periodsNotificationList);
      });
    }

    if(periodEntries.isEmpty){
      periodList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().periodPage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
    }
  }

  void _setupMails({bool clearLoader = false}){
    if(mailEntries.isEmpty){
      mailList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().messagePage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
    }

    if(clearLoader && mailList.isNotEmpty){
      mailList.removeAt(mailList.length-1);
    }

    int idx = 0;
    var prevDate = DateTime.now();
    mailList.add(
        const Padding(padding: EdgeInsets.only(top: 10))
    );
    for(var item in mailEntries){
      allLoadedMailCount++;
      if(mailSearchQuery.isNotEmpty){
        final q = mailSearchQuery.toLowerCase();
        if(!item.subject.toLowerCase().contains(q) && !item.senderName.toLowerCase().contains(q)){
          continue;
        }
      }
      final date = DateTime.fromMillisecondsSinceEpoch(item.sendDateMs);
      final currDate = DateTime(date.year, date.month, date.day);
      if(mailEntries.length != ++idx && prevDate != currDate){
        prevDate = currDate;
        mailList.add(_getSeparatorLine('${currDate.year}. ${api.Generic.monthToText(date.month)}. ${date.day}.'));
      }
      mailList.add(MailElementWidget(subject: item.subject, details: item.detail, sender: item.senderName, sendTime: item.sendDateMs, isRead: item.isRead, mailID: item.ID, callback: (element){
        setState(() {
          if(element.isRead){
            return;
          }
          final indx = mailList.indexOf(element);
          mailList.insert(indx, MailElementWidget(subject: element.subject, details: element.details, sender: element.sender, sendTime: element.sendTime, isRead: true, mailID: element.mailID, callback: (_){}));
          mailList.remove(element);
          unreadMailCount--;
          storage.saveInt('CachedMailsUnread', unreadMailCount);
          Future.delayed(Duration.zero, ()async{
            await api.MailRequest.setMailRead(MailPopupDisplayTexts.mailID);
            if(currentMailPage == 1){
              storage.DataCache.setHasCachedMail(0);
            }
          });
        });
      },));
    }
  }

  Future<void> stepCalendarBack() async{
    if(!canStepCalendarBack){
      return;
    }
    currentWeekOffset--;
    AppHaptics.lightImpact();
    await onCalendarRefresh(true);
  }
  Future<void> stepCalendarForward() async{
    if(!canStepCalendarForward){
      return;
    }
    currentWeekOffset++;
    AppHaptics.lightImpact();
    await onCalendarRefresh(true);
  }
  Future<void> jumpToCurrentWeek() async{
    if(currentWeekOffset == 1){
      return;
    }
    currentWeekOffset = 1;
    await onCalendarRefresh(false);
  }

  // currentWeekOffset is 1 for the current week, so this allows a year either way.
  static const int minWeekOffset = -51;
  static const int maxWeekOffset = 53;
  bool get canStepCalendarBack => currentWeekOffset > minWeekOffset;
  bool get canStepCalendarForward => currentWeekOffset < maxWeekOffset;

  Future<List<api.CalendarEntry>> fetchCalendarToList(int offset) async{
    //final userOffset = storage.DataCache.getUserWeekOffset()!;
    final request = await api.CalendarRequest.makeCalendarRequest(api.CalendarRequest.getCalendarOneWeekJSON(storage.DataCache.getUsername()!, storage.DataCache.getPassword()!, currentWeekOffset + offset));
    final list = api.CalendarRequest.getCalendarEntriesFromJSON(request);
    //return list2;
    return list;
  }

  Future<void> fetchCalendar({bool force = false}) async{
    if(storage.DataCache.getHasICSFile() ?? false){
      final epochStart = api.CalendarRequest.weekStartFor(currentWeekOffset).millisecondsSinceEpoch;
      final epochEnd = api.CalendarRequest.weekEndFor(currentWeekOffset).millisecondsSinceEpoch;

      calendarEntries.clear();
      calendarEntries = ICSCalendar.getCalendarInterval(epochStart, epochEnd);

      storage.DataCache.setHasCachedFirstWeekEpoch(1);
      return;
    }
    bool hasCachedCalendar = storage.DataCache.getHasCachedCalendar() ?? false;
    final cacheTime = await storage.getString('CalendarCacheTime');

    if(!hasCachedCalendar && !storage.DataCache.getHasNetwork()){
      return;
    }
    // if we had a save, and the cached value is not older than a day, we can load that up
    if(!force && hasCachedCalendar && cacheTime != null && (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) < const Duration(hours: 24).inMilliseconds && !storage.DataCache.getIsDemoAccount()!) {
      final len = await storage.getInt('CachedCalendarLength');
      for(int i = 0; i < len!; i++){
        final calEntry = await storage.getString('CachedCalendar_$i');
        calendarEntries.add(api.CalendarEntry('0', '0', 'NULL', 'NULL', false).fillWithExisting(calEntry!));
      }
      storage.DataCache.setHasCachedFirstWeekEpoch(1);
      //auto get details
      api.CalendarRequest.fillMissingDetails(calendarEntries, () {
        if (mounted) setState(() {});
      });

      Future.delayed(Duration.zero,()async{
        await _setupClassesNotifications(_classesNotificationList);
      });
      return;
    }
    //otherwise, just fetch again
    //final isWeekend = DateTime.now().weekday == DateTime.saturday || DateTime.now().weekday == DateTime.sunday ? 1 : 0;
    //final userOffset = storage.DataCache.getUserWeekOffset()!;
    final request = await api.CalendarRequest.makeCalendarRequest(api.CalendarRequest.getCalendarOneWeekJSON(storage.DataCache.getUsername()!, storage.DataCache.getPassword()!, currentWeekOffset));
    calendarEntries.clear();
    final list = api.CalendarRequest.getCalendarEntriesFromJSON(request);
    //calendarEntries = list2;
    calendarEntries = list;

    // Only the current week is cached, so that is the only one worth restoring.
    if(calendarEntries.isEmpty && currentWeekOffset == 1 && (storage.DataCache.getHasCachedCalendar() ?? false)){
      final len = await storage.getInt('CachedCalendarLength') ?? 0;
      for(int i = 0; i < len; i++){
        final entry = await storage.getString('CachedCalendar_$i');
        if(entry == null) continue;
        calendarEntries.add(api.CalendarEntry('0', '0', 'NULL', 'NULL', false).fillWithExisting(entry));
      }
    }

    //automatic room finder lol
    api.CalendarRequest.fillMissingDetails(calendarEntries, () {
      if (mounted) setState(() {});
    });
    //autofinder end

    if(currentWeekOffset == 1) {
      storage.saveInt('CachedCalendarLength', calendarEntries.length);
      //cache calendar
      for (int i = 0; i < calendarEntries.length; i++) {
        storage.saveString('CachedCalendar_$i', calendarEntries[i].toString());
      }
      final now = DateTime.now();
      storage.saveString('CalendarCacheTime', DateTime(now.year, now.month, now.day, 0, 0, 0).toString());
      Future.delayed(Duration.zero,()async{
        await _setupClassesNotifications(_classesNotificationList);
      });
    }
    storage.DataCache.setHasCachedCalendar(1);
  }

  Future<void> _loadMarkbookFromCache() async{
    final len = await storage.getInt('CachedMarkbookLength') ?? 0;
    for(int i = 0; i < len; i++){
      final entry = await storage.getString('CachedMarkbook_$i');
      if(entry == null) continue;
      markbookEntries.add(api.Subject(false, 0, 'NULL', 0, 0, 0).fillWithExisting(entry));
    }
  }

  Future<void> fetchMarkbook({bool force = false}) async{
    bool hasCachedMarkbook= storage.DataCache.getHasCachedMarkbook() ?? false;
    final cacheTime = await storage.getString('MarkbookCacheTime');

    if(!hasCachedMarkbook && !storage.DataCache.getHasNetwork()){
      return;
    }

    // if we had a save, and the cached value is not older than a day, we can load that up
    if(!force && hasCachedMarkbook && cacheTime != null && (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) < const Duration(hours: 24).inMilliseconds && !storage.DataCache.getIsDemoAccount()!) {
      await _loadMarkbookFromCache();
      return;
    }

    //otherwise, just fetch again
    final request = await api.MarkbookRequest.getMarkbookSubjects();
    if(request == null || request.isEmpty){
      // Stale beats empty: a failed request should not wipe what the user could still read.
      markbookEntries = [];
      await _loadMarkbookFromCache();
      return;
    }

    // Read the previous grades before the cache below overwrites them.
    final previousGrades = await GradeAlerts.readCachedGrades();

    markbookEntries = request;
    await GradeAlerts.writeCache(markbookEntries);
    await GradeAlerts.notify(GradeAlerts.findNewGrades(previousGrades, markbookEntries));
  }

  Future<void> _loadPaymentsFromCache() async{
    final len = await storage.getInt('CachedPaymentsLength') ?? 0;
    for(int i = 0; i < len; i++){
      final entry = await storage.getString('CachedPayments_$i');
      if(entry == null) continue;
      paymentsEntries.add(api.CashinEntry(0, 0, 'NULL', "", 'NULL').fillWithExisting(entry));
    }
  }

  Future<void> fetchPayments({bool force = false}) async{
    bool hasCachedPayments = storage.DataCache.getHasCachedPayments() ?? false;

    final cacheTime = await storage.getString('PaymentsCacheTime');

    if(!hasCachedPayments && !storage.DataCache.getHasNetwork()){
      return;
    }

    // if we had a save, and the cached value is not older than a day, we can load that up
    if(!force && hasCachedPayments && cacheTime != null && (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) < const Duration(hours: 24).inMilliseconds && !storage.DataCache.getIsDemoAccount()!) {
      await _loadPaymentsFromCache();
      return;
    }

    //otherwise, just fetch again
    final request = await api.CashinRequest.getAllCashins();
    if(request == null || request.isEmpty){
      await _loadPaymentsFromCache();
      return;
    }
    paymentsEntries = request;

    storage.saveInt('CachedPaymentsLength', paymentsEntries.length);
    //cache calendar
    for (int i = 0; i < paymentsEntries.length; i++) {
      storage.saveString('CachedPayments_$i', paymentsEntries[i].toString());
    }
    storage.saveString('PaymentsCacheTime', DateTime.now().toString());

    storage.DataCache.setHasCachedPayments(1);
  }

  Future<void> _loadPeriodsFromCache() async{
    final len = await storage.getInt('CachedPeriodsLength') ?? 0;
    for(int i = 0; i < len; i++){
      final entry = await storage.getString('CachedPeriods_$i');
      if(entry == null) continue;
      periodEntries.add(api.PeriodEntry("ERROR", 0, 0, 0).fillWithExisting(entry));
    }
  }

  Future<void> fetchPeriods({bool force = false}) async{
    bool hasCachedPeriods = storage.DataCache.getHasCachedPeriods() ?? false;

    final cacheTime = await storage.getString('PeriodsCacheTime');

    if(!hasCachedPeriods && !storage.DataCache.getHasNetwork()){
      return;
    }

    // if we had a save, and the cached value is not older than a day, we can load that up
    if(!force && hasCachedPeriods && cacheTime != null && (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) < const Duration(hours: 24).inMilliseconds && !storage.DataCache.getIsDemoAccount()!) {
      await _loadPeriodsFromCache();
      return;
    }

    //otherwise, just fetch again
    final request = await api.PeriodsRequest.getPeriods();
    if(request == null || request.isEmpty){
      await _loadPeriodsFromCache();
      return;
    }
    periodEntries = request;

    storage.saveInt('CachedPeriodsLength', periodEntries.length);
    //cache calendar
    for (int i = 0; i < periodEntries.length; i++) {
      storage.saveString('CachedPeriods_$i', periodEntries[i].toString());
    }
    storage.saveString('PeriodsCacheTime', DateTime.now().toString());

    storage.DataCache.setHasCachedPeriods(1);
  }

  int currentMailPage = 1;
  String mailSearchQuery = '';
  bool currentMailLoadingDebounce = false;
  late ScrollController currentMailPageController;
  Future<void> _loadMailsFromCache() async{
    final len = await storage.getInt('CachedMailsLength') ?? 0;
    unreadMailCount = (await storage.getInt('CachedMailsUnread')) ?? 0;
    totalMailCount = (await storage.getInt('CachedMailsTotal')) ?? 0;
    for(int i = 0; i < len; i++){
      final entry = await storage.getString('CachedMails_$i');
      if(entry == null) continue;
      mailEntries.add(api.MailEntry("ERROR", "ERROR", "ERROR", 0, false, "").fillWithExisting(entry));
    }
  }

  Future<void> fetchMails({bool force = false, bool ignoreCacheAge = false})async{
    bool hasCachedMails = storage.DataCache.getHasCachedMail() ?? false;

    final cacheTime = await storage.getString('MailCacheTime');

    if(!hasCachedMails && !storage.DataCache.getHasNetwork() && !force){
      return;
    }

    if(!force && !ignoreCacheAge && hasCachedMails && cacheTime != null && (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) < const Duration(hours: 24).inMilliseconds) {
      await _loadMailsFromCache();
      return;
    }

    final request = await api.MailRequest.getMails(currentMailPage);
    if(request == null || request.isEmpty){
      if(currentMailPage == 1){
        await _loadMailsFromCache();
      }
      return;
    }

    // Only the first page is comparable; later pages are older mail that would
    // all look new against a cache holding just page one.
    final previousMailIds = currentMailPage == 1
        ? await MailAlerts.readCachedMailIds()
        : <String>{};

    mailEntries = request;
    //debug.log(request!.toString());

    if(force){
      return;
    }
    
    final nums = await api.MailRequest.getUnreadMessagesAndAllMessages();
    unreadMailCount = nums[0];
    totalMailCount = nums[1];

    await MailAlerts.writeCache(mailEntries, nums[0], nums[1]);

    if(currentMailPage == 1){
      await MailAlerts.notify(MailAlerts.findNewMails(previousMailIds, mailEntries));
    }
  }

  Timer? _calendarTimer;

  bool _calendarDebounce = false;
  bool isLoadingCalendar = true;

  bool _noRefreshCalendar = false;

  Future<void> onCalendarRefresh(bool isPaging) async{
    if(_noRefreshCalendar){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshCalendar = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _calendarDebounce || _noRefreshCalendar){
      return;
    }
    if(_calendarTimer != null){
      _calendarTimer!.cancel();
    }
    clearCalendar();
    setupCalendarController(false, true);
    _calendarTimer = Timer(Duration(milliseconds: isPaging ? 500 : 0), () async {
      _calendarDebounce = true;
      setState(() {
        canDoCalendarPaging = false;
        isLoadingCalendar = true;
      });
      // Cached rows stay valid; a failed refresh should not discard readable data.
      await fetchCalendar(force: true);
      setupCalendar(false);
      _calendarDebounce = false;
      setState(() {
        isLoadingCalendar = false;
      });
    });
  }

  bool _markbookDebounce = false;
  bool _noRefreshMarkbook = false;
  Future<void> onMarkbookRefresh() async{
    if(_noRefreshMarkbook){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshMarkbook = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _markbookDebounce || _noRefreshMarkbook){
      return;
    }
    _markbookDebounce = true;
    clearMarkbook();
    // The cached rows stay valid: clearing the flag here meant a failed refresh
    // permanently discarded readable data.
    await fetchMarkbook(force: true);
    setupMarkbook();
    _markbookDebounce = false;
    refreshLastUpdated();
  }

  bool _paymentsDebounce = false;
  bool _noRefreshPayments = false;

  Future<void> onPaymentsRefresh() async{
    if(_noRefreshPayments){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshPayments = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _paymentsDebounce || _noRefreshPayments){
      return;
    }
    _paymentsDebounce = true;
    clearPayments();
    await fetchPayments(force: true);
    setupPayments();
    _paymentsDebounce = false;
    refreshLastUpdated();
  }

  bool _periodsDebounce = false;
  bool _noRefreshPeriods = false;

  Future<void> onPeriodsRefresh()async{
    if(_noRefreshPeriods){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshPeriods = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _periodsDebounce || _noRefreshPeriods){
      return;
    }
    _periodsDebounce = true;
    clearPeriods();
    await fetchPeriods(force: true);
    setupPeriods();
    _periodsDebounce = false;
    refreshLastUpdated();
  }

  bool _mailsDebounce = false;
  bool _noRefreshMail = false;

  Future<void> onMailRefresh()async{
    if(_noRefreshMail){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshMail = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _mailsDebounce || _noRefreshMail){
      return;
    }
    _mailsDebounce = true;
    clearMails();
    await fetchMails(ignoreCacheAge: true);
    setupMails();
    _mailsDebounce = false;
    refreshLastUpdated();
  }

  DateTime getClosestMondayTo(DateTime time){
    if(time.weekday == DateTime.monday){
      return time;
    }
    final result = time.add(Duration(days: 8 - time.weekday));
    return result;
  }

  int calcPassedWeeks() {
    final epochsemester = storage.DataCache.getFirstWeekEpoch()!;
    final now = DateTime.now();
    final determiner = epochsemester > 0 ? DateTime.fromMillisecondsSinceEpoch(epochsemester) : getClosestMondayTo(DateTime(now.year - (now.millisecondsSinceEpoch > DateTime(now.year, 9, 1).millisecondsSinceEpoch ? 0 : 1), 9, 1));
    final yearlessNow = DateTime(1, now.month, now.day);
    final sepOne = DateTime(yearlessNow.year - 1, determiner.month, determiner.day); // first week

    final timepassSinceSepOne = Duration(milliseconds: (yearlessNow.millisecondsSinceEpoch - sepOne.millisecondsSinceEpoch));
    final weeksPassed = timepassSinceSepOne.inDays / 7;
    final userOffset = storage.DataCache.getUserWeekOffset()!;
    return wrapStudyWeek((weeksPassed.floor() % 52) + (currentWeekOffset + userOffset));
  }

  // Study weeks cycle 1..52, so paging past the end of the year rolls back to week 1
  // instead of running off the scale.
  static int wrapStudyWeek(int week) => ((week - 1) % 52 + 52) % 52 + 1;
  

  @override
  void dispose() {
    super.dispose();
    calendarEntries.clear();
    mondayCalendar.clear();
    tuesdayCalendar.clear();
    wednessdayCalendar.clear();
    thursdayCalendar.clear();
    fridayCalendar.clear();
    saturdayCalendar.clear();
    sundayCalendar.clear();
    markbookEntries.clear();
    markbookList.clear();
    calendarTabController.dispose();
    paymentsEntries.clear();
    paymentsList.clear();
    periodList.clear();
    periodEntries.clear();
    mailList.clear();
    mailEntries.clear();
    _connectivitySub?.cancel();
    currentMailPageController.dispose();
    blurController.dispose();
  }

  static Container getSeparatorLine(BuildContext context){
    return Container(
      width: MediaQuery.of(context).size.width / 1.2,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.getTheme().textColor.withValues(alpha: 0),
            AppColors.getTheme().textColor.withValues(alpha: 0.2),
            AppColors.getTheme().textColor.withValues(alpha: 0.4),
            AppColors.getTheme().textColor.withValues(alpha: 0.4),
            AppColors.getTheme().textColor.withValues(alpha: 0.2),
            AppColors.getTheme().textColor.withValues(alpha: 0),
          ]
        ),
      ),
    );
  }

  void switchView(int to){
    if(currentView == to){
      return;
    }
    setState(() {
      currentView = to;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        drawer: AppDrawer(
            loggedInUsername: storage.DataCache.getUsername()!,
            loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
        ),
      body: SafeArea(
        child: Column(
        children: [
          if (storage.DataCache.getIsDemoAccount() ?? false) const DemoModeBanner(),
          OfflineBanner(lastUpdated: _lastUpdated[currentView]),
          Expanded(
            child: Stack(
        children: [
          Visibility(
              visible: currentView == 0,
              child: CalendarPageWidget(homePage: this, greetText: calendarGreetText, calendarTabs: calendarTabs, calendarTabViews: calendarTabViews)
          ),
          Visibility(
              visible: currentView == 1,
              child: MarkbookPageWidget(homePage: this, totalCredits: totalCredits, totalAvg: totalAvg, totalAvg30: totalAvg30,)
          ),
          Visibility(
              visible: currentView == 2,
              child: PaymentsPageWidget(homePage: this, totalMoney: totalMoney)
          ),
          Visibility(
            visible: currentView == 3,
            child: PeriodsPageWidget(homePage: this, currentSemester: currentSemester),
          ),
          Visibility(
            visible: currentView == 4,
            child: MailsPageWidget(homePage: this),
          ),
          Visibility(
            visible: _showBlur,
            child: AnimatedBuilder(
              animation: blurController,
              builder: (context, widget) {
                return Positioned.fill(
                  child: BackdropFilter(
                     filter: ImageFilter.blur(sigmaX: blurAnimation.value * 15, sigmaY: blurAnimation.value * 15),
                     child: Container(
                       color: Colors.black.withValues(alpha: blurAnimation.value * 0.4),
                     ),
                   ),
                );
              },
            ),
          ),
        ],
      ),
          ),
        ],
      ),
      )
    );
  }
}

class CalendarPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final String greetText;
  final List<Widget> calendarTabs;
  final List<Widget> calendarTabViews;
  const CalendarPageWidget({super.key, required this.homePage, required this.greetText, required this.calendarTabs, required this.calendarTabViews});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      drawer: AppDrawer(
          loggedInUsername: storage.DataCache.getUsername()!,
          loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
      ),
      body: SafeArea(
        child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Calendar, smallHintText: greetText, loggedInUsername: storage.DataCache.getUsername()!, loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
              Container(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
                color: AppColors.getTheme().rootBackground,
                width: MediaQuery.of(context).size.width,
                child: TabBar(
                  tabs: calendarTabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  automaticIndicatorColorAdjustment: true,
                  controller: homePage.calendarTabController,
                  enableFeedback: true,
                  physics: const BouncingScrollPhysics(
                    decelerationRate: ScrollDecelerationRate.fast,
                  ),
                  indicator: BoxDecoration(
                    color: AppColors.getTheme().textColor.withValues(alpha: .1),
                    borderRadius: const BorderRadius.all(Radius.circular(26))
                  ),
                  onTap: (index){
                    return;
                  },
                ),
              ),
              HomePageState.getSeparatorLine(context),
              Container(
                width: MediaQuery.of(context).size.width,
                child: t_table.WeekoffseterElementWidget(
                  week: homePage.weeksSinceStart,
                  from: homePage.calendarEntries.isEmpty ? null : DateTime.fromMillisecondsSinceEpoch(homePage.calendarEntries[0].startEpoch),
                  to: homePage.calendarEntries.isEmpty ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(homePage.calendarEntries[homePage.calendarEntries.length - 1].endEpoch),
                  onBackPressed: homePage.stepCalendarBack,
                  onForwardPressed: homePage.stepCalendarForward,
                  onHomePressed: homePage.jumpToCurrentWeek,
                  canDoPaging: homePage.canDoCalendarPaging,
                  homePage: homePage,
                  isLoading: homePage.isLoadingCalendar,
                  weekStart: api.CalendarRequest.weekStartFor(homePage.currentWeekOffset),
                  weekEnd: api.CalendarRequest.weekEndFor(homePage.currentWeekOffset),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: homePage.calendarTabController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: calendarTabViews,
                ),
              ),
              HomePageState.getSeparatorLine(context),
              bottomnav.BottomNavigatorWidget(homePage: homePage),
            ],
          ),
          ],
        ),
      ),
    );
  }
}

class MarkbookPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final int totalCredits;
  final double totalAvg;
  final double totalAvg30;
  const MarkbookPageWidget({super.key, required this.homePage, required this.totalCredits, required this.totalAvg, required this.totalAvg30});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage._confettiRefreshRetrigger = true;
    homePage.onMarkbookRefresh();
  }

  List<Widget> _getConfetti(BuildContext context){
    if(homePage._confettiList.isNotEmpty){
      return homePage._confettiList;
    }
    final confettiAmount = 55 + Random().nextInt(234243) % 30;
    for(int i = 0; i < confettiAmount; i++){
      final randomRed = 0xCC000000 + Random().nextInt(0x33000000);
      final randomGreen = 0x00CC0000 + Random().nextInt(0x0033000);
      final randomBlue = 0x0000CC00 + Random().nextInt(0x00003300);
      final alpha = 0x000000FF;
      final added = randomRed + randomBlue + randomGreen + alpha;
      final confetti = ConfettiHelper(
        confettiColor: Color(added),
        startOffset: Offset(lerpDouble(0, MediaQuery.of(context).size.width, Random().nextDouble() % 0.9999)!, lerpDouble(-MediaQuery.of(context).size.height, -50, Random().nextDouble() % 0.9999)!),
        startRotation: Random().nextDouble() % 360.0,
        rotationMultiplier: -60 + Random().nextInt(60*2),
        startSize: Size((8 + Random().nextInt(12)).toDouble(), (8 + Random().nextInt(12)).toDouble()),
        offsetMultiplier: -200 + Random().nextInt(200*2),
        startRadius: BorderRadius.only(topLeft: Radius.circular(4 + 12 * Random().nextDouble() % 0.999), topRight: Radius.circular(4 + 12 * Random().nextDouble() % 0.999), bottomRight: Radius.circular(4 + 12 * Random().nextDouble() % 0.999), bottomLeft: Radius.circular(4 + 12 * Random().nextDouble() % 0.999))
      );
      homePage._confettiHelperList.add(confetti);
      homePage._confettiList.add(
        IgnorePointer(
          child: AnimatedBuilder(
            animation: homePage._confettiController,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(
                    confetti.startOffset.dx + confetti.offsetMultiplier * homePage._confettiAnimation.value,
                    lerpDouble(confetti.startOffset.dy, confetti.startOffset.dy + MediaQuery.of(context).size.height * 2 + (confetti.offsetMultiplier < 0 ? -confetti.offsetMultiplier : confetti.offsetMultiplier) * 6 * homePage._confettiAnimation.value, homePage._confettiAnimation.value)!
                ),
                child: Transform.rotate(
                  angle: confetti.startRotation + confetti.rotationMultiplier * homePage._confettiAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: confetti.confettiColor,
                      borderRadius: confetti.startRadius
                    ),
                    width: confetti.startSize.width,
                    height: confetti.startSize.height,
                  ),
                ),
              );
            }
          ),
        )
      );
    }
    return homePage._confettiList;
  }

  @override
  Widget build(BuildContext context){
    if(homePage._confettiCanBePlayed && homePage._confettiCanGetFreshAnim && homePage._confettiRefreshRetrigger){
      homePage._confettiCanGetFreshAnim = false;
      homePage._confettiRefreshRetrigger = false;
      homePage._confettiController.forward().whenComplete((){
        homePage._confettiCanGetFreshAnim = true;
        homePage._confettiList.clear();
        homePage._confettiHelperList.clear();
        homePage._confettiController.reset();
      });
    }
    return Scaffold(
      drawer: AppDrawer(
          loggedInUsername: storage.DataCache.getUsername()!,
          loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
      ),
      body: SafeArea(
        child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Subjects, smallHintText: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topheader_subjects_CreditsInSemester, [totalCredits]), loggedInUsername: storage.DataCache.getUsername()!, loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
              HomePageState.getSeparatorLine(context),
              Expanded(
                  child: RefreshIndicator(
                    onRefresh: onRefresh,
                    child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Visibility(
                              visible: homePage.markbookList.isNotEmpty,
                              child: Container(
                                margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 12),
                                width: MediaQuery.of(context).size.width,
                                decoration: BoxDecoration(
                                  color: AppColors.getTheme().textColor.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(20),
                                  //border: Border.all(color: Colors.white.withOpacity(.2), width: 1)
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    EmojiRichText(
                                      text: AppStrings.getStringWithParams(AppStrings.getLanguagePack().markbookPage_AverageDisplay, [totalAvg.isNaN || totalAvg <= 0 ? AppStrings.getLanguagePack().markbookPage_NoGrades : totalAvg.toStringAsFixed(2), api.Generic.reactionForAvg(totalAvg)]),                                      defaultStyle: TextStyle(
                                        color: AppColors.getTheme().onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.0,
                                      ),
                                      emojiStyle: TextStyle(
                                          color: AppColors.getTheme().onPrimaryContainer,
                                          fontSize: 14.0,
                                          fontFamily: "Noto Color Emoji"
                                      ),
                                    ),
                                    EmojiRichText(
                                      text: AppStrings.getStringWithParams(AppStrings.getLanguagePack().markbookPage_AverageScholarshipDisplay, [totalAvg30.isNaN || totalAvg30 <= 0 ? AppStrings.getLanguagePack().markbookPage_NoGrades : totalAvg30.toStringAsFixed(2), api.Generic.reactionForAvg(totalAvg30)]),
                                      defaultStyle: TextStyle(
                                        color: AppColors.getTheme().onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.0,
                                      ),
                                      emojiStyle: TextStyle(
                                          color: AppColors.getTheme().onPrimaryContainer,
                                          fontSize: 14.0,
                                          fontFamily: "Noto Color Emoji"
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Visibility(
                              visible: homePage.markbookList.isNotEmpty,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: (){
                                      AppHaptics.lightImpact();
                                      showAverageCalculator(context, totalAvg, homePage.gradedCredits);
                                    },
                                    icon: Icon(Icons.calculate_outlined, size: 18, color: AppColors.getTheme().secondary),
                                    label: Text(
                                      AppStrings.getCurrentLangCode() == 'hu' ? 'Átlagszámító' : 'Average calculator',
                                      style: TextStyle(color: AppColors.getTheme().secondary, fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: AppColors.getTheme().secondary.withValues(alpha: 0.4)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: homePage.markbookList.isNotEmpty ? AppColors.getTheme().textColor.withValues(alpha: 0.03) : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.max,
                                children: homePage.markbookList.isNotEmpty ? homePage.markbookList : <Widget>[
                                  Center(
                                    child: SizedBox(
                                      height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      child: CircularProgressIndicator(
                                      color: AppColors.getTheme().textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                        fontWeight: FontWeight.w300,
                                        fontSize: 10
                                    ),
                                  )
                                ]
                              ),
                            ),
                          ],
                        ),
                    )
                  )
              ),
              HomePageState.getSeparatorLine(context),
              bottomnav.BottomNavigatorWidget(homePage: homePage),
            ],
          ),
          Stack(
            children: _getConfetti(context),
          )
        ],
      ),
      ),
    );
  }
}

class ConfettiHelper{
  final Color confettiColor;
  final Offset startOffset;
  final double startRotation;
  final int rotationMultiplier;
  final Size startSize;
  final int offsetMultiplier;
  final BorderRadius startRadius;

  const ConfettiHelper({required this.startRadius, required this.confettiColor, required this.startOffset, required this.startRotation, required this.rotationMultiplier, required this.startSize, required this.offsetMultiplier});
}

class PaymentsPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final int totalMoney;
  const PaymentsPageWidget({super.key, required this.homePage, required this.totalMoney});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage.onPaymentsRefresh();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
        drawer: AppDrawer(
            loggedInUsername: storage.DataCache.getUsername()!,
            loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
        ),
      body: SafeArea(
        child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Payments, smallHintText: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topheader_payments_TotalMoneySpent, [totalMoney]), loggedInUsername: storage.DataCache.getUsername()!, loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
              HomePageState.getSeparatorLine(context),
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: onRefresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                        child: Container(
                          margin: const EdgeInsets.all(15),
                          width: MediaQuery.of(context).size.width,
                          decoration: BoxDecoration(
                            color: homePage.paymentsList.isNotEmpty ? AppColors.getTheme().textColor.withValues(alpha: 0.03) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              mainAxisSize: MainAxisSize.max,
                              children: homePage.paymentsList.isNotEmpty ? homePage.paymentsList : <Widget>[
                                Center(
                                  child: SizedBox(
                                    height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                    width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                    child: CircularProgressIndicator(
                                      color: AppColors.getTheme().textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                      fontWeight: FontWeight.w300,
                                      fontSize: 10
                                  ),
                                )
                              ]
                          ),
                        ),
                      )
                  )
              ),
              HomePageState.getSeparatorLine(context),
              bottomnav.BottomNavigatorWidget(homePage: homePage),
            ],
          ),
        ],
      ),
    )
    );
  }
}

class PeriodsPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final int currentSemester;
  const PeriodsPageWidget({super.key, required this.homePage, required this.currentSemester});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage.onPeriodsRefresh();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
        drawer: AppDrawer(
            loggedInUsername: storage.DataCache.getUsername()!,
            loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
        ),
        body: SafeArea(
          child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Periods, smallHintText: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topheader_periods_MainHeader, [homePage.countActivePeriods, AppStrings.getLanguagePack().topheader_periods_ActiveText, homePage.countFuturePeriods, AppStrings.getLanguagePack().topheader_periods_FutureText, homePage.countExpiredPeriods, AppStrings.getLanguagePack().topheader_periods_ExpiredText]), loggedInUsername: storage.DataCache.getUsername()!, loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
                HomePageState.getSeparatorLine(context),
                Expanded(
                    child: RefreshIndicator(
                        onRefresh: onRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          child: Container(
                            margin: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: homePage.periodList.isNotEmpty ? AppColors.getTheme().textColor.withValues(alpha: .03) : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.max,
                                children: homePage.periodList.isNotEmpty ? homePage.periodList : <Widget>[
                                  Center(
                                    child: SizedBox(
                                      height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      child: CircularProgressIndicator(
                                        color: AppColors.getTheme().textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                        fontWeight: FontWeight.w300,
                                        fontSize: 10
                                    ),
                                  )
                                ]
                            ),
                          ),
                        )
                    )
                ),
                HomePageState.getSeparatorLine(context),
                bottomnav.BottomNavigatorWidget(homePage: homePage),
              ],
            ),
          ],
        ),
        ),
        floatingActionButton: null
    );
  }
}

class MailsPageWidget extends StatelessWidget{
  final HomePageState homePage;
  const MailsPageWidget({super.key, required this.homePage});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage.onMailRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        drawer: AppDrawer(
            loggedInUsername: storage.DataCache.getUsername()!,
            loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
        ),
        body: SafeArea(
          child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Messages, smallHintText: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topheader_messages_UnreadMessages, [homePage.unreadMailCount]), loggedInUsername: storage.DataCache.getUsername()!, loggedInURL: storage.DataCache.getInstituteUrl()!.replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
                HomePageState.getSeparatorLine(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: TextField(
                    style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: AppStrings.getCurrentLangCode() == 'hu' ? 'Keresés tárgyra vagy feladóra' : 'Search subject or sender',
                      hintStyle: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.35), fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.getTheme().textColor.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (v){
                      homePage.mailSearchQuery = v;
                      homePage.setupMails(clear: true);
                    },
                  ),
                ),
                Expanded(
                    child: RefreshIndicator(
                        onRefresh: onRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          controller: homePage.currentMailPageController,
                          child: Container(
                            margin: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: homePage.mailList.isNotEmpty ? AppColors.getTheme().textColor.withValues(alpha: 0.03) : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.max,
                                children: homePage.mailList.isNotEmpty ? homePage.mailList : <Widget>[
                                  Center(
                                    child: SizedBox(
                                      height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      child: CircularProgressIndicator(
                                        color: AppColors.getTheme().textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                        fontWeight: FontWeight.w300,
                                        fontSize: 10
                                    ),
                                  )
                                ]
                            ),
                          ),
                        )
                    )
                ),
                HomePageState.getSeparatorLine(context),
                bottomnav.BottomNavigatorWidget(homePage: homePage),
              ],
            ),
          ],
        ),
        )
    );
  }
}