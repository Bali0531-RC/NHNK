import { Stack } from 'expo-router';

// Each native tab wraps its screen in this so it gets a proper iOS large-title header.
export function TabStack({ title }: { title: string }) {
  return (
    <Stack screenOptions={{ headerLargeTitle: true, headerShadowVisible: false }}>
      <Stack.Screen name="index" options={{ title }} />
    </Stack>
  );
}
