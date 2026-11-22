import * as Clipboard from 'expo-clipboard';
import { SymbolView } from 'expo-symbols';
import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';

import { Card } from '@/components/ui';
import { Radius, Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';

// long numbers stay on one line and shrink instead of dumping the last digit on a new row
export function CopyRow({ label, value }: { label: string; value: string }) {
  const c = useTheme();
  const { tx } = useI18n();
  const { notify } = useHaptics();
  const [copied, setCopied] = useState(false);
  return (
    <Card style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three }}>
      <View style={{ flex: 1, gap: 2 }}>
        <Text style={{ color: c.textSecondary, fontSize: 12, fontWeight: '600', textTransform: 'uppercase' }}>{label}</Text>
        <Text
          selectable
          numberOfLines={1}
          adjustsFontSizeToFit
          minimumFontScale={0.6}
          style={{ color: c.text, fontSize: 17, fontWeight: '700', fontVariant: ['tabular-nums'] }}>
          {value}
        </Text>
      </View>
      <Pressable
        onPress={async () => {
          await Clipboard.setStringAsync(value);
          notify();
          setCopied(true);
          setTimeout(() => setCopied(false), 1500);
        }}
        style={({ pressed }) => ({
          flexDirection: 'row',
          alignItems: 'center',
          gap: 4,
          backgroundColor: copied ? c.success : c.brandSubtle,
          borderRadius: Radius.pill,
          paddingHorizontal: 12,
          paddingVertical: 7,
          opacity: pressed ? 0.7 : 1,
        })}>
        <SymbolView name={copied ? 'checkmark' : 'doc.on.doc'} tintColor={copied ? '#FFFFFF' : c.brand} size={13} />
        <Text style={{ color: copied ? '#FFFFFF' : c.brand, fontSize: 13, fontWeight: '700' }}>
          {copied ? tx.v2.payments.copied : tx.v2.payments.copy}
        </Text>
      </Pressable>
    </Card>
  );
}