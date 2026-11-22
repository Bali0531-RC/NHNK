import { ItemTabs } from '@/components/item-list';
import { ScreenTitle } from '@/components/screen';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useI18n } from '@/i18n';
import { getRequestTemplates, getSubmittedRequests } from '@/neptun/data';

export default function RequestsScreen() {
  const { tx } = useI18n();
  const templates = useNeptunQuery('requests.templates', getRequestTemplates);
  const submitted = useNeptunQuery('requests.submitted', getSubmittedRequests);
  return (
    <>
      <ScreenTitle title={tx.v2.requests.title} />
      <ItemTabs
        empty={tx.v2.requests.empty}
        hint={tx.v2.requests.hint}
        tabs={[
          { key: 'templates', label: tx.v2.requests.templates, query: templates, icon: 'doc.badge.plus' },
          { key: 'submitted', label: tx.v2.requests.submitted, query: submitted, icon: 'paperplane.fill' },
        ]}
      />
    </>
  );
}