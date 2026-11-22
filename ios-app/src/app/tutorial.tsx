import { router } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, Text, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { TutorialVideo } from '@/components/tutorial-video';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';

// 2fa walkthrough from settings, same phone frame as the onboarding
export default function Tutorial() {
  const c = useTheme();
  const { tx } = useI18n();
  const insets = useSafeAreaInsets();
  const { width, height } = useWindowDimensions();
  const videoH = Math.min(height - insets.top - insets.bottom - 160, ((width - Spacing.five * 2) * 4585) / 2242);

  return (
    <View style={{ flex: 1, backgroundColor: c.background, paddingTop: Spacing.four, paddingBottom: insets.bottom + Spacing.three, alignItems: 'center', gap: Spacing.three }}>
      <View style={{ flexDirection: 'row', alignSelf: 'stretch', alignItems: 'center', paddingHorizontal: Spacing.four }}>
        <Text style={{ flex: 1, color: c.text, fontSize: 22, fontWeight: '800' }}>{tx.v2.tutorial.title}</Text>
        <Pressable onPress={() => router.back()} hitSlop={12} accessibilityRole="button" accessibilityLabel={tx.v2.common.close}>
          <SymbolView name="xmark.circle.fill" size={30} tintColor={c.textTertiary} />
        </Pressable>
      </View>
      <Text style={{ color: c.textSecondary, fontSize: 15, textAlign: 'center', paddingHorizontal: Spacing.five }}>{tx.v2.tutorial.body}</Text>
      <View style={{ flex: 1, justifyContent: 'center' }}>
        <TutorialVideo height={videoH} />
      </View>
    </View>
  );
}