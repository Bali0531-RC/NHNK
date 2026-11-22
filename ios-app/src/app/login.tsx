import { ClipboardPasteButton } from "expo-clipboard";
import { Image } from "expo-image";
import { SymbolView } from "expo-symbols";
import { useEffect, useRef, useState } from "react";
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Pressable,
  ScrollView,
  Text,
  TextInput,
  View,
  type TextInputInstance,
} from "react-native";
import Animated, { FadeIn, FadeOut } from "react-native-reanimated";

import { InstitutionPicker } from "@/components/institution-picker";
import { LanguageSelector } from "@/components/language-selector";
import { OtpInput, type OtpState } from "@/components/otp-input";
import { Radius, Spacing } from "@/constants/theme";
import { useTheme } from "@/hooks/use-theme";
import { useI18n } from "@/i18n";
import {
  cleanCode,
  cleanOtp,
  cleanPassword,
  cooldownLeft,
  noteAttempt,
  otpFromText,
} from "@/lib/sanitize";
import { Store } from "@/neptun/storage";
import type { Institute } from "@/neptun/types";
import { useAuth } from "@/providers/auth";

const logo = require("../../assets/images/nhnk-logo.png");

export default function LoginScreen() {
  const c = useTheme();
  const { t, tx } = useI18n();
  const {
    expiry,
    dismissExpiry,
    signInReal,
    signInDemo,
    submitTwoFactor,
    pendingTwoFactor,
    cancelTwoFactor,
  } = useAuth();

  const [institute, setInstitute] = useState<Institute | null>(null);
  const [neptunCode, setNeptunCode] = useState(expiry?.username ?? "");
  const [password, setPassword] = useState("");
  const [twoFactor, setTwoFactor] = useState("");
  const [pickerOpen, setPickerOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [otpState, setOtpState] = useState<OtpState>("idle");
  const [otpNote, setOtpNote] = useState<string | null>(null);
  const [boxH, setBoxH] = useState(0);
  const [contentH, setContentH] = useState(0);

  const inTwoFactor = pendingTwoFactor !== null;
  const passwordRef = useRef<TextInputInstance>(null);

  useEffect(() => {
    if (!expiry) return;
    let active = true;
    void Store.getInstituteUrl().then((url) => {
      if (active && url)
        setInstitute(
          (cur) => cur ?? { name: new URL(url).host, url, fallbacks: [] },
        );
    });
    void Store.getPassword().then((pw) => {
      if (active && pw) setPassword((cur) => cur || pw);
    });
    return () => {
      active = false;
    };
  }, [expiry]);

  const field = {
    backgroundColor: c.card,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.three - 2,
    color: c.text,
    fontSize: 16,
    borderCurve: "continuous" as const,
  };

  // autofill fires username and password as two quick changes, refs dodge the stale closure
  const live = useRef({ code: neptunCode, pw: password });
  useEffect(() => {
    live.current = { code: neptunCode, pw: password };
  }, [neptunCode, password]);

  const onSignIn = async () => {
    setError(null);
    const code = cleanCode(live.current.code.trim());
    const pw = cleanPassword(live.current.pw);
    // reviewers have no uni to pick, demo/demo skips that
    if (code.toUpperCase() === "DEMO" && pw === "DEMO") return signInDemo();
    if (!institute) return setError(t.login.errorNoInstitution);
    if (!code || !pw) return setError(t.login.errorMissing);
    const wait = cooldownLeft();
    if (wait) return setError(tx.v2.otp.cooldown(wait));
    setBusy(true);
    const outcome = await signInReal(institute, code, pw);
    setBusy(false);
    if (outcome.kind !== "network")
      noteAttempt(outcome.kind !== "failed" || Boolean(outcome.legacy));
    if (outcome.kind === "failed")
      setError(
        outcome.legacy
          ? tx.v2.common.legacyApi
          : (outcome.message ?? t.login.errorWrong),
      );
    else if (outcome.kind === "network") setError(t.login.errorNetwork);
  };

  const onVerify = async (code: string) => {
    if (otpState === "checking" || otpState === "success" || code.length < 6)
      return;
    const wait = cooldownLeft();
    if (wait) {
      setOtpNote(tx.v2.otp.cooldown(wait));
      setTwoFactor("");
      return;
    }
    setOtpNote(null);
    setOtpState("checking");
    const outcome = await submitTwoFactor(code, async () => {
      setOtpState("success");
      await new Promise((done) => setTimeout(done, 900));
    });
    if (outcome.kind !== "network") noteAttempt(outcome.kind === "ok");
    if (outcome.kind === "ok") return;
    setOtpNote(
      outcome.kind === "network"
        ? tx.v2.otp.network
        : outcome.kind === "failed" && outcome.server
          ? tx.v2.otp.server
          : outcome.kind === "failed" && outcome.message
            ? outcome.message
            : tx.v2.otp.rejected,
    );
    setOtpState("error");
    setTimeout(() => {
      setTwoFactor("");
      setOtpState("idle");
    }, 1100);
  };

  const onBack = () => {
    cancelTwoFactor();
    setTwoFactor("");
    setOtpState("idle");
    setOtpNote(null);
    setError(null);
  };

  const onPaste = (text: string) => {
    const code = otpFromText(text);
    if (!code) return setOtpNote(tx.v2.otp.noCode);
    setOtpNote(null);
    setTwoFactor(code);
    void onVerify(code);
  };

  return (
    <KeyboardAvoidingView
      behavior="padding"
      style={{ flex: 1, backgroundColor: c.background }}
    >
      <ScrollView
        style={{ flex: 1 }}
        onLayout={(e) => setBoxH(e.nativeEvent.layout.height)}
        onContentSizeChange={(_, h) => setContentH(h)}
        scrollEnabled={contentH > boxH + 1}
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{
          flexGrow: 1,
          justifyContent: "center",
          paddingHorizontal: Spacing.four,
          paddingVertical: Spacing.five,
          gap: Spacing.four,
        }}
        keyboardDismissMode="interactive"
      >
        <View style={{ alignItems: "center", gap: Spacing.two }}>
          <Image
            source={logo}
            style={{
              width: inTwoFactor ? 56 : 84,
              height: inTwoFactor ? 56 : 84,
              borderRadius: Radius.xl,
            }}
            contentFit="contain"
          />
          {inTwoFactor ? null : (
            <>
              <Text
                style={{
                  color: c.text,
                  fontSize: 34,
                  fontWeight: "800",
                  letterSpacing: 1,
                }}
              >
                NHNK
              </Text>
              <Text style={{ color: c.textSecondary, fontSize: 15 }}>
                {t.login.tagline}
              </Text>
            </>
          )}
        </View>

        {expiry && !inTwoFactor ? (
          <ExpiryCard
            reason={expiry.reason}
            onDismiss={dismissExpiry}
            tx={tx}
            c={c}
          />
        ) : null}

        {inTwoFactor ? (
          <Animated.View
            entering={FadeIn.duration(220)}
            exiting={FadeOut.duration(150)}
            style={{ gap: Spacing.four }}
          >
            <View style={{ gap: Spacing.one }}>
              <Text
                style={{
                  color: c.text,
                  fontSize: 20,
                  fontWeight: "700",
                  textAlign: "center",
                }}
              >
                {t.login.twoFactorTitle}
              </Text>
              <Text
                style={{
                  color: c.textSecondary,
                  fontSize: 14,
                  textAlign: "center",
                  lineHeight: 20,
                }}
              >
                {t.login.twoFactorHint}
              </Text>
            </View>
            <OtpInput
              value={twoFactor}
              onChange={(v) => {
                if (otpState === "error") setOtpState("idle");
                setOtpNote(null);
                setTwoFactor(cleanOtp(v));
              }}
              onComplete={(code) => void onVerify(code)}
              state={otpState}
            />
            {process.env.EXPO_OS === "ios" ? (
              <View style={{ alignItems: "center" }}>
                <ClipboardPasteButton
                  acceptedContentTypes={["plain-text"]}
                  displayMode="iconAndLabel"
                  cornerStyle="capsule"
                  style={{ width: 132, height: 40 }}
                  onPress={(data) => {
                    if (data.type === "text") onPaste(data.text);
                    else setOtpNote(tx.v2.otp.noCode);
                  }}
                />
              </View>
            ) : null}
            {otpNote ? (
              <Animated.Text
                entering={FadeIn.duration(160)}
                style={{ color: c.danger, fontSize: 14, textAlign: "center" }}
              >
                {otpNote}
              </Animated.Text>
            ) : null}
            <Pressable
              onPress={onBack}
              disabled={otpState === "checking" || otpState === "success"}
              style={{ alignItems: "center", paddingVertical: Spacing.two }}
            >
              <Text style={{ color: c.textSecondary, fontSize: 15 }}>
                {t.login.back}
              </Text>
            </Pressable>
          </Animated.View>
        ) : (
          <>
            <View style={{ gap: Spacing.two }}>
              <Pressable
                style={[
                  field,
                  {
                    flexDirection: "row",
                    alignItems: "center",
                    justifyContent: "space-between",
                  },
                ]}
                onPress={() => setPickerOpen(true)}
              >
                <Text
                  style={{
                    color: institute ? c.text : c.textTertiary,
                    fontSize: 16,
                    flex: 1,
                  }}
                  numberOfLines={1}
                >
                  {institute ? institute.name : t.login.institutionPlaceholder}
                </Text>
                <SymbolView
                  name="chevron.right"
                  tintColor={c.textTertiary}
                  size={14}
                />
              </Pressable>
              <TextInput
                style={field}
                placeholder={t.login.codePlaceholder}
                placeholderTextColor={c.textTertiary}
                autoCapitalize="characters"
                autoCorrect={false}
                textContentType="username"
                autoComplete="username"
                returnKeyType={password ? "go" : "next"}
                submitBehavior={password ? "blurAndSubmit" : "submit"}
                onSubmitEditing={() =>
                  password ? void onSignIn() : passwordRef.current?.focus()
                }
                maxLength={64}
                value={neptunCode}
                onChangeText={(v) => {
                  live.current.code = cleanCode(v);
                  setNeptunCode(live.current.code);
                }}
              />
              <TextInput
                style={field}
                placeholder={t.login.passwordPlaceholder}
                placeholderTextColor={c.textTertiary}
                ref={passwordRef}
                secureTextEntry
                textContentType="password"
                autoComplete="current-password"
                returnKeyType="go"
                submitBehavior="blurAndSubmit"
                onSubmitEditing={() => void onSignIn()}
                maxLength={128}
                value={password}
                onChangeText={(v) => {
                  const next = cleanPassword(v);
                  // whole password in one change = autofill or paste. ios leaves the keyboard on a stale return key after that, so just go
                  const filled = !live.current.pw && next.length > 3;
                  live.current.pw = next;
                  setPassword(next);
                  if (filled && live.current.code && institute && !busy)
                    void onSignIn();
                }}
              />
              {error ? (
                <Text style={{ color: c.danger, fontSize: 14 }}>{error}</Text>
              ) : null}
            </View>

            <View style={{ gap: Spacing.two }}>
              <PrimaryButton
                label={busy ? t.login.signingIn : t.login.signInReal}
                onPress={onSignIn}
                busy={busy}
                c={c}
              />
              <Pressable
                onPress={signInDemo}
                disabled={busy}
                style={({ pressed }) => ({
                  borderRadius: Radius.md,
                  paddingVertical: Spacing.three,
                  alignItems: "center",
                  flexDirection: "row",
                  justifyContent: "center",
                  gap: Spacing.two,
                  borderWidth: 1,
                  borderColor: c.separator,
                  opacity: pressed ? 0.6 : 1,
                  borderCurve: "continuous",
                })}
              >
                <SymbolView
                  name="play.circle.fill"
                  tintColor={c.textSecondary}
                  size={20}
                />
                <Text
                  style={{
                    color: c.textSecondary,
                    fontSize: 16,
                    fontWeight: "600",
                  }}
                >
                  {t.login.exploreDemo}
                </Text>
              </Pressable>
            </View>
          </>
        )}

        {inTwoFactor ? null : (
          <>
            <Text
              style={{
                color: c.textTertiary,
                fontSize: 12,
                textAlign: "center",
                lineHeight: 17,
              }}
            >
              {t.login.disclaimer}
            </Text>
            <LanguageSelector />
          </>
        )}

        <InstitutionPicker
          visible={pickerOpen}
          onClose={() => setPickerOpen(false)}
          onSelect={setInstitute}
        />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

function PrimaryButton({
  label,
  onPress,
  busy,
  c,
}: {
  label: string;
  onPress: () => void;
  busy: boolean;
  c: ReturnType<typeof useTheme>;
}) {
  return (
    <Pressable
      onPress={onPress}
      disabled={busy}
      style={({ pressed }) => ({
        backgroundColor: c.brand,
        borderRadius: Radius.md,
        paddingVertical: Spacing.three,
        alignItems: "center",
        flexDirection: "row",
        justifyContent: "center",
        gap: Spacing.two,
        opacity: pressed || busy ? 0.85 : 1,
        borderCurve: "continuous",
      })}
    >
      {busy ? <ActivityIndicator color={c.brandOn} /> : null}
      <Text style={{ color: c.brandOn, fontSize: 16, fontWeight: "700" }}>
        {label}
      </Text>
    </Pressable>
  );
}

function ExpiryCard({
  reason,
  onDismiss,
  tx,
  c,
}: {
  reason: "twoFactor" | "password" | "expired";
  onDismiss: () => void;
  tx: ReturnType<typeof useI18n>["tx"];
  c: ReturnType<typeof useTheme>;
}) {
  const e = tx.v2.expiry;
  const tips = reason === "password" ? [] : [e.tipTotp, e.tipSync, e.tipOpen];
  return (
    <View
      style={{
        backgroundColor: c.warningSubtle,
        borderRadius: 22,
        borderCurve: "continuous",
        padding: Spacing.three,
        gap: Spacing.two,
      }}
    >
      <View
        style={{ flexDirection: "row", alignItems: "center", gap: Spacing.two }}
      >
        <SymbolView
          name="clock.badge.exclamationmark"
          tintColor={c.warning}
          size={20}
        />
        <Text
          style={{ color: c.text, fontSize: 17, fontWeight: "700", flex: 1 }}
        >
          {e.title}
        </Text>
        <Pressable onPress={onDismiss} hitSlop={10}>
          <SymbolView
            name="xmark.circle.fill"
            tintColor={c.textTertiary}
            size={20}
          />
        </Pressable>
      </View>
      <Text style={{ color: c.text, fontSize: 14, lineHeight: 20 }}>
        {e[reason]}
      </Text>
      {tips.length ? (
        <View style={{ gap: 6 }}>
          <Text
            style={{ color: c.textSecondary, fontSize: 13, fontWeight: "600" }}
          >
            {e.howTo}
          </Text>
          {tips.map((tip) => (
            <View key={tip} style={{ flexDirection: "row", gap: Spacing.two }}>
              <SymbolView
                name="checkmark.circle.fill"
                tintColor={c.success}
                size={14}
              />
              <Text
                style={{
                  color: c.textSecondary,
                  fontSize: 13,
                  lineHeight: 18,
                  flex: 1,
                }}
              >
                {tip}
              </Text>
            </View>
          ))}
        </View>
      ) : null}
    </View>
  );
}