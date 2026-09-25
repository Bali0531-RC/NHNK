import 'package:nhnk/platform_support.dart';
import 'dart:developer' as debug;

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'API/api_coms.dart' as api;
import 'grade_alerts.dart';
import 'language.dart';
import 'mail_alerts.dart';
import 'storage.dart' as storage;
import 'timetable_sync.dart';

const String _gradeCheckTask = 'hu.bali0531.nhnk.gradecheck';
const String _gradeCheckUniqueName = 'nhnk-grade-check';
const String _timetableTask = 'hu.bali0531.nhnk.timetable';
const String _timetableUniqueName = 'nhnk-timetable-sync';

@pragma('vm:entry-point')
Future<void> onWidgetRefresh(Uri? uri) async {
  if (uri?.host != 'refresh') return;
  WidgetsFlutterBinding.ensureInitialized();
  await storage.DataCache.loadData();
  await BackgroundWorker.sync();
  await BackgroundWorker.refreshTimetable();
}

/// Runs in its own isolate with none of the app's statics populated, so anything
/// it touches has to be initialised here first.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _gradeCheckTask && task != _timetableTask) {
      return true;
    }
    try {
      WidgetsFlutterBinding.ensureInitialized();
      AppStrings.initialize();
      await (await SharedPreferences.getInstance()).reload();
      await storage.DataCache.loadData();

      if (!(storage.DataCache.getHasLogin() ?? false)) return true;
      if (storage.DataCache.getIsDemoAccount() ?? false) return true;
      if (storage.DataCache.getHasICSFile() ?? false) return true;

      if (task == _timetableTask) {
        if (!(storage.DataCache.getNeedClassNotifications() ?? true) &&
            !await TimetableSync.hasWidgets()) return true;
        return await TimetableSync.refresh();
      }

      if (!(storage.DataCache.getNeedGradeNotifications() ?? true) &&
          !(storage.DataCache.getNeedMailNotifications() ?? true)) return true;

      final username = storage.DataCache.getUsername();
      final password = await storage.DataCache.getPassword();
      if (username == null ||
          username.isEmpty ||
          password == null ||
          password.isEmpty) {
        return true;
      }

      var success = true;

      if (storage.DataCache.getNeedGradeNotifications() ?? true) {
        try {
          final fresh = await api.MarkbookRequest.getMarkbookSubjects();
          if (fresh != null && fresh.isNotEmpty) {
            final previous = await GradeAlerts.readCachedGrades();
            final changed = GradeAlerts.findNewGrades(previous, fresh);

            await GradeAlerts.notify(changed);
            await GradeAlerts.writeCache(fresh);
          }
        } catch (error) {
          success = false;
          debug.log('Background grade check failed (${error.runtimeType})');
        }
      }

      if (storage.DataCache.getNeedMailNotifications() ?? true) {
        try {
          // Page 1 only: the cache holds the newest page, so older pages are not comparable.
          final mails = await api.MailRequest.getMails(1);
          if (mails != null && mails.isNotEmpty) {
            final previous = await MailAlerts.readCachedMailIds();
            final fresh = MailAlerts.findNewMails(previous, mails);
            await MailAlerts.notify(fresh);

            // The total is only needed for foreground pagination, so the periodic
            // check asks for the unread number alone rather than pulling 200 records.
            final fastUnread = await api.MailRequest.getUnreadCountFast();
            if (fastUnread != null) {
              final knownTotal =
                  (await storage.getInt('CachedMailsTotal')) ?? mails.length;
              await MailAlerts.writeCache(mails, fastUnread, knownTotal);
            } else {
              final counts =
                  await api.MailRequest.getUnreadMessagesAndAllMessages();
              await MailAlerts.writeCache(mails, counts[0], counts[1]);
            }
          }
        } catch (error) {
          success = false;
          debug.log('Background mail check failed (${error.runtimeType})');
        }
      }
      return success;
    } catch (e) {
      debug.log('Background refresh failed (${e.runtimeType})');
      return false;
    }
  });
}

class BackgroundWorker {
  /// Selectable intervals in minutes, last entry disables the check. 15 is Android's
  /// hard floor for periodic work -- anything shorter is silently clamped to it.
  static const List<int> intervalSteps = [15, 30, 60, 120, 180, 360, 720, 0];

  /// iOS background refresh needs AppDelegate and Info.plist changes the unsigned
  /// build does not carry, so this stays Android-only for now.
  static bool get isSupported => AppPlatform.isAndroid;

  static bool _initialised = false;

  static Future<void> _ensureInitialised() async {
    if (_initialised) return;
    await Workmanager().initialize(backgroundCallbackDispatcher);
    _initialised = true;
  }

  static Future<void> sync() async {
    if (!isSupported) return;
    await _ensureInitialised();
    await HomeWidget.registerInteractivityCallback(onWidgetRefresh);
    final signedIn = (storage.DataCache.getHasLogin() ?? false) &&
        !(storage.DataCache.getIsDemoAccount() ?? false) &&
        !(storage.DataCache.getHasICSFile() ?? false);
    if (signedIn &&
        ((storage.DataCache.getNeedClassNotifications() ?? true) ||
            await TimetableSync.hasWidgets())) {
      await Workmanager().registerPeriodicTask(
        _timetableUniqueName,
        _timetableTask,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
    } else {
      await Workmanager().cancelByUniqueName(_timetableUniqueName);
    }
    final minutes = storage.DataCache.getBackgroundGradeCheckMinutes();
    final wanted = signedIn &&
        minutes > 0 &&
        ((storage.DataCache.getNeedGradeNotifications() ?? true) ||
            (storage.DataCache.getNeedMailNotifications() ?? true)) &&
        !(storage.DataCache.getIsDemoAccount() ?? false) &&
        (storage.DataCache.getUsername()?.isNotEmpty ?? false);
    if (wanted) {
      await register(minutes);
    } else {
      await Workmanager().cancelByUniqueName(_gradeCheckUniqueName);
    }
  }

  static Future<void> refreshTimetable() async {
    if (!isSupported || !(storage.DataCache.getHasLogin() ?? false)) return;
    await _ensureInitialised();
    await Workmanager().registerOneOffTask(
      '$_timetableUniqueName-manual',
      _timetableTask,
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  static Future<void> register(int minutes) async {
    if (!isSupported) return;
    try {
      await _ensureInitialised();
      await Workmanager().registerPeriodicTask(
        _gradeCheckUniqueName,
        _gradeCheckTask,
        frequency: Duration(minutes: minutes < 15 ? 15 : minutes),
        // Replace rather than keep, so changing the interval takes effect.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
    } catch (e) {
      debug.log('Could not register the background grade check: $e');
    }
  }

  static Future<void> cancel() async {
    if (!isSupported) return;
    try {
      await _ensureInitialised();
      await Workmanager().cancelByUniqueName(_gradeCheckUniqueName);
      await Workmanager().cancelByUniqueName(_timetableUniqueName);
      await Workmanager().cancelByUniqueName('$_timetableUniqueName-manual');
    } catch (e) {
      debug.log('Could not cancel the background grade check: $e');
    }
  }
}
