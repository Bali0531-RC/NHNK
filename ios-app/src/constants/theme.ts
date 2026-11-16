import { Platform } from 'react-native';

// iOS grouped-list feel: a slightly recessed page background with cards sitting on top.
// Light/dark values track Apple's system palette so the app looks native in both.
export const Colors = {
  light: {
    text: '#000000',
    textSecondary: '#6C6C70',
    textTertiary: '#8E8E93',
    background: '#F2F2F7',
    card: '#FFFFFF',
    backgroundElement: '#FFFFFF',
    backgroundSelected: '#E5E5EA',
    separator: 'rgba(60,60,67,0.18)',
    brand: '#2563EB',
    brandSubtle: 'rgba(37,99,235,0.12)',
    brandOn: '#FFFFFF',
    success: '#2E9E5B',
    warning: '#C8700A',
    danger: '#D6322E',
  },
  dark: {
    text: '#FFFFFF',
    textSecondary: '#AEAEB2',
    textTertiary: '#8E8E93',
    background: '#000000',
    card: '#1C1C1E',
    backgroundElement: '#1C1C1E',
    backgroundSelected: '#2C2C2E',
    separator: 'rgba(84,84,88,0.55)',
    brand: '#5B9DFF',
    brandSubtle: 'rgba(91,157,255,0.18)',
    brandOn: '#FFFFFF',
    success: '#34C759',
    warning: '#FF9F0A',
    danger: '#FF453A',
  },
} as const;

export type ThemeColor = keyof typeof Colors.light & keyof typeof Colors.dark;

export const Fonts = Platform.select({
  ios: {
    sans: 'system-ui',
    serif: 'ui-serif',
    rounded: 'ui-rounded',
    mono: 'ui-monospace',
  },
  default: {
    sans: 'normal',
    serif: 'serif',
    rounded: 'normal',
    mono: 'monospace',
  },
  web: {
    sans: 'var(--font-display)',
    serif: 'var(--font-serif)',
    rounded: 'var(--font-rounded)',
    mono: 'var(--font-mono)',
  },
});

export const Spacing = {
  half: 2,
  one: 4,
  two: 8,
  three: 16,
  four: 24,
  five: 32,
  six: 64,
} as const;

export const Radius = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 22,
} as const;

export const BottomTabInset = Platform.select({ ios: 50, android: 80 }) ?? 0;
export const MaxContentWidth = 800;
