import { Host, Picker, Text as SText } from '@expo/ui/swift-ui';
import { pickerStyle, tag } from '@expo/ui/swift-ui/modifiers';
import { GlassView, isLiquidGlassAvailable } from 'expo-glass-effect';
import { useEffect, type ReactNode } from 'react';
import { Pressable, Text, View, type DimensionValue, type StyleProp, type TextProps, type ViewProps, type ViewStyle } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withRepeat, withTiming } from 'react-native-reanimated';

import { Radius, Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useTheme } from '@/hooks/use-theme';

const glass = isLiquidGlassAvailable();

// ios inset grouped card, android gets the hairline one
export function Card({ style, children, ...rest }: ViewProps) {
  const c = useTheme();
  const native = c.style === 'native';
  return (
    <View
      {...rest}
      style={[
        {
          backgroundColor: c.card,
          borderRadius: native ? 26 : Radius.lg,
          padding: Spacing.three,
          borderCurve: 'continuous',
          borderWidth: native ? 0 : 1,
          borderColor: c.cardBorder,
        },
        style,
      ]}>
      {children}
    </View>
  );
}

// Liquid glass on iOS 26 in the native look; a normal card everywhere else.
export function GlassCard({
  style,
  children,
  interactive,
  tint,
}: {
  style?: StyleProp<ViewStyle>;
  children: ReactNode;
  interactive?: boolean;
  tint?: string;
}) {
  const c = useTheme();
  if (glass && c.style === 'native') {
    return (
      <GlassView
        glassEffectStyle="regular"
        isInteractive={interactive}
        tintColor={tint}
        colorScheme={c.scheme}
        style={[{ borderRadius: 26, padding: Spacing.three, borderCurve: 'continuous', overflow: 'hidden' }, style]}>
        {children}
      </GlassView>
    );
  }
  return <Card style={[tint ? { backgroundColor: tint } : null, style]}>{children}</Card>;
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
        marginLeft: Spacing.three,
      }}>
      {children}
    </Text>
  );
}

export function Separator({ inset = 0 }: { inset?: number }) {
  const c = useTheme();
  return <View style={{ height: 0.5, backgroundColor: c.separator, marginLeft: inset }} />;
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

export function Pill({ label, color, background }: { label: string; color: string; background: string }) {
  return (
    <View style={{ backgroundColor: background, borderRadius: Radius.pill, paddingHorizontal: 9, paddingVertical: 3 }}>
      <Text style={{ color, fontSize: 12, fontWeight: '700' }}>{label}</Text>
    </View>
  );
}

// Shimmering placeholder in the shape of the content that is loading.
export function Skeleton({ width, height, radius = Radius.sm }: { width: DimensionValue; height: number; radius?: number }) {
  const c = useTheme();
  const o = useSharedValue(0.45);
  useEffect(() => {
    o.value = withRepeat(withTiming(0.9, { duration: 800 }), -1, true);
  }, [o]);
  const style = useAnimatedStyle(() => ({ opacity: o.value }));
  return (
    <Animated.View
      style={[{ width, height, borderRadius: radius, backgroundColor: c.fill, borderCurve: 'continuous' }, style]}
    />
  );
}

export function SkeletonList({ rows = 4, height = 72 }: { rows?: number; height?: number }) {
  return (
    <View style={{ gap: Spacing.two }}>
      {Array.from({ length: rows }, (_, i) => (
        <Card key={i} style={{ gap: Spacing.two }}>
          <Skeleton width="55%" height={16} />
          <Skeleton width="85%" height={12} />
          {height > 60 ? <Skeleton width="35%" height={12} /> : null}
        </Card>
      ))}
    </View>
  );
}

export type SegmentOption<T extends string> = { value: T; label: string };

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
  if (process.env.EXPO_OS === 'ios' && c.style === 'native') {
    return (
      <Host matchContents={{ vertical: true }} colorScheme={c.scheme} style={{ alignSelf: 'stretch' }}>
        <Picker
          selection={value}
          onSelectionChange={(v: string) => {
            if (v === value) return;
            selection();
            onChange(v as T);
          }}
          modifiers={[pickerStyle('segmented')]}>
          {options.map((o) => (
            <SText key={o.value} modifiers={[tag(o.value)]}>
              {o.label}
            </SText>
          ))}
        </Picker>
      </Host>
    );
  }
  return (
    <View style={{ flexDirection: 'row', gap: 2, backgroundColor: c.fill, borderRadius: Radius.md, padding: 2 }}>
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
              paddingVertical: Spacing.two,
              borderRadius: Radius.md - 2,
              alignItems: 'center',
              backgroundColor: active ? c.card : 'transparent',
              borderCurve: 'continuous',
              boxShadow: active ? '0 1px 3px rgba(0,0,0,0.12)' : undefined,
            }}>
            <Text style={{ color: active ? c.text : c.textSecondary, fontWeight: '600', fontSize: 14 }}>{opt.label}</Text>
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