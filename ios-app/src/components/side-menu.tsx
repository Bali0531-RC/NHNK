import { Button, Host, Menu, Text as SText } from '@expo/ui/swift-ui';
import { Image } from 'expo-image';
import { router, type Href } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { createContext, use, useCallback, useMemo, useState, type ComponentProps, type ReactNode } from 'react';
import { Linking, Pressable, ScrollView, Text, View, useWindowDimensions } from 'react-native';
import { Drawer } from 'react-native-drawer-layout';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Separator } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useHiddenMessages } from '@/hooks/use-message-state';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTerm } from '@/hooks/use-term';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { fmtMoney } from '@/lib/format';
import { getCollectiveAccount, getMessages, getProfile } from '@/neptun/data';
import { useAuth } from '@/providers/auth';

const BUG_URL = 'https://github.com/Bali0531-RC/NHNK/issues/new/choose';

type Sym = ComponentProps<typeof SymbolView>['name'];
type Item = { icon: Sym; label: string; color: string; onPress: () => void };

type SideMenuValue = { open: () => void; close: () => void };
const SideMenuContext = createContext<SideMenuValue | null>(null);

export function useSideMenu(): SideMenuValue {
  const ctx = use(SideMenuContext);
  if (!ctx) throw new Error('useSideMenu must be used inside SideMenu');
  return ctx;
}

// real drawer on gesture handler + reanimated: edge swipe opens, drag closes, content slides like the ios sidebar
export function SideMenu({ children }: { children: ReactNode }) {
  const c = useTheme();
  const { width } = useWindowDimensions();
  const { selection } = useHaptics();
  const [isOpen, setOpen] = useState(false);
  const open = useCallback(() => setOpen(true), []);
  const close = useCallback(() => setOpen(false), []);
  const value = useMemo(() => ({ open, close }), [open, close]);

  return (
    <SideMenuContext value={value}>
      <Drawer
        open={isOpen}
        onOpen={() => {
          selection();
          setOpen(true);
        }}
        onClose={() => setOpen(false)}
        drawerType="slide"
        swipeEdgeWidth={28}
        swipeMinDistance={12}
        drawerStyle={{ width: Math.min(340, width * 0.84), backgroundColor: c.background }}
        overlayStyle={{ backgroundColor: 'rgba(0,0,0,0.35)' }}
        renderDrawerContent={() => <MenuContent close={close} />}>
        {children}
      </Drawer>
    </SideMenuContext>
  );
}

