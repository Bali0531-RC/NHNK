import { useCallback } from 'react';

import { usePersistentState } from '@/hooks/use-persistent-state';
import type { MessageEntry } from '@/neptun/data';

type MessageState = { hidden: string[]; read: Record<string, boolean> };

// neptun cant delete or mark unread so we fake it locally
export function useHiddenMessages() {
  const [state, setState] = usePersistentState<MessageState>('message-state', { hidden: [], read: {} });

  const isUnread = useCallback(
    (m: MessageEntry) => {
      const local = state.read[m.id];
      return local === undefined ? !m.isRead : !local;
    },
    [state.read],
  );

  const setRead = useCallback(
    (ids: string[], read: boolean) =>
      setState((prev) => {
        const next = { ...prev.read };
        for (const id of ids) next[id] = read;
        return { ...prev, read: next };
      }),
    [setState],
  );

  const hide = useCallback(
    (ids: string[]) => setState((prev) => ({ ...prev, hidden: Array.from(new Set([...prev.hidden, ...ids])) })),
    [setState],
  );

  const unhideAll = useCallback(() => setState((prev) => ({ ...prev, hidden: [] })), [setState]);

  return { hidden: state.hidden, isUnread, setRead, hide, unhideAll };
}