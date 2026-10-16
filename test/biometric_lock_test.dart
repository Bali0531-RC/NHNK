import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/biometric_lock.dart';
import 'package:nhnk/colors.dart';
import 'package:nhnk/language.dart';
import 'package:nhnk/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');

  bool deviceSupported = true;
  bool authResult = false;
  int authCalls = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    deviceSupported = true;
    authResult = false;
    authCalls = 0;
    BiometricLock.resetSession();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async => call.method == 'readAll' ? <String, String>{} : null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivity, (call) async => <String>['wifi']);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BiometricLock.channel, (call) async {
      if (call.method == 'isDeviceSupported') {
        return deviceSupported;
      }
      if (call.method == 'authenticate') {
        authCalls++;
        return authResult;
      }
      return null;
    });

    await DataCache.loadData();
    AppColors.initialize();
    AppStrings.initialize();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secure, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(connectivity, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BiometricLock.channel, null);
  });

  test('biometric lock is enabled by default on fresh installs and can be opted out', () async {
    expect(DataCache.getBiometricLockEnabled(), isTrue);

    await DataCache.setBiometricLockEnabled(false);
    expect(DataCache.getBiometricLockEnabled(), isFalse);

    await DataCache.loadData();
    expect(DataCache.getBiometricLockEnabled(), isFalse);

    await DataCache.setBiometricLockEnabled(true);
    await DataCache.loadData();
    expect(DataCache.getBiometricLockEnabled(), isTrue);
  });

  test('demo accounts and logged-out states do not require biometric lock', () async {
    await DataCache.setHasLogin(0);
    await DataCache.setIsDemoAccount(0);
    expect(BiometricLock.shouldRequireLock(), isFalse);

    await DataCache.setHasLogin(1);
    await DataCache.setIsDemoAccount(1);
    expect(BiometricLock.shouldRequireLock(), isFalse);

    await DataCache.setIsDemoAccount(0);
    expect(BiometricLock.shouldRequireLock(), isTrue);

    await DataCache.setBiometricLockEnabled(false);
    expect(BiometricLock.shouldRequireLock(), isFalse);
  });

  testWidgets('BiometricLockGate keeps content locked until authentication succeeds', (tester) async {
    await DataCache.setHasLogin(1);
    await DataCache.setIsDemoAccount(0);
    await DataCache.setBiometricLockEnabled(true);
    authResult = false;

    await tester.pumpWidget(
      const MaterialApp(
        home: BiometricLockGate(
          child: Scaffold(body: Text('UNLOCKED_HOME')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(authCalls, 1);
    expect(find.text('UNLOCKED_HOME'), findsNothing);
    expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);

    authResult = true;
    await tester.tap(find.byIcon(Icons.lock_open_rounded));
    await tester.pumpAndSettle();

    expect(authCalls, 2);
    expect(find.text('UNLOCKED_HOME'), findsOneWidget);
  });
}
