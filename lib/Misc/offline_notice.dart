import 'package:flutter/material.dart';
import '../colors.dart';
import '../language.dart';
import '../storage.dart' as storage;

/// Compiled in rather than read from a language pack, for the same reason as the demo
/// banner: packs are downloaded at runtime and must not be able to rewrite a warning.
String _offlineText(String hu, String en) =>
    AppStrings.getCurrentLangCode() == 'hu' ? hu : en;

String _ageLabel(DateTime? updated){
  if(updated == null){
    return _offlineText('mentett adatok', 'saved data');
  }
  final diff = DateTime.now().difference(updated);
  if(diff.inMinutes < 2){
    return _offlineText('az imént frissítve', 'updated just now');
  }
  if(diff.inHours < 1){
    return _offlineText('${diff.inMinutes} perce frissítve', 'updated ${diff.inMinutes} min ago');
  }
  if(diff.inDays < 1){
    return _offlineText('${diff.inHours} órája frissítve', 'updated ${diff.inHours}h ago');
  }
  return _offlineText('${diff.inDays} napja frissítve', 'updated ${diff.inDays}d ago');
}

/// Shown while there is no connection, so stale figures are never mistaken for live ones.
class OfflineBanner extends StatelessWidget {
  final DateTime? lastUpdated;
  const OfflineBanner({super.key, this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    if(storage.DataCache.getHasNetwork()){
      return const SizedBox.shrink();
    }
    final theme = AppColors.getTheme();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: theme.errorRed.withValues(alpha: 0.14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: theme.textColor.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${_offlineText('NINCS INTERNET', 'OFFLINE')} — ${_ageLabel(lastUpdated)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
