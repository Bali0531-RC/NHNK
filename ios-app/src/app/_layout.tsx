import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';

import { LoadingScreen } from '@/components/loading-screen';
import { I18nProvider } from '@/i18n';
import { AuthProvider, useAuth } from '@/providers/auth';
import { PreferencesProvider, useResolvedScheme } from '@/providers/preferences';

export default function RootLayout() {
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

// Reads the resolved scheme so the native navigation chrome and status bar follow the
// theme override, not just the system setting.
function ThemedApp() {
  const scheme = useResolvedScheme();
  return (
    <ThemeProvider value={scheme === 'dark' ? DarkTheme : DefaultTheme}>
      <AuthProvider>
        <RootNavigator />
        <StatusBar style={scheme === 'dark' ? 'light' : 'dark'} />
      </AuthProvider>
    </ThemeProvider>
  );
}

function RootNavigator() {
  const { status } = useAuth();
  if (status === 'restoring') return <LoadingScreen />;

  const authed = status === 'signedIn';
  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Protected guard={authed}>
        <Stack.Screen name="(tabs)" />
      </Stack.Protected>
      <Stack.Protected guard={!authed}>
        <Stack.Screen name="login" />
      </Stack.Protected>
    </Stack>
  );
}
