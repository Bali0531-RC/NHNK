import { TabStack } from '@/components/tab-stack';
import { useI18n } from '@/i18n';

export default function Layout() {
  const { t } = useI18n();
  return <TabStack name="payments" title={t.tabs.payments} />;
}