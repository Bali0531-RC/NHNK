import * as WebBrowser from 'expo-web-browser';
import { useEffect, useState } from 'react';

import { ItemTabs } from '@/components/item-list';
import { ScreenTitle } from '@/components/screen';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useI18n } from '@/i18n';
import { getRequestTemplates, getSubmittedRequests } from '@/neptun/data';
import { Store } from '@/neptun/storage';

export default function RequestsScreen() {
  const { tx } = useI18n();
  const templates = useNeptunQuery('requests.templates', getRequestTemplates);
  const submitted = useNeptunQuery('requests.submitted', getSubmittedRequests);
  // the app cant file requests, so send them to their own school's neptun web
  const [web, setWeb] = useState<string | null>(null);
  useEffect(() => {
    void Promise.all([Store.getInstituteUrl(), Store.getIsDemo()]).then(([url, demo]) => {
      if (!demo && url?.startsWith('https://')) setWeb(url.replace(/\/+$/, '') + '/');
    });
  }, []);
  return (
    <>
      <ScreenTitle title={tx.v2.requests.title} />
      <ItemTabs
        empty={tx.v2.requests.empty}
        hint={tx.v2.requests.hint}
        action={web ? { label: tx.v2.requests.openNeptun, onPress: () => void WebBrowser.openBrowserAsync(web).catch(() => {}) } : undefined}
        tabs={[
          { key: 'templates', label: tx.v2.requests.templates, query: templates, icon: 'doc.badge.plus' },
          { key: 'submitted', label: tx.v2.requests.submitted, query: submitted, icon: 'paperplane.fill' },
        ]}
      />
    </>
  );
}