function MenuContent({ close }: { close: () => void }) {
  const c = useTheme();
  const { t, tx, lang } = useI18n();
  const insets = useSafeAreaInsets();
  const { signOut, isDemo } = useAuth();
  const { selection } = useHaptics();

  const profile = useNeptunQuery('profile', getProfile);
  const account = useNeptunQuery('collective', getCollectiveAccount);
  const messages = useNeptunQuery('messages', getMessages);
  const { isUnread, hidden } = useHiddenMessages();
  const unread = (messages.data ?? []).filter((m) => !hidden.includes(m.id) && isUnread(m)).length;
  const { list: terms, termId, termName, setTermId } = useTerm();

  const go = (path: Href) => {
    selection();
    close();
    router.push(path);
  };

  const groups: { title: string; items: Item[] }[] = [
    {
      title: tx.v2.menu.administration,
      items: [
        { icon: 'person.text.rectangle.fill', label: tx.v2.menu.profile, color: '#007AFF', onPress: () => go('/profile') },
        { icon: 'doc.badge.plus', label: tx.v2.menu.requests, color: '#FF9500', onPress: () => go('/requests') },
        { icon: 'folder.fill', label: tx.v2.menu.documents, color: '#5856D6', onPress: () => go('/documents') },
        { icon: 'checklist', label: tx.v2.menu.questionnaires, color: '#34C759', onPress: () => go('/questionnaires') },
        { icon: 'calendar.badge.clock', label: t.menu.upcoming, color: '#FF3B30', onPress: () => go('/upcoming') },
        { icon: 'chart.xyaxis.line', label: t.menu.statistics, color: '#AF52DE', onPress: () => go('/statistics') },
      ],
    },
    {
      title: tx.v2.menu.app,
      items: [
        { icon: 'gearshape.fill', label: t.menu.settings, color: '#8E8E93', onPress: () => go('/settings') },
        {
          icon: 'ladybug.fill',
          label: t.menu.bugReport,
          color: '#FF9500',
          onPress: () => {
            selection();
            close();
            void Linking.openURL(BUG_URL).catch(() => {});
          },
        },
        { icon: 'info.circle.fill', label: t.menu.about, color: '#30B0C7', onPress: () => go('/about') },
      ],
    },
  ];

  const p = profile.data;
  const name = isDemo ? 'DEMO' : p?.name || p?.code || '';
  const acc = account.data;

  return (
    <ScrollView
      contentContainerStyle={{
        paddingTop: insets.top + Spacing.three,
        paddingHorizontal: Spacing.three,
        paddingBottom: insets.bottom + Spacing.four,
        gap: Spacing.three,
      }}>
      <Pressable onPress={() => go('/profile')} style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1 })}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three }}>
          {p?.avatar ? (
            <Image
              source={{ uri: `data:image/jpeg;base64,${p.avatar}` }}
              style={{ width: 56, height: 56, borderRadius: 28 }}
              contentFit="cover"
            />
          ) : (
            <View
              style={{
                width: 56,
                height: 56,
                borderRadius: 28,
                backgroundColor: c.brand,
                alignItems: 'center',
                justifyContent: 'center',
              }}>
              <Text style={{ color: c.brandOn, fontSize: 22, fontWeight: '700' }}>{(name || '?').slice(0, 1).toUpperCase()}</Text>
            </View>
          )}
          <View style={{ flex: 1 }}>
            <Text numberOfLines={1} style={{ color: c.text, fontSize: 19, fontWeight: '700' }}>
              {name || t.menu.greeting}
            </Text>
            <Text numberOfLines={1} style={{ color: c.textSecondary, fontSize: 13 }}>
              {isDemo ? tx.common.demoNotice : (p?.code ?? '')}
            </Text>
          </View>
          <SymbolView name="chevron.right" tintColor={c.textTertiary} size={13} />
        </View>
      </Pressable>

      <View style={{ flexDirection: 'row', gap: Spacing.two }}>
        <Tile
          icon="envelope.fill"
          tint={unread > 0 ? c.brand : c.textSecondary}
          title={t.tabs.messages}
          value={unread > 0 ? tx.v2.menu.unread(unread) : tx.v2.menu.allRead}
          onPress={() => {
            selection();
            close();
            router.navigate('/messages');
          }}
        />
        <Tile
          icon="banknote.fill"
          tint={c.success}
          title={tx.v2.payments.collective}
          value={acc ? fmtMoney(acc.balance, lang) : '-'}
          onPress={() => go('/top-up')}
        />
      </View>

      {terms.length > 0 ? (
        <View style={{ backgroundColor: c.card, borderRadius: 18, borderCurve: 'continuous', padding: Spacing.three, gap: 4 }}>
          <Text style={{ color: c.textSecondary, fontSize: 12, fontWeight: '600', textTransform: 'uppercase' }}>{tx.v2.menu.semester}</Text>
          <Host matchContents style={{ alignSelf: 'flex-start' }}>
            <Menu label={<SText>{termName}</SText>} systemImage="chevron.up.chevron.down">
              {[...terms].reverse().map((term) => (
                <Button
                  key={term.id}
                  label={term.name}
                  systemImage={term.id === termId ? 'checkmark' : undefined}
                  onPress={() => {
                    selection();
                    setTermId(term.id);
                  }}
                />
              ))}
            </Menu>
          </Host>
        </View>
      ) : null}

      {groups.map((g) => (
        <View key={g.title} style={{ gap: Spacing.one }}>
          <Text style={{ color: c.textSecondary, fontSize: 12, fontWeight: '600', textTransform: 'uppercase', marginLeft: Spacing.three }}>
            {g.title}
          </Text>
          <View style={{ backgroundColor: c.card, borderRadius: 18, borderCurve: 'continuous', overflow: 'hidden' }}>
            {g.items.map((it, i) => (
              <View key={it.label}>
                {i > 0 ? <Separator inset={56} /> : null}
                <Pressable
                  onPress={it.onPress}
                  style={({ pressed }) => ({
                    flexDirection: 'row',
                    alignItems: 'center',
                    gap: Spacing.three,
                    paddingVertical: 11,
                    paddingHorizontal: Spacing.three,
                    backgroundColor: pressed ? c.backgroundSelected : 'transparent',
                  })}>
                  <View
                    style={{
                      width: 29,
                      height: 29,
                      borderRadius: 7,
                      borderCurve: 'continuous',
                      backgroundColor: it.color,
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}>
                    <SymbolView name={it.icon} tintColor="#FFFFFF" size={16} />
                  </View>
                  <Text style={{ color: c.text, fontSize: 16, flex: 1 }}>{it.label}</Text>
                  <SymbolView name="chevron.right" tintColor={c.textTertiary} size={12} />
                </Pressable>
              </View>
            ))}
          </View>
        </View>
      ))}

      <Pressable
        testID="menu-sign-out"
        onPress={() => {
          close();
          void signOut();
        }}
        style={({ pressed }) => ({
          backgroundColor: c.card,
          borderRadius: 18,
          borderCurve: 'continuous',
          paddingVertical: 13,
          alignItems: 'center',
          flexDirection: 'row',
          justifyContent: 'center',
          gap: Spacing.two,
          opacity: pressed ? 0.6 : 1,
        })}>
        <SymbolView name="rectangle.portrait.and.arrow.right" tintColor={c.danger} size={18} />
        <Text style={{ color: c.danger, fontSize: 16, fontWeight: '600' }}>{t.common.signOut}</Text>
      </Pressable>
    </ScrollView>
  );
}

function Tile({ icon, tint, title, value, onPress }: { icon: Sym; tint: string; title: string; value: string; onPress: () => void }) {
  const c = useTheme();
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => ({
        flex: 1,
        backgroundColor: c.card,
        borderRadius: 18,
        borderCurve: 'continuous',
        padding: Spacing.three,
        gap: 6,
        opacity: pressed ? 0.7 : 1,
      })}>
      <SymbolView name={icon} tintColor={tint} size={20} />
      <Text numberOfLines={1} style={{ color: c.textSecondary, fontSize: 12, fontWeight: '600' }}>
        {title}
      </Text>
      <Text numberOfLines={2} style={{ color: c.text, fontSize: 14, fontWeight: '600', fontVariant: ['tabular-nums'] }}>
        {value}
      </Text>
    </Pressable>
  );
}