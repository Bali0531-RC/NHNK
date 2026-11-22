import { useMemo } from 'react';

import { palette, type Palette } from '@/constants/theme';
import { usePreferences } from '@/providers/preferences';

// colours for the current look and scheme
export function useTheme(): Palette {
  const { resolvedScheme, themeStyle } = usePreferences();
  return useMemo(() => palette(themeStyle, resolvedScheme), [themeStyle, resolvedScheme]);
}