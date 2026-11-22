import { SymbolView } from 'expo-symbols';
import { useState, type ComponentProps } from 'react';
import { Pressable, Text, View } from 'react-native';
import Animated, { FadeIn, FadeInDown, FadeOut, LinearTransition } from 'react-native-reanimated';

import { DetailList, EmptyCard, QueryScreen } from '@/components/screen';
import { Card, Segmented, SkeletonList } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import type { Query } from '@/hooks/use-neptun-query';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { fmtDate } from '@/lib/format';
import type { ListItem } from '@/neptun/data';

type Sym = ComponentProps<typeof SymbolView>['name'];

export type ItemTab = { key: string; label: string; query: Query<ListItem[]>; icon: Sym };

// segmented neptun records, cards unfold every field
export function ItemTabs({ tabs, empty, hint, dateLabel }: { tabs: ItemTab[]; empty: string; hint?: string; dateLabel?: (d: string) => string }) {
  const c = useTheme();
  const [active, setActive] = useState(tabs[0].key);
  const tab = tabs.find((x) => x.key === active) ?? tabs[0];
  const items = tab.query.data ?? [];
  return (
    <QueryScreen
      query={tab.query}
      skeleton={<SkeletonList rows={5} />}
      header={
        <View style={{ gap: Spacing.two }}>
          <Segmented options={tabs.map((x) => ({ value: x.key, label: x.label }))} value={active} onChange={setActive} />
          {hint ? <Text style={{ color: c.textSecondary, fontSize: 13, lineHeight: 18, marginHorizontal: Spacing.one }}>{hint}</Text> : null}
        </View>
      }>
      {items.length === 0 ? <EmptyCard text={empty} icon={tab.icon} /> : null}
      {items.map((it, i) => (
        <ItemCard key={`${tab.key}-${it.id}`} item={it} icon={tab.icon} index={i} dateLabel={dateLabel} />
      ))}
    </QueryScreen>
  );
}

function ItemCard({ item, icon, index, dateLabel }: { item: ListItem; icon: Sym; index: number; dateLabel?: (d: string) => string }) {
  const c = useTheme();
  const { lang } = useI18n();
  const { selection } = useHaptics();
  const [open, setOpen] = useState(false);
  const date = item.dateMs ? fmtDate(item.dateMs, lang, true) : '';
  return (
    <Animated.View entering={FadeInDown.duration(250).delay(Math.min(index, 10) * 30)} layout={LinearTransition}>
      <Pressable
        onPress={() => {
          selection();
          setOpen((o) => !o);
        }}>
        <Card style={{ gap: Spacing.two }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three }}>
            <View
              style={{
                width: 36,
                height: 36,
                borderRadius: 10,
                borderCurve: 'continuous',
                backgroundColor: c.brandSubtle,
                alignItems: 'center',
                justifyContent: 'center',
              }}>
              <SymbolView name={icon} tintColor={c.brand} size={17} />
            </View>
            <View style={{ flex: 1, gap: 2 }}>
              <Text selectable style={{ color: c.text, fontSize: 16, fontWeight: '600' }}>
                {item.title}
              </Text>
              <Text numberOfLines={1} style={{ color: c.textSecondary, fontSize: 13 }}>
                {[item.subtitle, date ? (dateLabel ? dateLabel(date) : date) : '', item.status].filter(Boolean).join(' · ')}
              </Text>
            </View>
            <SymbolView name={open ? 'chevron.up' : 'chevron.down'} tintColor={c.textTertiary} size={12} />
          </View>
          {open && item.rows.length ? (
            <Animated.View entering={FadeIn.duration(200)} exiting={FadeOut.duration(150)}>
              <DetailList rows={item.rows} />
            </Animated.View>
          ) : null}
        </Card>
      </Pressable>
    </Animated.View>
  );
}