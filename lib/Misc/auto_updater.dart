import 'package:nhnk/platform_support.dart';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../storage.dart'; // A getInt és saveInt miatt kell
import '../colors.dart';
import '../language.dart';

String _ut(String hu, String en) => AppStrings.getCurrentLangCode() == 'hu' ? hu : en;

class AppUpdater {
  // Must track this fork: upstream releases are signed with a different key and
  // would fail to install over builds from this repository.
  static const String repoOwner = "Bali0531-RC";
  static const String repoName = "NHNK";

  /// Google Play bans APKs that update themselves, so the playstore flavor ships
  /// without this. iOS has no way to install one at all.
  static bool get isSupported =>
      AppPlatform.isAndroid &&
      String.fromEnvironment('NHNK_DISTRIBUTION', defaultValue: 'github') != 'playstore';

  /// Fő belépési pont. Ezt hívd meg a main_page initState-jében!
  static Future<void> checkAndInstallUpdate(BuildContext context) async {
    if (!isSupported) {
      return;
    }

    // 1. Internet ellenőrzés
    if (await Connectivity().checkConnectivity() == ConnectivityResult.none) {
      return;
    }

    // 2. 24 órás Cache ellenőrzés (csak naponta egyszer nézzük meg)
    final cacheTime = await getInt('ObsoleteAppVerUpdateCacheTime') ?? -1;
    if ((DateTime.now().millisecondsSinceEpoch - cacheTime) < const Duration(hours: 24).inMilliseconds) {
      return; // Még nem telt el 24 óra, nem csinálunk semmit
    }

    try {
      // 3. GitHub API hívás a 'latest' kiadásért
      final response = await http.get(Uri.parse("https://api.github.com/repos/$repoOwner/$repoName/releases/latest"));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final latestTag = data['tag_name'].toString(); // Pl: Release_v1.0.2
      final latestVersionClean = latestTag.replaceAll(RegExp(r'[^0-9.]'), ''); // Kiszűrjük a szöveget: 1.0.2

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Elmentjük a sikeres ellenőrzés idejét
      await saveInt('ObsoleteAppVerUpdateCacheTime', DateTime.now().millisecondsSinceEpoch);

      if (_isNewerVersion(currentVersion, latestVersionClean)) {
        if (!context.mounted) return;

        bool shouldUpdate = await _showUpdateDialog(context, latestVersionClean);
        if (shouldUpdate) {
          await _downloadAndInstall(context, data['assets']);
        }
      }
    } catch (e) {
      debugPrint("Hiba az auto-update során: $e");
    }
  }

  /// Egyszerű Igen / Később ablak
  static Future<bool> _showUpdateDialog(BuildContext context, String version) async {
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getTheme().rootBackground,
        title: Text(_ut("Frissítés elérhető!", "Update available"), style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold)),
        content: Text(
          _ut("Az alkalmazás új verziója (v$version) letölthető. Szeretnéd most telepíteni?",
              "A new version (v$version) is ready to download. Install it now?"),
          style: TextStyle(color: AppColors.getTheme().textColor)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_ut("Később", "Later"), style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6)))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getTheme().currentClassGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_ut("Igen", "Yes"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Letöltés sávval és automatikus megnyitás
  static Future<void> _downloadAndInstall(BuildContext context, List assets) async {
    // 1. Architektúra detektálása (ARM7 vs ARM8)
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    bool isArm64 = androidInfo.supported64BitAbis.isNotEmpty;
    String archKeyword = isArm64 ? "ARM8" : "ARM7";

    // 2. Megfelelő APK kiválasztása a GitHub assets listából
    var asset;
    try {
      asset = assets.firstWhere((a) => a['name'].toString().contains(archKeyword) && a['name'].toString().endsWith('.apk'));
    } catch (e) {
      debugPrint("Nem található megfelelő APK ehhez az architektúrához: $archKeyword");
      return;
    }

    final downloadUrl = asset['browser_download_url'];
    final tempDir = await getTemporaryDirectory();
    final savePath = "${tempDir.path}/Neptun_Update.apk";

    // Takarítás: töröljük a régi telepítőt
    if (File(savePath).existsSync()) {
      File(savePath).deleteSync();
    }

    if (!context.mounted) return;

    // 3. Letöltés folyamatjelzővel
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DownloadProgressDialog(),
    );

    try {
      final dio = Dio();
      await dio.download(downloadUrl, savePath);

      if (!context.mounted) return;
      Navigator.pop(context); // Töltés ablak bezárása

      // 4. Telepítés indítása
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        debugPrint("Hiba az APK megnyitásakor: ${result.message}");
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      debugPrint("Hálózati hiba a letöltés során: $e");
    }
  }
  /// Darabjaira szedi a verziószámokat (pl. 1.0.2) és megnézi, hogy a latest tényleg nagyobb-e.
  static bool _isNewerVersion(String current, String latest) {
    List<int> currParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < latestParts.length; i++) {
      int c = i < currParts.length ? currParts[i] : 0;
      int l = latestParts[i];
      if (l > c) return true;  // A GitHub verzió nagyobb
      if (l < c) return false; // A telefonos verzió a nagyobb
    }
    return false; // Pontosan egyeznek
  }
}

/// Belső Widget a letöltési folyamatjelzőhöz
class _DownloadProgressDialog extends StatelessWidget {
  const _DownloadProgressDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.getTheme().rootBackground,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.getTheme().currentClassGreen),
          const SizedBox(height: 20),
          Text(_ut("Frissítés letöltése folyamatban...", "Downloading the update..."), style: TextStyle(color: AppColors.getTheme().textColor)),
          const SizedBox(height: 10),
          Text(_ut("Kérlek, ne zárd be az alkalmazást.", "Please keep the app open."), style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6), fontSize: 12)),
        ],
      ),
    );
  }
}