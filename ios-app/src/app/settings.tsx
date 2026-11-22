import { Button, Form, Host, Picker, Section, Stepper, Text as SText, Toggle } from '@expo/ui/swift-ui';
import { disabled, font, foregroundStyle, pickerStyle, tag, tint } from '@expo/ui/swift-ui/modifiers';
import * as Haptics from 'expo-haptics';
import { router, Stack } from 'expo-router';
import { useEffect, useState } from 'react';
import { Alert, Linking } from 'react-native';

import { ScreenTitle } from '@/components/screen';
import { useHaptics } from '@/hooks/use-haptics';
import { useHiddenMessages } from '@/hooks/use-message-state';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import type { Lang } from '@/i18n/strings';
import { ensurePermission, sendTest } from '@/lib/notifications';
import { eraseEverything } from '@/lib/wipe';
import { clearDataCache } from '@/neptun/cache';
import { Store } from '@/neptun/storage';
import { extractTotpSecret } from '@/neptun/totp';
import { checkBiometric, useAppLock } from '@/providers/app-lock';
import { useAuth } from '@/providers/auth';
import { usePreferences, type ThemeMode } from '@/providers/preferences';
import type { ThemeStyle } from '@/constants/theme';

const LEADS = [5, 10, 15, 30, 60];

export default function SettingsScreen() {
  const c = useTheme();
  const { t, tx, lang, setLang } = useI18n();
  const s = tx.v2.settings;
  const { isDemo } = useAuth();
  const prefs = usePreferences();
  const { set } = prefs;
  const { notify, selection } = useHaptics();
  const { grant } = useAppLock();
  const { hidden, unhideAll } = useHiddenMessages();

  const [totpSaved, setTotpSaved] = useState(false);
  useEffect(() => {
    let active = true;
    void Store.getTotpSecret().then((v) => {
      if (active) setTotpSaved(!!v);
    });
    return () => {
      active = false;
    };
  }, []);

  const toggle = <K extends 'haptics' | 'notifyMessages' | 'notifyClasses' | 'notifyExams' | 'notifyPayments' | 'notifyPeriods' | 'backgroundSync' | 'showOfficeHours' | 'showPeriodsInCalendar'>(
    key: K,
  ) => (on: boolean) => {
    selection();
    set(key, on);
    // flipping a notification on is the user asking, so this is the one place besides onboarding that prompts
    if (on && key.startsWith('notify')) void ensurePermission().then((ok) => (ok ? null : deniedAlert()));
  };

  const deniedAlert = () =>
    Alert.alert(s.notifications, s.permissionDenied, [
      { text: t.common.cancel, style: 'cancel' },
      { text: s.openSettings, onPress: () => void Linking.openSettings() },
    ]);

  const toggleBiometric = async (on: boolean) => {
    if (!on) {
      selection();
      prefs.setBiometricLock(false);
      return;
    }
    const res = await checkBiometric(t.lock.prompt, t.common.cancel);
    if (res === 'ok') {
      grant();
      prefs.setBiometricLock(true);
      notify();
    } else if (res !== 'cancel') {
      notify(Haptics.NotificationFeedbackType.Error);
      Alert.alert(t.settings.biometric, res === 'unavailable' ? t.settings.biometricUnavailable : tx.v2.perms.faceDenied, [
        { text: t.common.cancel, style: 'cancel' },
        { text: s.openSettings, onPress: () => void Linking.openSettings() },
      ]);
    }
  };

  const test = async (timeSensitive: boolean) => {
    const ok = await sendTest(timeSensitive);
    if (ok) {
      notify();
      Alert.alert(timeSensitive ? s.testTimeSensitive : s.testPush, s.testSent);
    } else {
      notify(Haptics.NotificationFeedbackType.Error);
      deniedAlert();
    }
  };

  const manageTotp = () => {
    if (totpSaved) {
      Alert.alert(t.settings.twoFactorKey, t.settings.twoFactorClearConfirm, [
        { text: t.common.cancel, style: 'cancel' },
        {
          text: t.settings.clear,
          style: 'destructive',
          onPress: async () => {
            await Store.setTotpSecret(null);
            setTotpSaved(false);
          },
        },
      ]);
      return;
    }
    Alert.prompt(
      t.settings.twoFactorKey,
      t.settings.twoFactorPrompt,
      [
        { text: t.common.cancel, style: 'cancel' },
        {
          text: t.common.save,
          onPress: async (value?: string) => {
            const secret = value ? extractTotpSecret(value) : null;
            if (!secret) {
              Alert.alert(t.settings.twoFactorKey, t.settings.twoFactorInvalid);
              return;
            }
            await Store.setTotpSecret(secret);
            setTotpSaved(true);
            notify();
          },
        },
      ],
      'plain-text',
    );
  };

  const wipeCache = () =>
    Alert.alert(s.clearCache, s.clearCacheConfirm, [
      { text: t.common.cancel, style: 'cancel' },
      {
        text: t.settings.clear,
        style: 'destructive',
        onPress: () => {
          clearDataCache();
          notify();
          Alert.alert(s.clearCache, s.cleared);
        },
      },
    ]);

  const resetApp = () =>
    Alert.alert(s.resetApp, s.resetAppConfirm, [
      { text: t.common.cancel, style: 'cancel' },
      {
        text: s.resetAppAction,
        style: 'destructive',
        onPress: () => {
          notify(Haptics.NotificationFeedbackType.Warning);
          void eraseEverything();
        },
      },
    ]);

  const note = (text: string) => <SText modifiers={[font({ size: 12 }), foregroundStyle(c.textSecondary)]}>{text}</SText>;

  return (
    <>
      <ScreenTitle title={t.settings.title} />
      <Stack.Screen options={{ headerTransparent: false, headerLargeTitle: false, headerStyle: { backgroundColor: c.background } }} />
      <Host style={{ flex: 1 }} colorScheme={c.scheme}>
        <Form modifiers={[tint(c.brand)]}>
          {isDemo ? <Section>{note(t.settings.demoBanner)}</Section> : null}

          <Section title={t.settings.appearance} footer={note(s.styleNote)}>
            <Picker
              label={s.style}
              selection={prefs.themeStyle}
              onSelectionChange={(v: string) => {
                selection();
                set('themeStyle', v as ThemeStyle);
              }}
              modifiers={[pickerStyle('segmented')]}>
              <SText modifiers={[tag('native')]}>{s.styleNative}</SText>
              <SText modifiers={[tag('android')]}>{s.styleAndroid}</SText>
            </Picker>
            <Picker
              label={s.mode}
              selection={prefs.themeMode}
              onSelectionChange={(v: string) => {
                selection();
                prefs.setThemeMode(v as ThemeMode);
              }}
              modifiers={[pickerStyle('segmented')]}>
              <SText modifiers={[tag('system')]}>{t.settings.themeSystem}</SText>
              <SText modifiers={[tag('light')]}>{t.settings.themeLight}</SText>
              <SText modifiers={[tag('dark')]}>{t.settings.themeDark}</SText>
            </Picker>
            <Picker
              label={t.settings.language}
              systemImage="globe"
              selection={lang}
              onSelectionChange={(v: string) => setLang(v as Lang)}
              modifiers={[pickerStyle('menu')]}>
              <SText modifiers={[tag('hu')]}>Magyar</SText>
              <SText modifiers={[tag('en')]}>English</SText>
              <SText modifiers={[tag('de')]}>Deutsch</SText>
            </Picker>
          </Section>

          <Section title={s.notifications}>
            <Toggle label={s.notifyMessages} systemImage="envelope.badge" isOn={prefs.notifyMessages} onIsOnChange={toggle('notifyMessages')} />
            <Toggle label={s.notifyClasses} systemImage="bell.badge" isOn={prefs.notifyClasses} onIsOnChange={toggle('notifyClasses')} />
            {prefs.notifyClasses ? (
              <Picker
                label={s.leadTime}
                systemImage="timer"
                selection={prefs.classLeadMinutes}
                onSelectionChange={(v: number) => set('classLeadMinutes', v)}
                modifiers={[pickerStyle('menu')]}>
                {LEADS.map((m) => (
                  <SText key={m} modifiers={[tag(m)]}>
                    {s.minutes(m)}
                  </SText>
                ))}
              </Picker>
            ) : null}
            <Toggle label={s.notifyExams} systemImage="graduationcap" isOn={prefs.notifyExams} onIsOnChange={toggle('notifyExams')} />
            <Toggle label={s.notifyPayments} systemImage="creditcard" isOn={prefs.notifyPayments} onIsOnChange={toggle('notifyPayments')} />
            <Toggle label={s.notifyPeriods} systemImage="flag" isOn={prefs.notifyPeriods} onIsOnChange={toggle('notifyPeriods')} />
            <Button label={s.testPush} systemImage="paperplane" onPress={() => void test(false)} />
            <Button label={s.testTimeSensitive} systemImage="exclamationmark.bubble" onPress={() => void test(true)} />
          </Section>

          <Section footer={note(s.backgroundSyncNote)}>
            <Toggle label={s.backgroundSync} systemImage="arrow.triangle.2.circlepath" isOn={prefs.backgroundSync} onIsOnChange={toggle('backgroundSync')} />
          </Section>

          <Section title={s.timetable} footer={note(s.weekShiftNote)}>
            <Toggle label={s.officeHours} systemImage="person.crop.circle.badge.clock" isOn={prefs.showOfficeHours} onIsOnChange={toggle('showOfficeHours')} />
            <Toggle label={s.periodsInCalendar} systemImage="calendar.badge.exclamationmark" isOn={prefs.showPeriodsInCalendar} onIsOnChange={toggle('showPeriodsInCalendar')} />
            <Stepper
              label={`${s.weekShift}: ${prefs.weekShift > 0 ? '+' : ''}${prefs.weekShift}`}
              value={prefs.weekShift}
              min={-4}
              max={4}
              step={1}
              onValueChange={(v) => {
                selection();
                set('weekShift', v);
              }}
            />
          </Section>

          {!isDemo ? (
            <Section title={t.settings.security} footer={note(totpSaved ? t.settings.twoFactorSaved : t.settings.twoFactorNotSaved)}>
              <Toggle label={t.settings.biometric} systemImage="faceid" isOn={prefs.biometricLock} onIsOnChange={(on) => void toggleBiometric(on)} />
              <Button label={t.settings.twoFactorKey} systemImage={totpSaved ? 'key.fill' : 'key'} onPress={manageTotp} />
            </Section>
          ) : null}

          <Section footer={note(tx.v2.tutorial.body)}>
            <Button
              label={tx.v2.tutorial.link}
              systemImage="play.circle.fill"
              modifiers={[tint(c.scheme === 'dark' ? '#0A84FF' : '#007AFF')]}
              onPress={() => router.push('/tutorial')}
            />
          </Section>

          <Section title={s.system}>
            <Toggle label={t.settings.haptics} systemImage="hand.tap" isOn={prefs.haptics} onIsOnChange={toggle('haptics')} />
            <Button label={s.replayOnboarding} systemImage="sparkles" onPress={() => prefs.setOnboardingSeen(false)} />
            <Button
              label={s.restoreMessages(hidden.length)}
              systemImage="arrow.uturn.backward"
              modifiers={[disabled(hidden.length === 0)]}
              onPress={() => {
                unhideAll();
                notify();
              }}
            />
            <Button label={t.menu.about} systemImage="info.circle" onPress={() => router.push('/about')} />
            <Button label={s.clearCache} systemImage="trash" role="destructive" onPress={wipeCache} />
            <Button label={s.resetApp} systemImage="arrow.counterclockwise.circle" role="destructive" onPress={resetApp} />
          </Section>
        </Form>
      </Host>
    </>
  );
}