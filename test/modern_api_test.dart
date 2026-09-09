import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/API/api_coms.dart' as api;
import 'package:shared_preferences/shared_preferences.dart';

/// The new endpoints are not present on every Neptun install, so the thing worth
/// pinning is that a miss is quiet and the caller keeps its old behaviour.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await api.ModernApi.forgetCapabilities();
  });

  test('endpoint constants match the routes observed on the web client', () {
    expect(api.ModernApi.unreadMessageCount, 'Message/GetUnreadedMessagesCount');
    expect(api.ModernApi.creditProgress, 'dashboard/creditprogress');
  });

  test('a legacy account never reaches the modern endpoints', () async {
    // No session and no modern flag: fetchData must give up rather than build a URL.
    expect(await api.ModernApi.fetchData(api.ModernApi.creditProgress), isNull);
    expect(await api.ModernApi.fetchData(api.ModernApi.unreadMessageCount), isNull);
  });

  test('required credits is null when the endpoint gives nothing', () async {
    expect(await api.ProgressRequest.getRequiredCredits(), isNull);
  });

  test('forgetting capabilities clears the remembered answers', () async {
    await api.ModernApi.forgetCapabilities();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('ModernSupport_dashboard_creditprogress'), 0);
    expect(prefs.getInt('ModernSupport_Message_GetUnreadedMessagesCount'), 0);
  });
}
