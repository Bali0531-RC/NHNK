import * as Haptics from 'expo-haptics';
import * as Notifications from 'expo-notifications';
import { SymbolView } from 'expo-symbols';
import { useEffect, useRef, useState, type ComponentProps } from 'react';
import {
  Linking,
  Pressable,
  ScrollView,
  Text,
  View,
  useWindowDimensions,
  type NativeScrollEvent,
  type ScrollViewInstance,
  type NativeSyntheticEvent,
} from 'react-native';
import Animated, { Easing, FadeIn, FadeOut, Keyframe, LinearTransition } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { LanguageSelector } from '@/components/language-selector';
import { TutorialVideo } from '@/components/tutorial-video';
import { Radius, Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { checkBiometric, useAppLock } from '@/providers/app-lock';
import { usePreferences } from '@/providers/preferences';

type Sym = ComponentProps<typeof SymbolView>['name'];

// soft settle, no spring. the bouncing looked like a toy
const SETTLE = new Keyframe({
  0: { opacity: 0, transform: [{ scale: 0.94 }] },
  100: { opacity: 1, transform: [{ scale: 1 }], easing: Easing.out(Easing.cubic) },
}).duration(280);

const PAGES: { icon: Sym; color: string }[] = [
  { icon: 'graduationcap.fill', color: '#007AFF' },
  { icon: 'calendar', color: '#FF3B30' },
  { icon: 'books.vertical.fill', color: '#AF52DE' },
  { icon: 'creditcard.fill', color: '#34C759' },
  { icon: 'clock.fill', color: '#FF9500' },
  { icon: 'envelope.badge.fill', color: '#30B0C7' },
  { icon: 'sidebar.left', color: '#5856D6' },
];

// first launch intro, replayable from settings
export function Onboarding({ onDone }: { onDone: () => void }) {
  const c = useTheme();
  const { tx } = useI18n();
  const insets = useSafeAreaInsets();
  const { width, height } = useWindowDimensions();
  const { selection, notify } = useHaptics();
  const pager = useRef<ScrollViewInstance>(null);
  const [page, setPage] = useState(0);

  const pages = tx.v2.onboarding.pages;
  // two extra pages at the end: opt-in permissions, then the 2fa video
  const permsAt = pages.length;
  const total = pages.length + 2;
  const last = page >= total - 1;

  const goTo = (i: number) => {
    pager.current?.scrollTo({ x: i * width, animated: true });
    if (i !== page) selection();
    setPage(i);
  };

  const onScrollEnd = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const i = Math.round(e.nativeEvent.contentOffset.x / width);
    if (i !== page) {
      selection();
      setPage(i);
    }
  };

  const finish = () => {
    notify();
    onDone();
  };

  return (
    <View style={{ flex: 1, backgroundColor: c.background, paddingTop: insets.top + Spacing.two, paddingBottom: insets.bottom + Spacing.three }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: Spacing.three }}>
        <LanguageSelector />
        {page < permsAt ? (
          <Pressable onPress={() => goTo(permsAt)} hitSlop={10} style={({ pressed }) => ({ opacity: pressed ? 0.6 : 1 })}>
            <Text style={{ color: c.textSecondary, fontSize: 15, fontWeight: '600' }}>{tx.v2.onboarding.skip}</Text>
          </Pressable>
        ) : null}
      </View>

      <ScrollView
        ref={pager}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={onScrollEnd}
        style={{ flex: 1 }}>
        {pages.map((p, i) => {
          const meta = PAGES[i] ?? PAGES[0];
          return (
            <View key={p.title} style={{ width, alignItems: 'center', justifyContent: 'center', paddingHorizontal: Spacing.five, gap: Spacing.four }}>
              {i === page ? (
                <Animated.View
                  entering={SETTLE}
                  style={{
                    width: 112,
                    height: 112,
                    borderRadius: 30,
                    borderCurve: 'continuous',
                    backgroundColor: meta.color,
                    alignItems: 'center',
                    justifyContent: 'center',
                    boxShadow: `0 10px 30px ${meta.color}55`,
                  }}>
                  <SymbolView name={meta.icon} tintColor="#FFFFFF" size={52} />
                </Animated.View>
              ) : (
                <View style={{ width: 112, height: 112 }} />
              )}
              <View style={{ gap: Spacing.two, alignItems: 'center' }}>
                <Text style={{ color: c.text, fontSize: 28, fontWeight: '800', textAlign: 'center' }}>{p.title}</Text>
                <Text style={{ color: c.textSecondary, fontSize: 17, textAlign: 'center', lineHeight: 24 }}>{p.body}</Text>
              </View>
            </View>
          );
        })}
        <View style={{ width }}>{page >= permsAt - 1 ? <PermissionsPage /> : null}</View>
        <View style={{ width, alignItems: 'center', justifyContent: 'center', paddingHorizontal: Spacing.five, gap: Spacing.three }}>
          {page >= permsAt ? (
            <>
              <TutorialVideo height={Math.min(height * 0.5, 460)} />
              <View style={{ gap: Spacing.one, alignItems: 'center' }}>
                <Text style={{ color: c.text, fontSize: 24, fontWeight: '800', textAlign: 'center' }}>{tx.v2.tutorial.title}</Text>
                <Text style={{ color: c.textSecondary, fontSize: 15, textAlign: 'center', lineHeight: 21 }}>{tx.v2.tutorial.body}</Text>
              </View>
            </>
          ) : null}
        </View>
      </ScrollView>

      <View style={{ flexDirection: 'row', justifyContent: 'center', gap: 6, marginBottom: Spacing.four }}>
        {Array.from({ length: total }, (_, i) => (
          <Pressable key={i} hitSlop={6} onPress={() => goTo(i)}>
            <Animated.View
              layout={LinearTransition.duration(220)}
              style={{
                width: i === page ? 22 : 8,
                height: 8,
                borderRadius: 4,
                backgroundColor: i === page ? c.brand : c.fill,
              }}
            />
          </Pressable>
        ))}
      </View>

      <View style={{ flexDirection: 'row', gap: Spacing.two, paddingHorizontal: Spacing.four }}>
        {page > 0 ? (
          <Animated.View entering={FadeIn.duration(180)} exiting={FadeOut.duration(150)} style={{ flex: 1 }}>
            <Pressable
              onPress={() => goTo(page - 1)}
              style={({ pressed }) => ({
                backgroundColor: c.fill,
                borderRadius: Radius.pill,
                paddingVertical: Spacing.three,
                alignItems: 'center',
                opacity: pressed ? 0.7 : 1,
              })}>
              <Text style={{ color: c.text, fontSize: 17, fontWeight: '600' }}>{tx.v2.onboarding.back}</Text>
            </Pressable>
          </Animated.View>
        ) : null}
        <Animated.View layout={LinearTransition.duration(220)} style={{ flex: page > 0 ? 1.4 : 1 }}>
          <Pressable
            onPress={() => (last ? finish() : goTo(page + 1))}
            style={({ pressed }) => ({
              backgroundColor: c.brand,
              borderRadius: Radius.pill,
              paddingVertical: Spacing.three,
              alignItems: 'center',
              opacity: pressed ? 0.85 : 1,
            })}>
            <Text style={{ color: c.brandOn, fontSize: 17, fontWeight: '700' }}>
              {last ? tx.v2.onboarding.done : tx.v2.onboarding.next}
            </Text>
          </Pressable>
        </Animated.View>
      </View>
    </View>
  );
}

