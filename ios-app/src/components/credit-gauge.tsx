import { Gauge, Host, Text as SText } from '@expo/ui/swift-ui';
import { font, frame, gaugeStyle, monospacedDigit, scaleEffect, tint } from '@expo/ui/swift-ui/modifiers';
import { Text, View } from 'react-native';

import { ProgressBar } from '@/components/screen';
import { useTheme } from '@/hooks/use-theme';

// swiftui's capacity ring, the closed one that fills up. its native box is ~58pt so scale it and pin the frame, nothing bleeds out
const BASE = 58;

export function CreditGauge({ value, max, size = 120, color }: { value: number; max: number; size?: number; color?: string }) {
  const c = useTheme();
  const tone = color ?? c.live;
  const safeMax = Math.max(1, max);
  const clamped = Math.min(Math.max(0, value), safeMax);

  if (process.env.EXPO_OS === 'ios') {
    return (
      <Host colorScheme={c.scheme} style={{ width: size, height: size }}>
        <Gauge
          value={clamped}
          min={0}
          max={safeMax}
          modifiers={[gaugeStyle('circularCapacity'), tint(tone), scaleEffect(size / BASE), frame({ width: size, height: size })]}
          currentValueLabel={<SText modifiers={[font({ size: 15, weight: 'bold', design: 'rounded' }), monospacedDigit()]}>{String(value)}</SText>}
        />
      </Host>
    );
  }

  return (
    <View style={{ width: size, gap: 6, alignItems: 'center' }}>
      <Text style={{ color: c.text, fontSize: size / 4, fontWeight: '800', fontVariant: ['tabular-nums'] }}>{value}</Text>
      <ProgressBar value={clamped / safeMax} color={tone} height={6} />
    </View>
  );
}

export function CreditBar({ value, max, color }: { value: number; max: number; color?: string }) {
  const c = useTheme();
  const tone = color ?? c.live;
  const safeMax = Math.max(1, max);
  const clamped = Math.min(Math.max(0, value), safeMax);
  if (process.env.EXPO_OS !== 'ios') return <ProgressBar value={clamped / safeMax} color={tone} height={4} />;
  return (
    <Host matchContents={{ vertical: true }} colorScheme={c.scheme} style={{ alignSelf: 'stretch' }}>
      <Gauge value={clamped} min={0} max={safeMax} modifiers={[gaugeStyle('linearCapacity'), tint(tone)]} />
    </Host>
  );
}