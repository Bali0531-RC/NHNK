import {
  Button,
  ConfirmationDialog,
  ContentUnavailableView,
  DatePicker,
  HStack,
  Host,
  Image,
  List,
  Section,
  Spacer,
  SwipeActions,
  Text as SText,
  VStack,
} from '@expo/ui/swift-ui';
import {
  contentShape,
  font,
  foregroundStyle,
  lineLimit,
  listStyle,
  multilineTextAlignment,
  onTapGesture,
  padding,
  refreshable,
  shapes,
  tint,
} from '@expo/ui/swift-ui/modifiers';
import { router, Stack } from 'expo-router';
import { useState } from 'react';
import * as Haptics from 'expo-haptics';
import { View } from 'react-native';

import { DataBanner, ErrorCard, ScreenTitle, useSyncSuffix } from '@/components/screen';
import { SkeletonList } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useHiddenMessages } from '@/hooks/use-message-state';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { DAY_MS, fmtDate, hhmm, nowMs, sameDay } from '@/lib/format';
import { iosMajor } from '@/lib/ios';
import { getMessages, markMessageRead, type MessageEntry } from '@/neptun/data';
import { log } from '@/neptun/log';

type Status = 'all' | 'unread' | 'read';
// -1 = custom from/to picked with the native date pickers
type Range = 0 | 7 | 30 | 90 | -1;

// the list tint(brand) beats role=destructive on swipe buttons, delete gets its own red like the leading one gets brand
const SYSTEM_RED = '#FF3B30';
const dayStart = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();

