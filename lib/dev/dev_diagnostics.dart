import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much of a stored key the developer tab is allowed to show.
enum KeyTier {
  /// Never listed at all. Legacy plaintext credential keys.
  hidden,

  /// Name, type and size. Never the value, because it is somebody's grades,
  /// messages or timetable.
  opaque,

  /// Name and value.
  open,
}

/// Decides what may be rendered for a stored key.
///
/// The open tier is an allowlist rather than a blocklist. A key added next month
/// is opaque until someone deliberately adds it here, which is the safe way
/// round: forgetting to list something hides it instead of leaking it.
class KeyPolicy {
  static const Set<String> _neverList = {
    'Password', 'AccessToken', 'Username', 'URL', 'URL_Fallbacks',
    'ICS_FileLocation',
  };

  static const Set<String> _openPrefixes = {
    'SETTING_', 'CONFIG_', 'CALENDAR_Display', 'THEME_AppTheme',
  };

  static const Set<String> _openExact = {
    'HasLogin', 'HasAcceptedTerms', 'HasCachedCalendar', 'HasCachedMarkbook',
    'HasCachedPayments', 'HasCachedPeriods', 'HasCachedMail',
    'HasCachedFirstWeekEpoch', 'IsModernApi', 'IsDemoAccount', 'FontScale',
    'DegreeCreditTarget', 'FirstWeekOfSemesterEpoch', 'SECURE_HasTotpSecret',
    'CalendarCacheTime', 'MarkbookCacheTime', 'PaymentsCacheTime',
    'PeriodsCacheTime', 'MailCacheTime', 'UpdateCacheTime',
    'NextFirstWeekCacheTime', 'RefreshLangCacheTime', 'UpcomingCacheTime',
    'SuggestLangNudgeTime', 'SuggestLangUpdateCacheTime',
    'ObsoleteAppVerUpdateCacheTime', 'ICS_HasIcsUpload', 'DEV_ModeEnabled',
  };

  static KeyTier of(String key) {
    if (_neverList.contains(key)) return KeyTier.hidden;
    if (key.startsWith('devicecookie_') || key.startsWith('neptun_')) {
      return KeyTier.hidden;
    }
    if (_openExact.contains(key)) return KeyTier.open;
    for (final prefix in _openPrefixes) {
      if (key.startsWith(prefix)) return KeyTier.open;
    }
    return KeyTier.opaque;
  }
}

class StoredKey {
  final String key;
  final KeyTier tier;
  final String type;
  final int bytes;

  /// Null unless the key is on the open allowlist.
  final String? value;

  const StoredKey({
    required this.key,
    required this.tier,
    required this.type,
    required this.bytes,
    this.value,
  });
}

class CacheEntry {
  final String label;
  final String key;
  final DateTime? writtenAt;
  final Duration ttl;

  const CacheEntry({
    required this.label,
    required this.key,
    required this.writtenAt,
    required this.ttl,
  });

  Duration? get age =>
      writtenAt == null ? null : DateTime.now().difference(writtenAt!);
  bool get isStale {
    final a = age;
    return a == null || a > ttl;
  }
}

class DevDiagnostics {
  /// Every SharedPreferences key, classified. Hidden ones are dropped here so
  /// they never reach a widget.
  static Future<List<StoredKey>> readStoredKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <StoredKey>[];

    for (final key in prefs.getKeys()) {
      final tier = KeyPolicy.of(key);
      if (tier == KeyTier.hidden) continue;

      final raw = prefs.get(key);
      final type = raw == null ? 'null' : raw.runtimeType.toString();
      final rendered = raw is List ? raw.join(',') : '$raw';
      out.add(StoredKey(
        key: key,
        tier: tier,
        type: type.startsWith('List') ? 'List' : type,
        bytes: rendered.length,
        value: tier == KeyTier.open ? rendered : null,
      ));
    }

    out.sort((a, b) => a.key.compareTo(b.key));
    return out;
  }

  static Future<List<CacheEntry>> readCaches() async {
    final prefs = await SharedPreferences.getInstance();

    DateTime? stamp(String key) {
      final raw = prefs.get(key);
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return [
      CacheEntry(label: 'Timetable', key: 'CalendarCacheTime', writtenAt: stamp('CalendarCacheTime'), ttl: const Duration(hours: 24)),
      CacheEntry(label: 'Markbook', key: 'MarkbookCacheTime', writtenAt: stamp('MarkbookCacheTime'), ttl: const Duration(hours: 24)),
      CacheEntry(label: 'Payments', key: 'PaymentsCacheTime', writtenAt: stamp('PaymentsCacheTime'), ttl: const Duration(hours: 24)),
      CacheEntry(label: 'Periods', key: 'PeriodsCacheTime', writtenAt: stamp('PeriodsCacheTime'), ttl: const Duration(hours: 24)),
      CacheEntry(label: 'Messages', key: 'MailCacheTime', writtenAt: stamp('MailCacheTime'), ttl: const Duration(hours: 24)),
      CacheEntry(label: 'Upcoming', key: 'UpcomingCacheTime', writtenAt: stamp('UpcomingCacheTime'), ttl: const Duration(hours: 3)),
    ];
  }

  /// Drops one cache's timestamp so the next open refetches.
  static Future<void> invalidate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<Map<String, String>> readBuildInfo() async {
    final info = await PackageInfo.fromPlatform();
    final connectivity = await Connectivity().checkConnectivity();

    final out = <String, String>{
      'version': '${info.version} (${info.buildNumber})',
      'package': info.packageName,
      'installer': info.installerStore ?? 'sideloaded',
      'distribution': const String.fromEnvironment('NHNK_DISTRIBUTION', defaultValue: 'unset'),
      'connectivity': connectivity.map((c) => c.name).join(', '),
    };

    if (Platform.isAndroid) {
      final android = await DeviceInfoPlugin().androidInfo;
      out['device'] = '${android.manufacturer} ${android.model}';
      out['android'] = '${android.version.release} (sdk ${android.version.sdkInt})';
      out['abi'] = android.supportedAbis.isEmpty ? 'unknown' : android.supportedAbis.first;
    }
    return out;
  }

  static Future<Map<String, int>> readFootprint() async {
    final out = <String, int>{
      'rss': ProcessInfo.currentRss,
      'peakRss': ProcessInfo.maxRss,
    };

    Future<int> sizeOf(Directory dir) async {
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) { }
        }
      }
      return total;
    }

    out['documents'] = await sizeOf(await getApplicationDocumentsDirectory());
    out['cache'] = await sizeOf(await getTemporaryDirectory());
    return out;
  }
}
