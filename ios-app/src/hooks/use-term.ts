import { usePersistentState } from '@/hooks/use-persistent-state';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { getTerms } from '@/neptun/data';

export type TermPick = { id: string; latest: string } | null;

// a pick only holds while the newest term is the same one it was made under, so a new semester always opens on itself
export function pickedTerm(pick: TermPick, latest: string | undefined): string | null {
  return pick && latest && pick.latest === latest ? pick.id : null;
}

// picked term, defaults to the last one cuz neptun sorts oldest first
export function useTerm() {
  const terms = useNeptunQuery('terms', getTerms);
  const [pick, setPick] = usePersistentState<TermPick>('termPick', null);
  const list = terms.data ?? [];
  const latest = list[list.length - 1]?.id;
  const picked = pickedTerm(pick, latest);
  const termId = (picked && list.some((x) => x.id === picked) ? picked : null) ?? latest ?? null;
  const termName = list.find((x) => x.id === termId)?.name ?? '';
  const isLatest = termId != null && termId === latest;
  const setTermId = (id: string) => setPick(latest ? { id, latest } : null);
  return { terms, list, termId, termName, isLatest, setTermId };
}