type Ask = 'idle' | 'on' | 'denied';

// nothing fires until a button is tapped. a no just gets a warning right here, the app carries on
function PermissionsPage() {
  const c = useTheme();
  const { t, tx } = useI18n();
  const p = tx.v2.perms;
  const { notify } = useHaptics();
  const prefs = usePreferences();
  const { grant } = useAppLock();
  const [notif, setNotif] = useState<Ask>('idle');
  const [face, setFace] = useState<Ask>(prefs.biometricLock ? 'on' : 'idle');

  // only reads the current state, getPermissionsAsync never prompts
  useEffect(() => {
    void Notifications.getPermissionsAsync().then((r) => {
      if (r.granted) setNotif('on');
      else if (!r.canAskAgain) setNotif('denied');
    });
  }, []);

  const askNotif = async () => {
    const cur = await Notifications.getPermissionsAsync();
    const res =
      cur.granted || !cur.canAskAgain
        ? cur
        : await Notifications.requestPermissionsAsync({ ios: { allowAlert: true, allowSound: true, allowBadge: true } });
    setNotif(res.granted ? 'on' : 'denied');
    notify(res.granted ? Haptics.NotificationFeedbackType.Success : Haptics.NotificationFeedbackType.Warning);
  };

  const askFace = async () => {
    const res = await checkBiometric(t.lock.prompt, t.common.cancel);
    if (res === 'cancel') return;
    if (res === 'ok') {
      grant();
      prefs.setBiometricLock(true);
    }
    setFace(res === 'ok' ? 'on' : 'denied');
    notify(res === 'ok' ? Haptics.NotificationFeedbackType.Success : Haptics.NotificationFeedbackType.Warning);
  };

  return (
    <ScrollView
      contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', paddingHorizontal: Spacing.four, paddingVertical: Spacing.three, gap: Spacing.three }}>
      <View style={{ gap: Spacing.two, alignItems: 'center', marginBottom: Spacing.two }}>
        <Text style={{ color: c.text, fontSize: 28, fontWeight: '800', textAlign: 'center' }}>{p.title}</Text>
        <Text style={{ color: c.textSecondary, fontSize: 15, textAlign: 'center', lineHeight: 21 }}>{p.body}</Text>
      </View>
      <PermRow icon="bell.badge.fill" color="#FF3B30" title={p.notifTitle} body={p.notifBody} state={notif} warning={p.notifDenied} onAsk={askNotif} />
      <PermRow icon="faceid" color="#34C759" title={p.faceTitle} body={p.faceBody} state={face} warning={p.faceDenied} onAsk={askFace} />
      <PermRow icon="arrow.triangle.2.circlepath" color="#5856D6" title={p.bgTitle} body={p.bgBody} />
    </ScrollView>
  );
}

