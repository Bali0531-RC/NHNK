import { SymbolView } from 'expo-symbols';
import { Pressable } from 'react-native';

import { useSideMenu } from '@/components/side-menu';
import { useHaptics } from '@/hooks/use-haptics';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';

// Opens the side menu. In the native look the header wraps it in a glass bar button.
export function Hamburger() {
  const c = useTheme();
  const { tx } = useI18n();
  const { selection } = useHaptics();
  const menu = useSideMenu();
  return (
    <Pressable
      testID="menu-button"
      accessibilityRole="button"
      accessibilityLabel={tx.menu.open}
      hitSlop={14}
      onPress={() => {
        selection();
        menu.open();
      }}
      style={({ pressed }) => ({ opacity: pressed ? 0.5 : 1, width: 36, height: 36, alignItems: 'center', justifyContent: 'center' })}>
      <SymbolView name="line.3.horizontal" tintColor={c.style === 'native' ? c.text : c.brandText} size={20} weight="semibold" />
    </Pressable>
  );
}