import { ItemTabs } from '@/components/item-list';
import { ScreenTitle } from '@/components/screen';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useI18n } from '@/i18n';
import { getQuestionnaires } from '@/neptun/data';

export default function QuestionnairesScreen() {
  const { tx } = useI18n();
  const open = useNeptunQuery('questionnaires.open', () => getQuestionnaires(false));
  const done = useNeptunQuery('questionnaires.done', () => getQuestionnaires(true));
  return (
    <>
      <ScreenTitle title={tx.v2.questionnaires.title} />
      <ItemTabs
        empty={tx.v2.questionnaires.empty}
        dateLabel={tx.v2.questionnaires.deadline}
        tabs={[
          { key: 'open', label: tx.v2.questionnaires.toFill, query: open, icon: 'checklist' },
          { key: 'done', label: tx.v2.questionnaires.filled, query: done, icon: 'checkmark.circle.fill' },
        ]}
      />
    </>
  );
}