function PermRow({
  icon,
  color,
  title,
  body,
  state,
  warning,
  onAsk,
}: {
  icon: Sym;
  color: string;
  title: string;
  body: string;
  state?: Ask;
  warning?: string;
  onAsk?: () => void;
}) {
  const c = useTheme();
  const { tx } = useI18n();
  return (
    <View style={{ backgroundColor: c.card, borderRadius: 18, borderCurve: 'continuous', padding: Spacing.three, gap: Spacing.two }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three }}>
        <View style={{ width: 40, height: 40, borderRadius: 11, borderCurve: 'continuous', backgroundColor: color, alignItems: 'center', justifyContent: 'center' }}>
          <SymbolView name={icon} tintColor="#FFFFFF" size={22} />
        </View>
        <View style={{ flex: 1, gap: 2 }}>
          <Text style={{ color: c.text, fontSize: 16, fontWeight: '700' }}>{title}</Text>
          <Text style={{ color: c.textSecondary, fontSize: 13, lineHeight: 18 }}>{body}</Text>
        </View>
        {onAsk ? (
          state === 'on' ? (
            <Animated.View entering={SETTLE}>
              <SymbolView name="checkmark.circle.fill" tintColor="#34C759" size={28} />
            </Animated.View>
          ) : state === 'idle' ? (
            <Pressable
              onPress={onAsk}
              style={({ pressed }) => ({
                backgroundColor: c.brand,
                borderRadius: Radius.pill,
                paddingHorizontal: Spacing.three,
                paddingVertical: Spacing.two,
                opacity: pressed ? 0.8 : 1,
              })}>
              <Text style={{ color: c.brandOn, fontSize: 14, fontWeight: '700' }}>{tx.v2.perms.allow}</Text>
            </Pressable>
          ) : (
            <SymbolView name="exclamationmark.triangle.fill" tintColor="#FF9500" size={24} />
          )
        ) : null}
      </View>
      {state === 'denied' && warning ? (
        <Animated.View entering={FadeIn.duration(200)} style={{ gap: Spacing.one }}>
          <Text style={{ color: '#FF9500', fontSize: 13, lineHeight: 18 }}>{warning}</Text>
          <Pressable onPress={() => void Linking.openSettings()} hitSlop={6}>
            <Text style={{ color: c.brand, fontSize: 13, fontWeight: '600' }}>{tx.v2.settings.openSettings}</Text>
          </Pressable>
        </Animated.View>
      ) : null}
    </View>
  );
}