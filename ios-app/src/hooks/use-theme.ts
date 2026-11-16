import { Colors } from '@/constants/theme';
import { useResolvedScheme } from '@/providers/preferences';

// Colours for the active scheme. The scheme comes from the user's theme override (which
// falls back to the system setting), not straight from the OS.
export function useTheme() {
  const scheme = useResolvedScheme();
  return Colors[scheme];
}
