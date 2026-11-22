import { useLocalSearchParams } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { useEffect } from 'react';
import { Text, View } from 'react-native';

import { HtmlView } from '@/components/html-view';
import { QueryScreen, ScreenTitle } from '@/components/screen';
import { Card } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useHiddenMessages } from '@/hooks/use-message-state';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { fmtLongDate, hhmm } from '@/lib/format';
import { peekCache, writeCache } from '@/neptun/cache';
import { openMessage, type MessageEntry } from '@/neptun/data';

export default function MessageScreen() {
  const c = useTheme();
  const { tx, lang } = useI18n();
  const { id, subject, sender, date } = useLocalSearchParams<{ id: string; subject?: string; sender?: string; date?: string }>();
  const body = useNeptunQuery(id ? `message.${id}` : null, () => openMessage(id));
  const dateMs = Number(date) || 0;
  const { setRead } = useHiddenMessages();

  // Opening acknowledges the posts in Neptun; mirror that in the cached list right away.
  const opened = body.data != null;
  useEffect(() => {
    if (!opened || !id) return;
    setRead([id], true);
    const list = peekCache<MessageEntry[]>('messages');
    if (list && list.data.some((m) => m.id === id && !m.isRead)) {
      void writeCache(
        'messages',
        list.data.map((m) => (m.id === id ? { ...m, isRead: true } : m)),
      );
    }
  }, [opened, id, setRead]);

  return (
    <>
      <ScreenTitle title={tx.message.title} />
      <QueryScreen
        query={body}
        header={
          <Card style={{ gap: Spacing.two }}>
            <Text selectable style={{ color: c.text, fontSize: 18, fontWeight: '700' }}>
              {subject}
            </Text>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
              <SymbolView name="person.fill" tintColor={c.textTertiary} size={12} />
              <Text selectable style={{ color: c.textSecondary, fontSize: 14, flex: 1 }}>
                {sender && sender !== '-' ? sender : tx.v2.messages.system}
              </Text>
            </View>
            {dateMs ? (
              <Text style={{ color: c.textTertiary, fontSize: 13 }}>
                {fmtLongDate(dateMs, lang)} {hhmm(dateMs)}
              </Text>
            ) : null}
          </Card>
        }>
        <Card>
          {body.data?.trim() ? (
            <HtmlView html={body.data} />
          ) : (
            <Text style={{ color: c.textSecondary, fontSize: 15 }}>{tx.message.noText}</Text>
          )}
        </Card>
      </QueryScreen>
    </>
  );
}