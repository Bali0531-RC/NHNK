import { NativeTabs } from 'expo-router/native-tabs';

import { SideMenu } from '@/components/side-menu';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { getMessages } from '@/neptun/data';
import { useHiddenMessages } from '@/hooks/use-message-state';

export const unstable_settings = { initialRouteName: '(calendar)' };

export default function TabsLayout() {
  const c = useTheme();
  const { t } = useI18n();
  // Shares the Messages screen's cache key and local read state, so badge and list agree.
  const messages = useNeptunQuery('messages', getMessages);
  const { isUnread, hidden } = useHiddenMessages();
  const unread = (messages.data ?? []).filter((m) => !hidden.includes(m.id) && isUnread(m)).length;
  const native = c.style === 'native';

  return (
    <SideMenu>
      <NativeTabs
        tintColor={native ? undefined : c.brandText}
        backgroundColor={native ? undefined : c.tabBar}
        badgeBackgroundColor={native ? undefined : c.brand}
        minimizeBehavior={native ? 'onScrollDown' : undefined}>
        <NativeTabs.Trigger name="(calendar)">
          <NativeTabs.Trigger.Label>{t.tabs.calendar}</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon sf={{ default: 'calendar', selected: 'calendar' }} />
        </NativeTabs.Trigger>
        <NativeTabs.Trigger name="(subjects)">
          <NativeTabs.Trigger.Label>{t.tabs.subjects}</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon sf={{ default: 'books.vertical', selected: 'books.vertical.fill' }} />
        </NativeTabs.Trigger>
        <NativeTabs.Trigger name="(payments)">
          <NativeTabs.Trigger.Label>{t.tabs.payments}</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon sf={{ default: 'creditcard', selected: 'creditcard.fill' }} />
        </NativeTabs.Trigger>
        <NativeTabs.Trigger name="(periods)">
          <NativeTabs.Trigger.Label>{t.tabs.periods}</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon sf={{ default: 'clock', selected: 'clock.fill' }} />
        </NativeTabs.Trigger>
        <NativeTabs.Trigger name="(messages)">
          <NativeTabs.Trigger.Label>{t.tabs.messages}</NativeTabs.Trigger.Label>
          <NativeTabs.Trigger.Icon sf={{ default: 'envelope', selected: 'envelope.fill' }} />
          {unread > 0 ? <NativeTabs.Trigger.Badge>{String(unread)}</NativeTabs.Trigger.Badge> : null}
        </NativeTabs.Trigger>
      </NativeTabs>
    </SideMenu>
  );
}