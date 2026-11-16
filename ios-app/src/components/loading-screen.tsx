import { Image } from 'expo-image';
import { ActivityIndicator, View } from 'react-native';

import { Radius, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';

const logo = require('../../assets/images/nhnk-logo.png');

// Shown only while the stored session is being read on launch. Kept to the logo and a
// spinner so it reads as an instant hand-off, not a screen.
export function LoadingScreen() {
  const c = useTheme();
  return (
    <View
      style={{
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: c.background,
        gap: Spacing.four,
      }}>
      <Image source={logo} style={{ width: 96, height: 96, borderRadius: Radius.xl }} contentFit="contain" />
      <ActivityIndicator color={c.brand} />
    </View>
  );
}
