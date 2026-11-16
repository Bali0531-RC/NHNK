import { NativeTabs } from 'expo-router/native-tabs';

import { useI18n } from '@/i18n';

export default function TabsLayout() {
  const { t } = useI18n();
  return (
    <NativeTabs>
      <NativeTabs.Trigger name="(dashboard)">
        <NativeTabs.Trigger.Label>{t.tabs.dashboard}</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf="house.fill" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(timetable)">
        <NativeTabs.Trigger.Label>{t.tabs.timetable}</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf="calendar" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(grades)">
        <NativeTabs.Trigger.Label>{t.tabs.grades}</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf="checkmark.seal.fill" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(settings)">
        <NativeTabs.Trigger.Label>{t.tabs.settings}</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf="gearshape.fill" />
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
