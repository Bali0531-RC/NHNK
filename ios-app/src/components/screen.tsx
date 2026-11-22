import { Stack } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { useEffect, useState, type ComponentProps, type ReactNode } from 'react';
import { Pressable, RefreshControl, ScrollView, Text, View } from 'react-native';
import Animated, { FadeIn, FadeOut, LinearTransition, useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

import { Card, SkeletonList } from '@/components/ui';
import { Radius, Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useLastSync } from '@/hooks/use-last-sync';
import type { Query } from '@/hooks/use-neptun-query';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { fieldLabel, fixValue } from '@/i18n/field-labels';

type Sym = ComponentProps<typeof SymbolView>['name'];

// Header title with an optional one-line subtitle under it.
export function ScreenTitle({ title, subtitle }: { title: string; subtitle?: string | null }) {
  const c = useTheme();
  const tint = c.style === 'native' ? c.text : c.brandText;
  return (
    <Stack.Screen
      options={{
        title,
        headerTitle: subtitle
          ? () => (
              <View style={{ alignItems: 'center' }}>
                <Text numberOfLines={1} style={{ color: tint, fontSize: 17, fontWeight: '600' }}>
                  {title}
                </Text>
                <Text numberOfLines={1} style={{ color: c.textSecondary, fontSize: 12, fontWeight: '500' }}>
                  {subtitle}
                </Text>
              </View>
            )
          : undefined,
      }}
    />
  );
}

function timeOf(ms: number, lang: string): string {
  const d = new Date(ms);
  const sameDay = new Date().toDateString() === d.toDateString();
  return new Intl.DateTimeFormat(lang === 'hu' ? 'hu-HU' : lang === 'de' ? 'de-DE' : 'en-US', {
    month: sameDay ? undefined : 'short',
    day: sameDay ? undefined : 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(d);
}

// ", as of 21:47" from the one global sync time, so every screen agrees.
export function useSyncSuffix(fallback: number | null): string {
  const { tx, lang } = useI18n();
  const last = useLastSync() ?? fallback;
  return last ? `, ${tx.v2.status.savedAt(timeOf(last, lang))}` : '';
}

// tells you why the data is stale. tap to retry
export function DataBanner({ query }: { query: Query<unknown> }) {
  const c = useTheme();
  const { tx } = useI18n();
  const suffix = useSyncSuffix(query.savedAt);
  let icon: Sym | null = null;
  let text = '';
  let tone = c.warning;
  let bg = c.warningSubtle;
  if (query.offline) {
    icon = 'wifi.slash';
    text = tx.status.offline;
  } else if (query.down) {
    icon = 'server.rack';
    text = tx.v2.status.down;
    tone = c.danger;
    bg = c.dangerSubtle;
  } else if (query.error && query.data) {
    icon = 'exclamationmark.arrow.circlepath';
    text = tx.status.refreshFailed;
  }
  if (!icon || (!query.data && !query.offline && !query.down)) return null;
  const when = suffix || '.';
  return (
    <Animated.View entering={FadeIn.duration(220)} exiting={FadeOut.duration(180)} layout={LinearTransition}>
      <Pressable
        onPress={() => void query.refresh()}
        style={({ pressed }) => ({
          flexDirection: 'row',
          alignItems: 'center',
          gap: Spacing.two,
          paddingVertical: Spacing.two + 2,
          paddingHorizontal: Spacing.three,
          borderRadius: Radius.lg,
          borderCurve: 'continuous',
          backgroundColor: bg,
          opacity: pressed ? 0.7 : 1,
        })}>
        <SymbolView name={icon} tintColor={tone} size={16} />
        <Text style={{ color: c.text, fontSize: 13, flex: 1, lineHeight: 18 }}>
          {text}
          {when}
        </Text>
        <SymbolView name="arrow.clockwise" tintColor={c.textTertiary} size={13} />
      </Pressable>
    </Animated.View>
  );
}

export function ErrorCard({ query }: { query: Query<unknown> }) {
  const c = useTheme();
  const { tx } = useI18n();
  const msg = query.offline
    ? tx.status.offlineNoData
    : query.down
      ? tx.v2.status.downNoData
      : query.error === 'unsupported'
        ? tx.status.unsupported
        : tx.status.failed;
  return (
    <Card style={{ alignItems: 'center', gap: Spacing.three, paddingVertical: Spacing.five }}>
      <SymbolView
        name={query.offline ? 'wifi.slash' : query.down ? 'server.rack' : 'exclamationmark.triangle'}
        tintColor={c.textTertiary}
        size={34}
      />
      <Text selectable style={{ color: c.text, fontSize: 16, fontWeight: '600', textAlign: 'center' }}>
        {msg}
      </Text>
      <Pressable
        onPress={() => void query.refresh()}
        style={({ pressed }) => ({
          paddingVertical: Spacing.two,
          paddingHorizontal: Spacing.four,
          borderRadius: Radius.pill,
          backgroundColor: c.brandSubtle,
          opacity: pressed ? 0.7 : 1,
        })}>
        <Text style={{ color: c.brandText, fontWeight: '700' }}>{tx.status.retry}</Text>
      </Pressable>
    </Card>
  );
}

function Placeholder({ query, skeleton }: { query: Query<unknown>; skeleton?: ReactNode }) {
  if (query.loading) return <>{skeleton ?? <SkeletonList />}</>;
  if (!query.data && (query.error || query.offline)) return <ErrorCard query={query} />;
  return null;
}

// Pull-to-refresh that gives a tap of feedback the moment the pull passes the threshold.
export function useRefresh(refresh: () => Promise<unknown>) {
  const { impact } = useHaptics();
  const [pulling, setPulling] = useState(false);
  const onRefresh = async () => {
    impact();
    setPulling(true);
    try {
      await refresh();
    } finally {
      setPulling(false);
    }
  };
  return { refreshing: pulling, onRefresh };
}

export function QueryScreen({
  query,
  children,
  header,
  skeleton,
  gap = Spacing.three,
  extraRefresh,
}: {
  query: Query<unknown>;
  children: ReactNode;
  header?: ReactNode;
  skeleton?: ReactNode;
  gap?: number;
  extraRefresh?: () => Promise<unknown>;
}) {
  const c = useTheme();
  const { refreshing, onRefresh } = useRefresh(() => Promise.all([query.refresh(), extraRefresh?.()]));
  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: c.background }}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={{ padding: Spacing.three, gap, paddingBottom: Spacing.six }}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={c.textSecondary} />}>
      {header}
      <DataBanner query={query} />
      {query.data ? (
        <Animated.View entering={FadeIn.duration(250)} style={{ gap }}>
          {children}
        </Animated.View>
      ) : (
        <Placeholder query={query} skeleton={skeleton} />
      )}
    </ScrollView>
  );
}

