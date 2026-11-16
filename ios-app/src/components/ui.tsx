import { useEffect, useRef } from 'react';
import {
  Animated,
  Pressable,
  Text,
  View,
  type DimensionValue,
  type TextProps,
  type ViewProps,
} from 'react-native';

import { Radius, Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useTheme } from '@/hooks/use-theme';

export function Card({ style, children, ...rest }: ViewProps) {
  const c = useTheme();
  return (
    <View
      {...rest}
      style={[
        {
          backgroundColor: c.card,
          borderRadius: Radius.lg,
          padding: Spacing.three,
          borderCurve: 'continuous',
          boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
        },
        style,
      ]}>
      {children}
    </View>
  );
}

export function SectionLabel({ children }: { children: string }) {
  const c = useTheme();
  return (
    <Text
      style={{
        color: c.textSecondary,
        fontSize: 13,
        fontWeight: '600',
        textTransform: 'uppercase',
        letterSpacing: 0.4,
        marginLeft: Spacing.one,
      }}>
      {children}
    </Text>
  );
}

export function Separator() {
  const c = useTheme();
  return <View style={{ height: 1, backgroundColor: c.separator }} />;
}

export function Chip({ label, color, textColor }: { label: string; color: string; textColor: string }) {
  return (
    <View
      style={{
        backgroundColor: color,
        borderRadius: Radius.sm,
        paddingHorizontal: Spacing.two,
        paddingVertical: Spacing.half + 1,
        borderCurve: 'continuous',
        minWidth: 30,
        alignItems: 'center',
      }}>
      <Text style={{ color: textColor, fontWeight: '700', fontVariant: ['tabular-nums'] }}>{label}</Text>
    </View>
  );
}

export function StatTile({ value, label, accent }: { value: string; label: string; accent?: string }) {
  const c = useTheme();
  return (
    <Card style={{ flex: 1, gap: Spacing.one }}>
      <Text
        selectable
        style={{ color: accent ?? c.text, fontSize: 28, fontWeight: '700', fontVariant: ['tabular-nums'] }}>
        {value}
      </Text>
      <Text style={{ color: c.textSecondary, fontSize: 13 }}>{label}</Text>
    </Card>
  );
}

// A pulsing placeholder for data that is still loading. Uses the RN Animated driver so it
// stays smooth without pulling in anything reanimated-specific.
export function Skeleton({
  width,
  height,
  radius = Radius.sm,
}: {
  width: DimensionValue;
  height: number;
  radius?: number;
}) {
  const c = useTheme();
  const opacity = useRef(new Animated.Value(0.4)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(opacity, { toValue: 0.85, duration: 750, useNativeDriver: true }),
        Animated.timing(opacity, { toValue: 0.4, duration: 750, useNativeDriver: true }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [opacity]);
  return (
    <Animated.View
      style={{ width, height, borderRadius: radius, backgroundColor: c.backgroundSelected, opacity, borderCurve: 'continuous' }}
    />
  );
}

export type SegmentOption<T extends string> = { value: T; label: string };

// Segmented pill selector shared by the language and theme pickers so they look identical.
export function Segmented<T extends string>({
  options,
  value,
  onChange,
}: {
  options: SegmentOption<T>[];
  value: T;
  onChange: (value: T) => void;
}) {
  const c = useTheme();
  const { selection } = useHaptics();
  return (
    <View style={{ flexDirection: 'row', gap: Spacing.one + 2 }}>
      {options.map((opt) => {
        const active = opt.value === value;
        return (
          <Pressable
            key={opt.value}
            onPress={() => {
              if (!active) {
                selection();
                onChange(opt.value);
              }
            }}
            style={{
              flex: 1,
              paddingVertical: Spacing.three - 2,
              borderRadius: Radius.md,
              alignItems: 'center',
              backgroundColor: active ? c.brand : c.card,
              borderCurve: 'continuous',
            }}>
            <Text style={{ color: active ? c.brandOn : c.textSecondary, fontWeight: '700' }}>{opt.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export function Body({ style, ...rest }: TextProps) {
  const c = useTheme();
  return <Text {...rest} style={[{ color: c.text, fontSize: 16 }, style]} />;
}

export function Muted({ style, ...rest }: TextProps) {
  const c = useTheme();
  return <Text {...rest} style={[{ color: c.textSecondary, fontSize: 14 }, style]} />;
}