export default function MessagesScreen() {
  const c = useTheme();
  const { t, tx, lang } = useI18n();
  const { selection, impact, notify } = useHaptics();
  const query = useNeptunQuery('messages', getMessages);
  const syncSuffix = useSyncSuffix(query.savedAt);
  const { hidden, isUnread, setRead, hide, unhideAll } = useHiddenMessages();
  const [status, setStatus] = useState<Status>('all');
  const [attachments, setAttachments] = useState(false);
  const [range, setRange] = useState<Range>(0);
  const [newestFirst, setNewestFirst] = useState(true);
  const [search, setSearch] = useState('');
  const [now, setNow] = useState(() => Date.now());
  const [from, setFrom] = useState(() => new Date(Date.now() - 30 * DAY_MS));
  const [to, setTo] = useState(() => new Date());
  const [confirmAll, setConfirmAll] = useState(false);

  const all = (query.data ?? []).filter((m) => !hidden.includes(m.id));
  const needle = search.trim().toLowerCase();
  const cutoff = range > 0 ? now - range * DAY_MS : 0;
  const lo = dayStart(from);
  const hi = dayStart(to) + DAY_MS;
  const shown = all
    .filter((m) => (status === 'unread' ? isUnread(m) : status === 'read' ? !isUnread(m) : true))
    .filter((m) => !attachments || m.hasAttachment)
    .filter((m) => !cutoff || m.dateMs >= cutoff)
    .filter((m) => range !== -1 || (m.dateMs >= lo && m.dateMs < hi))
    .filter((m) => !needle || m.subject.toLowerCase().includes(needle) || m.sender.toLowerCase().includes(needle))
    .sort((a, b) => (newestFirst ? b.dateMs - a.dateMs : a.dateMs - b.dateMs));
  const filtered = status !== 'all' || attachments || range !== 0 || !newestFirst;
  const unreadCount = all.filter(isUnread).length;

  const markRead = (ids: string[]) => {
    setRead(ids, true);
    void (async () => {
      for (const id of ids) {
        try {
          await markMessageRead(id);
        } catch (err) {
          log.warn('messages', 'mark read failed', err);
        }
      }
    })();
  };

  const toggleRead = (m: MessageEntry) => {
    impact();
    if (isUnread(m)) markRead([m.id]);
    else setRead([m.id], false);
  };

  // single swipe just goes, settings has the undo
  const remove = (m: MessageEntry) => {
    impact();
    hide([m.id]);
  };

  const confirmDelete = () => {
    notify(Haptics.NotificationFeedbackType.Success);
    hide(shown.map((m) => m.id));
    setConfirmAll(false);
  };

  const open = (m: MessageEntry) => {
    selection();
    router.push({
      pathname: '/message/[id]',
      params: { id: m.id, subject: m.subject, sender: m.sender, date: String(m.dateMs) },
    });
  };

  const readAll = () => {
    const ids = all.filter(isUnread).map((m) => m.id);
    if (!ids.length) return;
    notify();
    markRead(ids);
  };

  const deleteAll = () => {
    notify(Haptics.NotificationFeedbackType.Warning);
    setConfirmAll(true);
  };

  const pick =
    <T,>(fn: (v: T) => void, v: T) =>
    () => {
      selection();
      fn(v);
    };

  const thisYear = new Date(now).getFullYear();
  const when = (ms: number) => (sameDay(ms, now) ? hhmm(ms) : fmtDate(ms, lang, new Date(ms).getFullYear() !== thisYear));

  return (
    <View style={{ flex: 1, backgroundColor: c.background }}>
      <ScreenTitle title={t.tabs.messages} subtitle={unreadCount ? tx.v2.menu.unread(unreadCount) : null} />
      <Stack.Screen
        options={{
          headerTransparent: false,
          headerLargeTitle: false,
          headerStyle: { backgroundColor: c.background },
          headerSearchBarOptions: {
            placeholder: tx.v2.messages.search,
            hideWhenScrolling: false,
            onChangeText: (e) => setSearch(e.nativeEvent.text),
          },
        }}
      />
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Menu
          icon={filtered ? 'line.3.horizontal.decrease.circle.fill' : 'line.3.horizontal.decrease.circle'}
          accessibilityLabel={tx.v2.messages.filter}>
          <Stack.Toolbar.Menu inline title={tx.v2.messages.filter}>
            <Stack.Toolbar.MenuAction icon="tray" isOn={status === 'all'} onPress={pick(setStatus, 'all' as Status)}>
              {tx.v2.messages.all}
            </Stack.Toolbar.MenuAction>
            <Stack.Toolbar.MenuAction icon="envelope.badge" isOn={status === 'unread'} onPress={pick(setStatus, 'unread' as Status)}>
              {tx.v2.messages.unread}
            </Stack.Toolbar.MenuAction>
            <Stack.Toolbar.MenuAction icon="envelope.open" isOn={status === 'read'} onPress={pick(setStatus, 'read' as Status)}>
              {tx.v2.messages.read}
            </Stack.Toolbar.MenuAction>
            <Stack.Toolbar.MenuAction icon="paperclip" isOn={attachments} onPress={pick(setAttachments, !attachments)}>
              {tx.v2.messages.attachments}
            </Stack.Toolbar.MenuAction>
          </Stack.Toolbar.Menu>
          <Stack.Toolbar.Menu icon="calendar" title={tx.v2.messages.date}>
            {([0, 7, 30, 90, -1] as Range[]).map((r) => (
              <Stack.Toolbar.MenuAction
                key={r}
                isOn={range === r}
                onPress={() => {
                  selection();
                  setNow(Date.now());
                  setRange(r);
                }}>
                {r === 0
                  ? tx.v2.messages.anyTime
                  : r === 7
                    ? tx.v2.messages.last7
                    : r === 30
                      ? tx.v2.messages.last30
                      : r === 90
                        ? tx.v2.messages.last90
                        : tx.v2.messages.customRange}
              </Stack.Toolbar.MenuAction>
            ))}
          </Stack.Toolbar.Menu>
          <Stack.Toolbar.Menu icon="arrow.up.arrow.down" title={tx.v2.messages.sort}>
            <Stack.Toolbar.MenuAction isOn={newestFirst} onPress={pick(setNewestFirst, true)}>
              {tx.v2.messages.newest}
            </Stack.Toolbar.MenuAction>
            <Stack.Toolbar.MenuAction isOn={!newestFirst} onPress={pick(setNewestFirst, false)}>
              {tx.v2.messages.oldest}
            </Stack.Toolbar.MenuAction>
          </Stack.Toolbar.Menu>
          <Stack.Toolbar.Menu inline>
            {filtered ? (
              <Stack.Toolbar.MenuAction
                icon="xmark.circle"
                onPress={() => {
                  selection();
                  setStatus('all');
                  setAttachments(false);
                  setRange(0);
                  setNewestFirst(true);
                }}>
                {tx.v2.messages.clearFilters}
              </Stack.Toolbar.MenuAction>
            ) : null}
            <Stack.Toolbar.MenuAction icon="envelope.open.fill" disabled={unreadCount === 0} onPress={readAll}>
              {tx.v2.messages.readAll}
            </Stack.Toolbar.MenuAction>
            {hidden.length ? (
              <Stack.Toolbar.MenuAction icon="arrow.uturn.backward" onPress={pick(unhideAll, undefined)}>
                {tx.v2.messages.restoreHidden(hidden.length)}
              </Stack.Toolbar.MenuAction>
            ) : null}
            <Stack.Toolbar.MenuAction icon="trash" destructive disabled={shown.length === 0} onPress={deleteAll}>
              {tx.v2.messages.deleteAll}
            </Stack.Toolbar.MenuAction>
          </Stack.Toolbar.Menu>
        </Stack.Toolbar.Menu>
      </Stack.Toolbar>

      {!query.data ? (
        <View style={{ padding: Spacing.three, gap: Spacing.three }}>
          <DataBanner query={query} />
          {query.loading ? <SkeletonList rows={7} height={56} /> : <ErrorCard query={query} />}
        </View>
      ) : (
        <Host style={{ flex: 1 }} colorScheme={c.scheme}>
          <ConfirmationDialog
            title={tx.v2.messages.deleteAll}
            titleVisibility="visible"
            isPresented={confirmAll}
            onIsPresentedChange={(v) => {
              if (!v) setConfirmAll(false);
            }}>
            <ConfirmationDialog.Trigger>
              <List
                modifiers={[
                  listStyle('insetGrouped'),
                  tint(c.brand),
                  refreshable(async () => {
                    impact();
                    setNow(nowMs());
                    await query.refresh();
                  }),
                ]}>
                {query.offline || query.down || query.error ? (
                  <Section>
                    <SText modifiers={[font({ size: 13 }), foregroundStyle(query.down ? c.danger : c.warning)]}>
                      {query.offline
                        ? tx.status.offline + syncSuffix
                        : query.down
                          ? tx.v2.status.down + syncSuffix
                          : tx.status.refreshFailed + syncSuffix}
                    </SText>
                  </Section>
                ) : null}
                {range === -1 ? (
                  <Section title={tx.v2.messages.customRange}>
                    <DatePicker
                      title={tx.v2.messages.from}
                      selection={from}
                      range={{ end: to }}
                      displayedComponents={['date']}
                      onDateChange={(d) => {
                        selection();
                        setFrom(d);
                      }}
                    />
                    <DatePicker
                      title={tx.v2.messages.to}
                      selection={to}
                      range={{ start: from, end: new Date() }}
                      displayedComponents={['date']}
                      onDateChange={(d) => {
                        selection();
                        setTo(d);
                      }}
                    />
                  </Section>
                ) : null}
                {shown.length === 0 && iosMajor >= 17 ? (
                  <ContentUnavailableView
                    title={filtered || needle ? tx.v2.messages.emptyFiltered : tx.v2.messages.empty}
                    systemImage={filtered || needle ? 'line.3.horizontal.decrease.circle' : 'tray'}
                  />
                ) : shown.length === 0 ? (
                  // ios 16 renders ContentUnavailableView as literally nothing
                  <HStack>
                    <Spacer />
                    <VStack spacing={10} modifiers={[padding({ vertical: 36 })]}>
                      <Image
                        systemName={filtered || needle ? 'line.3.horizontal.decrease.circle' : 'tray'}
                        size={44}
                        color={c.textSecondary}
                      />
                      <SText modifiers={[font({ size: 20, weight: 'semibold' }), multilineTextAlignment('center')]}>
                        {filtered || needle ? tx.v2.messages.emptyFiltered : tx.v2.messages.empty}
                      </SText>
                    </VStack>
                    <Spacer />
                  </HStack>
                ) : (
                  <Section footer={<SText modifiers={[font({ size: 12 })]}>{tx.v2.messages.localNote}</SText>}>
                    {shown.map((m) => {
                      const unread = isUnread(m);
                      return (
                        <SwipeActions key={m.id}>
                          <HStack spacing={10} alignment="top" modifiers={[contentShape(shapes.rectangle()), onTapGesture(() => open(m))]}>
                            <Image systemName="circle.fill" size={9} color={unread ? c.brand : 'transparent'} modifiers={[]} />
                            <VStack alignment="leading" spacing={3}>
                              <HStack spacing={6}>
                                <SText modifiers={[font({ size: 16, weight: unread ? 'semibold' : 'regular' }), lineLimit(1)]}>
                                  {m.sender && m.sender !== '-' ? m.sender : tx.v2.messages.system}
                                </SText>
                                <Spacer />
                                {m.hasAttachment ? <Image systemName="paperclip" size={12} color={c.textSecondary} /> : null}
                                <SText modifiers={[font({ size: 14 }), foregroundStyle(c.textSecondary)]}>{when(m.dateMs)}</SText>
                              </HStack>
                              <SText
                                modifiers={[
                                  font({ size: 15, weight: unread ? 'medium' : 'regular' }),
                                  foregroundStyle(unread ? c.text : c.textSecondary),
                                  lineLimit(2),
                                ]}>
                                {m.subject}
                              </SText>
                            </VStack>
                          </HStack>
                          <SwipeActions.Actions edge="leading" allowsFullSwipe>
                            <Button
                              label={unread ? tx.v2.messages.markRead : tx.v2.messages.markUnread}
                              systemImage={unread ? 'envelope.open.fill' : 'envelope.badge.fill'}
                              modifiers={[tint(c.brand)]}
                              onPress={() => toggleRead(m)}
                            />
                          </SwipeActions.Actions>
                          <SwipeActions.Actions edge="trailing" allowsFullSwipe>
                            <Button
                              label={tx.v2.messages.delete}
                              systemImage="trash.fill"
                              role="destructive"
                              modifiers={[tint(SYSTEM_RED)]}
                              onPress={() => remove(m)}
                            />
                          </SwipeActions.Actions>
                        </SwipeActions>
                      );
                    })}
                  </Section>
                )}
              </List>
            </ConfirmationDialog.Trigger>
            <ConfirmationDialog.Actions>
              <Button label={tx.v2.messages.delete} role="destructive" onPress={confirmDelete} />
              <Button label={t.common.cancel} role="cancel" onPress={() => setConfirmAll(false)} />
            </ConfirmationDialog.Actions>
            <ConfirmationDialog.Message>
              <SText>
                {`${tx.v2.messages.deleteAllConfirm} ${tx.v2.messages.localNote}`}
              </SText>
            </ConfirmationDialog.Message>
          </ConfirmationDialog>
        </Host>
      )}
    </View>
  );
}