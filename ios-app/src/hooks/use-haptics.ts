import * as Haptics from 'expo-haptics';
import { useCallback } from 'react';

import { usePreferences } from '@/providers/preferences';

// respects the haptics toggle, ios only. android vibration sucks
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