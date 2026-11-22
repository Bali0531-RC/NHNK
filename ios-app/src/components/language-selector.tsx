import { Pressable, Text, View } from 'react-native';

import { Radius, Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import type { Lang } from '@/i18n/strings';

const LANGS: { value: Lang; label: string }[] = [
  { value: 'hu', label: 'HU' },
  { value: 'en', label: 'EN' },
  { value: 'de', label: 'DE' },
];

// tiny HU/EN/DE switch for login and onboarding
export function LanguageSelector() {
  const c = useTheme();
  const { lang, setLang } = useI18n();
  const { selection } = useHaptics();
  return (
    <View style={{ flexDirection: 'row', gap: Spacing.one, alignSelf: 'center' }}>
      {LANGS.map((l) => {
        const active = l.value === lang;
        return (
          <Pressable
            key={l.value}
            onPress={() => {
              if (!active) {
                selection();
                setLang(l.value);
              }
            }}
            style={{
              paddingVertical: Spacing.one + 2,
              paddingHorizontal: Spacing.three,
              borderRadius: Radius.sm,
              backgroundColor: active ? c.brand : c.card,
              borderCurve: 'continuous',
            }}>
            <Text style={{ color: active ? c.brandOn : c.textSecondary, fontWeight: '700', fontSize: 13 }}>
              {l.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}