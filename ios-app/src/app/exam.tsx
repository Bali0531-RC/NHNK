import {
  Button,
  ConfirmationDialog,
  DatePicker,
  Form,
  Host,
  RNHostView,
  Section,
  Text as SText,
  TextField,
  Toggle,
  useNativeState,
} from '@expo/ui/swift-ui';
import { font, foregroundStyle, tint } from '@expo/ui/swift-ui/modifiers';
import { File } from 'expo-file-system';
import * as Haptics from 'expo-haptics';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { router, Stack, useLocalSearchParams } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';

import { Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { importPhoto, isLoose, newExamId, photoUri, removeExam, saveExam, useExams, type ManualExam } from '@/lib/exams';
import { iosMajor } from '@/lib/ios';
import { ensurePermission, rescheduleReminders } from '@/lib/notifications';
import { loadPrefs } from '@/providers/preferences';

// add / edit one hand-made exam. pinned to the lesson it was opened from, or loose when it came from a + button
export default function ExamEditor() {
  const c = useTheme();
  const { t, tx } = useI18n();
  const s = tx.v2.exams;
  const { notify, selection } = useHaptics();
  const p = useLocalSearchParams<{ id?: string; title?: string; start?: string; end?: string; instance?: string; at?: string }>();
  const existing = useExams().find((x) => x.id === p.id);
  const [opened] = useState(() => Date.now());
  const lessonStart = Number(p.start) || opened;
  const loose = existing ? isLoose(existing) : !p.title;
  const lessonTitle = existing?.lesson.title ?? p.title ?? '';

  const [title, setTitle] = useState(existing?.title ?? '');
  const [notes, setNotes] = useState(existing?.notes ?? '');
  const [at, setAt] = useState(() => new Date(existing?.atMs ?? (Number(p.at) || lessonStart)));
  const [photos, setPhotos] = useState<string[]>(existing?.photos ?? []);
  const [evening, setEvening] = useState(existing?.remindEvening ?? true);
  const [hour, setHour] = useState(existing?.remindHour ?? true);
  const [confirm, setConfirm] = useState(false);
  const titleState = useNativeState(title);
  const notesState = useNativeState(notes);

  const addPhotos = async () => {
    selection();
    const res = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsMultipleSelection: true,
      selectionLimit: 8,
      quality: 0.85,
    });
    if (res.canceled) return;
    const names = (await Promise.all(res.assets.map((a) => importPhoto(a.uri)))).filter((x): x is string => !!x);
    if (names.length) {
      notify();
      setPhotos((cur) => [...cur, ...names]);
    }
  };

  const save = async () => {
    const exam: ManualExam = {
      id: existing?.id ?? newExamId(),
      title: title.trim() || s.badge,
      notes: notes.trim(),
      atMs: at.getTime(),
      photos,
      remindEvening: evening,
      remindHour: hour,
      // editing keeps whatever it hung on, a loose one stays loose
      lesson:
        existing?.lesson ??
        (loose
          ? { title: '', startMs: 0, endMs: 0, instance: '' }
          : { title: p.title ?? '', startMs: lessonStart, endMs: Number(p.end) || lessonStart, instance: p.instance ?? '' }),
    };
    await saveExam(exam);
    notify(Haptics.NotificationFeedbackType.Success);
    router.back();
    // the save tap is the ask, reminders are useless without the permission
    if (evening || hour) await ensurePermission();
    await rescheduleReminders(await loadPrefs());
  };

  const remove = async () => {
    if (!existing) return;
    await removeExam(existing.id);
    notify(Haptics.NotificationFeedbackType.Warning);
    router.back();
    await rescheduleReminders(await loadPrefs());
  };

  const note = (text: string) => <SText modifiers={[font({ size: 12 }), foregroundStyle(c.textSecondary)]}>{text}</SText>;

  return (
    <>
      <Stack.Screen options={{ title: s.title }} />
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button icon="checkmark" variant={iosMajor >= 26 ? 'prominent' : 'done'} accessibilityLabel={s.save} onPress={() => void save()} />
      </Stack.Toolbar>
      <Host style={{ flex: 1 }} colorScheme={c.scheme}>
        <ConfirmationDialog title={s.remove} titleVisibility="visible" isPresented={confirm} onIsPresentedChange={setConfirm}>
          <ConfirmationDialog.Trigger>
            <Form modifiers={[tint(c.brand)]}>
              <Section footer={note(loose ? s.looseNote : lessonTitle)}>
                <TextField text={titleState} placeholder={loose ? s.looseNamePlaceholder : s.namePlaceholder} onTextChange={setTitle} />
                <DatePicker
                  title={tx.v2.calendar.time}
                  selection={at}
                  displayedComponents={['date', 'hourAndMinute']}
                  onDateChange={(d) => {
                    selection();
                    setAt(d);
                  }}
                />
              </Section>

              <Section title={s.notes}>
                <TextField text={notesState} placeholder={s.notesPlaceholder} axis="vertical" onTextChange={setNotes} />
              </Section>

              <Section title={s.photos}>
                {photos.length ? (
                  <RNHostView matchContents>
                    <ScrollView
                      horizontal
                      showsHorizontalScrollIndicator={false}
                      contentContainerStyle={{ gap: Spacing.two, paddingVertical: Spacing.one }}>
                      {photos.map((name) => (
                        <View key={name}>
                          <Pressable onPress={() => void new File(photoUri(name)).preview().catch(() => {})}>
                            <Image
                              source={{ uri: photoUri(name) }}
                              style={{ width: 84, height: 84, borderRadius: 12 }}
                              contentFit="cover"
                            />
                          </Pressable>
                          <Pressable
                            hitSlop={8}
                            accessibilityLabel={s.removePhoto}
                            onPress={() => {
                              selection();
                              setPhotos((cur) => cur.filter((x) => x !== name));
                            }}
                            style={{ position: 'absolute', top: 4, right: 4 }}>
                            <SymbolView name="xmark.circle.fill" size={22} tintColor="#FFFFFF" />
                          </Pressable>
                        </View>
                      ))}
                    </ScrollView>
                  </RNHostView>
                ) : null}
                <Button label={s.addPhoto} systemImage="photo.badge.plus" onPress={() => void addPhotos()} />
              </Section>

              <Section title={s.remind} footer={note(s.localNote)}>
                <Toggle
                  label={s.remindEvening}
                  systemImage="moon.stars"
                  isOn={evening}
                  onIsOnChange={(v) => {
                    selection();
                    setEvening(v);
                  }}
                />
                <Toggle
                  label={s.remindHour}
                  systemImage="alarm"
                  isOn={hour}
                  onIsOnChange={(v) => {
                    selection();
                    setHour(v);
                  }}
                />
              </Section>

              {existing ? (
                <Section>
                  <Button
                    label={s.remove}
                    systemImage="trash"
                    role="destructive"
                    onPress={() => {
                      notify(Haptics.NotificationFeedbackType.Warning);
                      setConfirm(true);
                    }}
                  />
                </Section>
              ) : null}
            </Form>
          </ConfirmationDialog.Trigger>
          <ConfirmationDialog.Actions>
            <Button label={s.remove} role="destructive" onPress={() => void remove()} />
            <Button label={t.common.cancel} role="cancel" onPress={() => setConfirm(false)} />
          </ConfirmationDialog.Actions>
          <ConfirmationDialog.Message>
            <SText>{s.removeConfirm}</SText>
          </ConfirmationDialog.Message>
        </ConfirmationDialog>
      </Host>
    </>
  );
}