export function DividerLabel({ label, color }: { label: string; color?: string }) {
  const c = useTheme();
  return (
    <Text
      style={{
        color: color ?? c.textSecondary,
        fontSize: 13,
        fontWeight: '600',
        textTransform: 'uppercase',
        letterSpacing: 0.4,
        marginLeft: Spacing.three,
        marginTop: Spacing.two,
      }}>
      {label}
    </Text>
  );
}

// Animates between values instead of snapping.
export function ProgressBar({ value, color, height = 6 }: { value: number; color?: string; height?: number }) {
  const c = useTheme();
  const pct = Math.max(0, Math.min(1, value));
  const w = useSharedValue(pct);
  useEffect(() => {
    w.value = withTiming(pct, { duration: 450 });
  }, [pct, w]);
  const style = useAnimatedStyle(() => ({ width: `${w.value * 100}%` }));
  return (
    <View style={{ height, borderRadius: height / 2, backgroundColor: c.fill, overflow: 'hidden' }}>
      <Animated.View style={[{ height, borderRadius: height / 2, backgroundColor: color ?? c.brand }, style]} />
    </View>
  );
}

export function EmptyCard({ text, icon }: { text: string; icon?: Sym }) {
  const c = useTheme();
  return (
    <Card style={{ alignItems: 'center', gap: Spacing.two, paddingVertical: Spacing.five }}>
      {icon ? <SymbolView name={icon} tintColor={c.textTertiary} size={30} /> : null}
      <Text style={{ color: c.textSecondary, fontSize: 15, textAlign: 'center' }}>{text}</Text>
    </Card>
  );
}

// Label and value rows inside one card, for the raw detail views.
export function DetailList({ rows }: { rows: { label: string; value: string; key?: string }[] }) {
  const c = useTheme();
  const { tx, lang } = useI18n();
  const seen = new Set<string>();
  const shown = rows.flatMap((r) => {
    const label = r.key ? fieldLabel(r.key, lang) : r.label;
    if (!label || seen.has(`${label}|${r.value}`)) return [];
    seen.add(`${label}|${r.value}`);
    return [{ ...r, label, value: fixValue(r.value, lang) }];
  });
  if (!shown.length) return null;
  return (
    <Card style={{ paddingVertical: Spacing.one }}>
      {shown.map((r, i) => (
        <View
          key={`${r.label}-${i}`}
          style={{
            flexDirection: 'row',
            gap: Spacing.three,
            paddingVertical: Spacing.two + 2,
            borderTopWidth: i === 0 ? 0 : 0.5,
            borderTopColor: c.separator,
          }}>
          <Text style={{ color: c.textSecondary, fontSize: 14, flex: 1 }}>{r.label}</Text>
          {r.value === '✓' || r.value === '✕' ? (
            <View
              accessible
              accessibilityLabel={r.value === '✓' ? tx.v2.common.yes : tx.v2.common.no}
              style={{ flex: 1.3, alignItems: 'flex-end' }}>
              <SymbolView
                name={r.value === '✓' ? 'checkmark.circle.fill' : 'xmark.circle.fill'}
                tintColor={r.value === '✓' ? c.success : c.danger}
                size={20}
              />
            </View>
          ) : (
            <Text selectable style={{ color: c.text, fontSize: 14, fontWeight: '500', flex: 1.3, textAlign: 'right' }}>
              {r.value}
            </Text>
          )}
        </View>
      ))}
    </Card>
  );
}