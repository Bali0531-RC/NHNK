import * as Haptics from 'expo-haptics';
import { SymbolView } from 'expo-symbols';
import { useEffect, useRef } from 'react';
import { Pressable, Text, TextInput, View, type TextInputInstance } from 'react-native';
import Animated, {
  FadeIn,
  FadeOut,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withSpring,
  withTiming,
  ZoomIn,
} from 'react-native-reanimated';

import { useHaptics } from '@/hooks/use-haptics';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';

const LENGTH = 6;

export type OtpState = 'idle' | 'checking' | 'error' | 'success';

// one hidden TextInput on top so ios autofill and paste still work
export function OtpInput({
  value,
  onChange,
  onComplete,
  state,
}: {
  value: string;
  onChange: (v: string) => void;
  onComplete: (code: string) => void;
  state: OtpState;
}) {
  const c = useTheme();
  const { tx } = useI18n();
  const { selection, notify } = useHaptics();
  const input = useRef<TextInputInstance>(null);
  const shake = useSharedValue(0);
  const caret = useSharedValue(1);
  const locked = state === 'checking' || state === 'success';

  useEffect(() => {
    caret.set(withRepeat(withSequence(withTiming(0, { duration: 450 }), withTiming(1, { duration: 450 })), -1));
  }, [caret]);

  useEffect(() => {
    if (state === 'error') {
      notify(Haptics.NotificationFeedbackType.Error);
      shake.set(
        withSequence(
          withTiming(-9, { duration: 45 }),
          withTiming(9, { duration: 45 }),
          withTiming(-6, { duration: 45 }),
          withTiming(6, { duration: 45 }),
          withSpring(0, { damping: 12 }),
        ),
      );
    } else if (state === 'success') {
      notify(Haptics.NotificationFeedbackType.Success);
    } else if (state === 'idle') {
      input.current?.focus();
    }
  }, [state, notify, shake]);

  const rowStyle = useAnimatedStyle(() => ({ transform: [{ translateX: shake.get() }] }));
  const caretStyle = useAnimatedStyle(() => ({ opacity: caret.get() }));

  const set = (text: string) => {
    if (locked) return;
    const digits = text.replace(/\D/g, '').slice(0, LENGTH);
    if (digits.length !== value.length) selection();
    onChange(digits);
    if (digits.length === LENGTH) onComplete(digits);
  };

  const error = state === 'error';
  const status =
    state === 'error' ? tx.v2.otp.wrong : state === 'checking' ? tx.v2.otp.checking : state === 'success' ? tx.v2.otp.verified : '';

  return (
    <View style={{ alignItems: 'center', gap: 14, minHeight: 92 }}>
      {state === 'success' ? (
        <Animated.View entering={ZoomIn.springify().damping(13)} style={{ height: 56, justifyContent: 'center' }}>
          <SymbolView name="checkmark" tintColor={c.text} size={44} weight="light" />
        </Animated.View>
      ) : (
        <Pressable onPress={() => input.current?.focus()} disabled={locked}>
          <Animated.View style={[{ flexDirection: 'row', gap: 8 }, rowStyle]}>
            {Array.from({ length: LENGTH }, (_, i) => {
              const digit = value[i] ?? '';
              const active = !locked && !error && value.length < LENGTH && i === value.length;
              return (
                <View
                  key={i}
                  style={{
                    width: 46,
                    height: 56,
                    borderRadius: 12,
                    borderCurve: 'continuous',
                    marginLeft: i === 3 ? 10 : 0,
                    backgroundColor: error ? c.danger + '1F' : c.card,
                    borderWidth: error || active ? 1.5 : 0,
                    borderColor: error ? c.danger : c.text,
                    boxShadow: error ? undefined : '0 1px 3px rgba(0,0,0,0.10)',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}>
                  {digit ? (
                    <Animated.Text
                      key={`${i}-${digit}`}
                      entering={ZoomIn.duration(170)}
                      exiting={FadeOut.duration(220)}
                      style={{
                        color: error ? c.danger : c.text,
                        opacity: state === 'checking' ? 0.35 : 1,
                        fontSize: 26,
                        fontWeight: '600',
                        fontVariant: ['tabular-nums'],
                      }}>
                      {digit}
                    </Animated.Text>
                  ) : active ? (
                    <Animated.View style={[{ width: 1.5, height: 24, borderRadius: 1, backgroundColor: c.text }, caretStyle]} />
                  ) : null}
                </View>
              );
            })}
          </Animated.View>
          <TextInput
            ref={input}
            value={value}
            onChangeText={set}
            editable={!locked}
            autoFocus
            keyboardType="number-pad"
            textContentType="oneTimeCode"
            autoComplete="one-time-code"
            maxLength={LENGTH}
            caretHidden
            style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, opacity: 0.02, color: 'transparent' }}
          />
        </Pressable>
      )}
      {status ? (
        <Animated.View key={state} entering={FadeIn.duration(180)} exiting={FadeOut.duration(150)}>
          <Text selectable style={{ color: error ? c.danger : c.textSecondary, fontSize: 13, fontWeight: error ? '500' : '400' }}>
            {status}
          </Text>
        </Animated.View>
      ) : (
        <Text style={{ fontSize: 13 }}> </Text>
      )}
    </View>
  );
}