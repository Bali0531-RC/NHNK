import { ItemTabs } from '@/components/item-list';
import { ScreenTitle } from '@/components/screen';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useI18n } from '@/i18n';
import { getDocuments } from '@/neptun/data';

export default function DocumentsScreen() {
  const { tx } = useI18n();
  const official = useNeptunQuery('documents.official', () => getDocuments('official'));
  const uploaded = useNeptunQuery('documents.uploaded', () => getDocuments('uploaded'));
  const tr = useNeptunQuery('documents.tr', () => getDocuments('tr'));
  return (
    <>
      <ScreenTitle title={tx.v2.documents.title} />
      <ItemTabs
        empty={tx.v2.documents.empty}
        tabs={[
          { key: 'official', label: tx.v2.documents.official, query: official, icon: 'doc.text.fill' },
          { key: 'uploaded', label: tx.v2.documents.uploaded, query: uploaded, icon: 'square.and.arrow.up.fill' },
          { key: 'tr', label: tx.v2.documents.tr, query: tr, icon: 'checkmark.seal.fill' },
        ]}
      />
    </>
  );
}