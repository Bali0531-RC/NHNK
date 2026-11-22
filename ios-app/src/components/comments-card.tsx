import { SymbolView } from 'expo-symbols';
import { Text, View } from 'react-native';
import Animated, { FadeIn } from 'react-native-reanimated';

import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';

// prof free text up top, its sometimes the only place the real room or the zh date lives
export function CommentsCard({ items }: { items: string[] }) {
  const c = useTheme();
  const { tx } = useI18n();
  if (!items.length) return null;
  return (
    <Animated.View
      entering={FadeIn.duration(250)}
      style={{ backgroundColor: c.brandSubtle, borderRadius: 14, borderCurve: 'continuous', padding: Spacing.three, gap: Spacing.two }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.two }}>
        <SymbolView name="text.bubble.fill" tintColor={c.brand} size={16} />
        <Text style={{ color: c.brand, fontSize: 13, fontWeight: '700', textTransform: 'uppercase' }}>{tx.v2.calendar.comments}</Text>
      </View>
      {items.map((t) => (
        <Text key={t} selectable style={{ color: c.text, fontSize: 15, lineHeight: 21 }}>
          {t}
        </Text>
      ))}
    </Animated.View>
  );
}