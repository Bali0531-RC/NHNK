import { useCallback } from 'react';

import { usePersistentState } from '@/hooks/use-persistent-state';
import type { Override, OverrideMap } from '@/lib/grades';

// planned grades per term, local only until reset
export function useOverrides(termId: string | null) {
  const [all, setAll] = usePersistentState<Record<string, OverrideMap>>('subject-overrides', {});
  const map = (termId && all[termId]) || {};

  const setOverride = useCallback(
    (subjectId: string, patch: Override | null) => {
      if (!termId) return;
      setAll((prev) => {
        const term = { ...(prev[termId] ?? {}) };
        if (patch === null) delete term[subjectId];
        else {
          const merged = { ...(term[subjectId] ?? {}), ...patch };
          if (merged.grade === undefined) delete merged.grade;
          if (merged.completed === undefined) delete merged.completed;
          if (Object.keys(merged).length) term[subjectId] = merged;
          else delete term[subjectId];
        }
        return { ...prev, [termId]: term };
      });
    },
    [termId, setAll],
  );

  const resetTerm = useCallback(() => {
    if (!termId) return;
    setAll((prev) => ({ ...prev, [termId]: {} }));
  }, [termId, setAll]);

  return { overrides: map, setOverride, resetTerm };
}