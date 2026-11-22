import { Stack } from 'expo-router';

import { Hamburger } from '@/components/hamburger';
import { useDetailHeader } from '@/hooks/use-header';

// per tab stack with the menu button. only the timetable is index, five tabs claiming / made launch land anywhere
export function TabStack({ name = 'index', title, largeTitle = true }: { name?: string; title: string; largeTitle?: boolean }) {
  const header = useDetailHeader();
  return (
    <Stack screenOptions={{ ...header, headerLeft: () => <Hamburger /> }}>
      <Stack.Screen name={name} options={{ title, headerLargeTitle: largeTitle && header.headerLargeTitle }} />
    </Stack>
  );
}