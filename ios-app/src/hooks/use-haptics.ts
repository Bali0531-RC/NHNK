import * as Haptics from 'expo-haptics';
import { useCallback } from 'react';

import { usePreferences } from '@/providers/preferences';

// Thin wrapper so every call site respects the user's haptics toggle and only fires on iOS.
// Android's generic vibration feels nothing like these, so it is left out on purpose.
export function useHaptics() {
  const { haptics } = usePreferences();
  const enabled = haptics && process.env.EXPO_OS === 'ios';

  const selection = useCallback(() => {
    if (enabled) void Haptics.selectionAsync();
  }, [enabled]);

  const impact = useCallback(
    (style: Haptics.ImpactFeedbackStyle = Haptics.ImpactFeedbackStyle.Light) => {
      if (enabled) void Haptics.impactAsync(style);
    },
    [enabled],
  );

  const notify = useCallback(
    (type: Haptics.NotificationFeedbackType = Haptics.NotificationFeedbackType.Success) => {
      if (enabled) void Haptics.notificationAsync(type);
    },
    [enabled],
  );

  return { selection, impact, notify };
}
