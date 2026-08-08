import 'dart:developer' as debug;
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'API/api_coms.dart' as api;
import 'grade_alerts.dart';
import 'language.dart';
import 'mail_alerts.dart';
import 'notifications.dart';
import 'storage.dart' as storage;

const String _gradeCheckTask = 'hu.bali0531.nhnk.gradecheck';
const String _gradeCheckUniqueName = 'nhnk-grade-check';

/// Runs in its own isolate with none of the app's statics populated, so anything
/// it touches has to be initialised here first.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher(){
  Workmanager().executeTask((task, inputData) async{
    if(task != _gradeCheckTask){
      return true;
    }
    try{
      WidgetsFlutterBinding.ensureInitialized();
      AppStrings.initialize();
      await storage.DataCache.loadData();

      if(!(storage.DataCache.getNeedGradeNotifications() ?? true)
          && !(storage.DataCache.getNeedMailNotifications() ?? true)) return true;
      if(storage.DataCache.getIsDemoAccount() ?? false) return true;

      final username = storage.DataCache.getUsername();
      final password = storage.DataCache.getPassword();
      if(username == null || username.isEmpty || password == null || password.isEmpty){
        return true;
      }

      var notified = false;

      if(storage.DataCache.getNeedGradeNotifications() ?? true){
        final fresh = await api.MarkbookRequest.getMarkbookSubjects();
        if(fresh != null && fresh.isNotEmpty){
          final previous = await GradeAlerts.readCachedGrades();
          final changed = GradeAlerts.findNewGrades(previous, fresh);

          // Written even when nothing changed, so the next run compares against
          // current data rather than re-reporting the same grade forever.
          await GradeAlerts.writeCache(fresh);

          if(changed.isNotEmpty){
            if(!notified){ await AppNotifications.initializeHeadless(); notified = true; }
            await GradeAlerts.notify(changed);
          }
        }
      }

      if(storage.DataCache.getNeedMailNotifications() ?? true){
        // Page 1 only: the cache holds the newest page, so older pages are not comparable.
        final mails = await api.MailRequest.getMails(1);
        if(mails != null && mails.isNotEmpty){
          final previous = await MailAlerts.readCachedMailIds();
          final fresh = MailAlerts.findNewMails(previous, mails);
          final counts = await api.MailRequest.getUnreadMessagesAndAllMessages();
          await MailAlerts.writeCache(mails, counts[0], counts[1]);

          if(fresh.isNotEmpty){
            if(!notified){ await AppNotifications.initializeHeadless(); notified = true; }
            await MailAlerts.notify(fresh);
          }
        }
      }
    }
    catch(e){
      debug.log('Background grade check failed: $e');
    }
    // Returning false makes WorkManager retry with backoff; a failed poll is not
    // worth the extra wakeups when the next scheduled run is a few hours away.
    return true;
  });
}

class BackgroundWorker{
  /// Selectable intervals in minutes, last entry disables the check. 15 is Android's
  /// hard floor for periodic work -- anything shorter is silently clamped to it.
  static const List<int> intervalSteps = [15, 30, 60, 120, 180, 360, 720, 0];

  /// iOS background refresh needs AppDelegate and Info.plist changes the unsigned
  /// build does not carry, so this stays Android-only for now.
  static bool get isSupported => !kIsWebFallback && Platform.isAndroid;

  static bool _initialised = false;

  static Future<void> _ensureInitialised() async{
    if(_initialised) return;
    await Workmanager().initialize(backgroundCallbackDispatcher);
    _initialised = true;
  }

  static Future<void> sync() async{
    if(!isSupported) return;
    final minutes = storage.DataCache.getBackgroundGradeCheckMinutes();
    final wanted = minutes > 0
        && ((storage.DataCache.getNeedGradeNotifications() ?? true)
            || (storage.DataCache.getNeedMailNotifications() ?? true))
        && !(storage.DataCache.getIsDemoAccount() ?? false)
        && (storage.DataCache.getUsername()?.isNotEmpty ?? false);
    if(wanted){
      await register(minutes);
    }
    else{
      await cancel();
    }
  }

  static Future<void> register(int minutes) async{
    if(!isSupported) return;
    try{
      await _ensureInitialised();
      await Workmanager().registerPeriodicTask(
        _gradeCheckUniqueName,
        _gradeCheckTask,
        frequency: Duration(minutes: minutes < 15 ? 15 : minutes),
        // Capped rather than matching the interval, so turning the feature on does not
        // sit idle for up to 12 hours before the first check.
        initialDelay: const Duration(minutes: 15),
        // Replace rather than keep, so changing the interval takes effect.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresDeviceIdle: false,
        ),
        backoffPolicy: BackoffPolicy.exponential,
      );
    }
    catch(e){
      debug.log('Could not register the background grade check: $e');
    }
  }

  static Future<void> cancel() async{
    if(!isSupported) return;
    try{
      await _ensureInitialised();
      await Workmanager().cancelByUniqueName(_gradeCheckUniqueName);
    }
    catch(e){
      debug.log('Could not cancel the background grade check: $e');
    }
  }
}

// Platform.isAndroid would throw on web; the app does not ship a web build, but
// this keeps the getter honest.
const bool kIsWebFallback = bool.fromEnvironment('dart.library.js_util');
