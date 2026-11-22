import { isLiquidGlassAvailable } from 'expo-glass-effect';

import { useTheme } from '@/hooks/use-theme';

const glass = isLiquidGlassAvailable();

// shared header for pushed screens, large titles on the native look
export function useDetailHeader() {
  const c = useTheme();
  if (c.style === 'native') {
    return {
      headerShown: true,
      headerTransparent: true,
      headerBlurEffect: glass ? undefined : ('systemChromeMaterial' as const),
      headerShadowVisible: false,
      headerLargeTitle: true,
      headerLargeTitleShadowVisible: false,
      headerLargeStyle: { backgroundColor: 'transparent' },
      headerTintColor: c.brand,
      headerTitleStyle: { color: c.text },
      headerBackButtonDisplayMode: 'minimal' as const,
      contentStyle: { backgroundColor: c.background },
    };
  }
  return {
    headerShown: true,
    headerShadowVisible: false,
    headerStyle: { backgroundColor: c.background },
    headerTintColor: c.brandText,
    headerTitleStyle: { color: c.brandText },
    headerBackButtonDisplayMode: 'minimal' as const,
    contentStyle: { backgroundColor: c.background },
  };
}