import { useEffect, type ReactNode } from 'react';
import { View, type StyleProp, type ViewStyle } from 'react-native';
import Animated, { Easing, useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

import { Radius, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';

// hex + alpha, anything else (rgba, named) passes through untouched
export function withAlpha(color: string, alpha: number): string {
  if (!/^#[0-9a-f]{6}$/i.test(color)) return color;
  return `${color}${Math.round(Math.min(1, Math.max(0, alpha)) * 255)
    .toString(16)
    .padStart(2, '0')}`;
}

// the whole card is the progress bar. glowing leading edge, eases in on mount
export function FillCard({
  progress,
  color,
  style,
  children,
}: {
  progress: number;
  color: string;
  style?: StyleProp<ViewStyle>;
  children: ReactNode;
}) {
  const c = useTheme();
  const target = Number.isFinite(progress) ? Math.min(1, Math.max(0, progress)) : 0;
  const p = useSharedValue(0);

  useEffect(() => {
    p.set(withTiming(target, { duration: 800, easing: Easing.out(Easing.cubic) }));
  }, [p, target]);

  const fill = useAnimatedStyle(() => ({ width: `${p.get() * 100}%` }));

  return (
    <View
      style={[
        {
          backgroundColor: c.card,
          borderRadius: c.style === 'native' ? 22 : Radius.lg,
          borderCurve: 'continuous',
          overflow: 'hidden',
        },
        style,
      ]}>
      {target > 0 ? (
        <Animated.View
          style={[
            {
              position: 'absolute',
              top: 0,
              bottom: 0,
              left: 0,
              experimental_backgroundImage: `linear-gradient(90deg, ${withAlpha(color, 0.06)} 0%, ${withAlpha(color, 0.28)} 100%)`,
              borderRightWidth: target < 1 ? 2 : 0,
              borderRightColor: withAlpha(color, 0.9),
              boxShadow: `4px 0 18px ${withAlpha(color, 0.45)}`,
            },
            fill,
          ]}
        />
      ) : null}
      <View style={{ padding: Spacing.three }}>{children}</View>
    </View>
  );
}