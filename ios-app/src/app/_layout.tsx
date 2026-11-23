import { isLiquidGlassAvailable } from 'expo-glass-effect';
import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect, useState } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';

import { LoadingScreen } from '@/components/loading-screen';
import { LockScreen } from '@/components/lock-screen';
import { Onboarding } from '@/components/onboarding';
import { useDemoExam } from '@/hooks/use-demo-exam';
import { useDetailHeader } from '@/hooks/use-header';
import { useOta } from '@/hooks/use-ota';
import { useTheme } from '@/hooks/use-theme';
import { I18nProvider } from '@/i18n';
import { useNotificationSync } from '@/lib/notifications';
import { useReviewPrompt } from '@/lib/review';
import { needsInstallWipe, prepareInstall } from '@/lib/wipe';
import { migrateKeychain } from '@/neptun/storage';
import LoginScreen from './login';
import { AppLockProvider, useAppLock } from '@/providers/app-lock';
import { AuthProvider, useAuth } from '@/providers/auth';
import { PreferencesProvider, usePreferences } from '@/providers/preferences';

const glass = isLiquidGlassAvailable();

export default function RootLayout() {
  // fresh install drops the keychain leftovers first, otherwise a reinstall skips onboarding and auto logs in
  const [ready, setReady] = useState(!needsInstallWipe);
  useEffect(() => {
    void prepareInstall()
      .finally(() => setReady(true))
      .then(() => migrateKeychain(['nhnk.prefs.v2', 'nhnk.pref.lang']));
  }, []);
  if (!ready) return null;
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <I18nProvider>
        <PreferencesProvider>
          <ThemedApp />
        </PreferencesProvider>
      </I18nProvider>
    </GestureHandlerRootView>
  );
}

// Native navigation chrome and the status bar follow the in-app theme, not just the system.
function ThemedApp() {
  const c = useTheme();
  const base = c.scheme === 'dark' ? DarkTheme : DefaultTheme;
  const theme = {
    ...base,
    colors: { ...base.colors, primary: c.brandText, background: c.background, card: c.card, text: c.text, border: c.separator },
  };
  return (
    <ThemeProvider value={theme}>
      <AuthProvider>
        <AppLockProvider>
          <RootNavigator />
        </AppLockProvider>
        <StatusBar style={c.scheme === 'dark' ? 'light' : 'dark'} />
      </AuthProvider>
    </ThemeProvider>
  );
}

function RootNavigator() {
  const c = useTheme();
  const { status, reauth, pendingTwoFactor } = useAuth();
  const { locked } = useAppLock();
  const { loaded, onboardingSeen, setOnboardingSeen } = usePreferences();
  const detail = useDetailHeader();
  // Screens with a two-line custom title read badly over scrolled content, so their bar is solid.
  const solidHeader = {
    headerLargeTitle: false,
    headerTransparent: false,
    headerBlurEffect: undefined,
    headerStyle: { backgroundColor: c.background },
  };
  const authed = status === 'signedIn';
  useNotificationSync(authed);
  useReviewPrompt(authed);
  useDemoExam();
  // never reload under someone typing a 2fa code
  useOta(!pendingTwoFactor);

  if (!loaded || status === 'restoring') return <LoadingScreen />;
  if (!onboardingSeen) return <Onboarding onDone={() => setOnboardingSeen(true)} />;
  if (authed && locked) return <LockScreen />;
  if (authed && reauth && pendingTwoFactor) return <LoginScreen />;

  const sheet = {
    presentation: 'formSheet' as const,
    sheetGrabberVisible: true,
    sheetAllowedDetents: [0.6, 1],
    headerShown: false,
    contentStyle: { backgroundColor: glass && c.style === 'native' ? 'transparent' : c.background },
  };

  return (
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: c.background } }}>
      <Stack.Protected guard={authed}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="settings" options={detail} />
        <Stack.Screen name="statistics" options={detail} />
        <Stack.Screen name="upcoming" options={detail} />
        <Stack.Screen name="about" options={detail} />
        <Stack.Screen name="profile" options={detail} />
        <Stack.Screen name="requests" options={detail} />
        <Stack.Screen name="documents" options={detail} />
        <Stack.Screen name="questionnaires" options={detail} />
        <Stack.Screen name="subject/[id]" options={{ ...detail, ...solidHeader }} />
        <Stack.Screen name="message/[id]" options={{ ...detail, ...solidHeader }} />
        <Stack.Screen name="class-details" options={sheet} />
        <Stack.Screen name="top-up" options={sheet} />
        <Stack.Screen
          name="exam"
          options={{ ...detail, presentation: 'formSheet', sheetGrabberVisible: true, sheetAllowedDetents: [0.9], headerLargeTitle: false }}
        />
        <Stack.Screen name="tutorial" options={{ presentation: 'modal', contentStyle: { backgroundColor: c.background } }} />
      </Stack.Protected>
      <Stack.Protected guard={!authed}>
        <Stack.Screen name="login" />
      </Stack.Protected>
    </Stack>
  );
}