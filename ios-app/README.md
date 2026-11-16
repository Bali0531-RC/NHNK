# NHNK iOS (Expo)

Native iOS rebuild of NHNK, the unofficial Neptun client. Lives in `/ios-app` on the
`ios-app` branch. The Flutter app, Android builds, CI and tags in the repo root are
untouched by anything in here.

This is a separate app, not a port of the Flutter UI. It reuses the documented Neptun
API contract (see `../API-DOCS`), not the Dart code.

## Status

Demo-stage shell. Native navigation, design system, Hungarian + English, and a demo
mode with fixture data. Real Neptun authentication (Account/Authenticate, TOTP,
GetNewTokens refresh, SecureStore) is the next milestone and is not wired yet. The
login screen's demo button is the way in.

## Stack

- Expo SDK 57, React Native 0.86, TypeScript, Expo Router v7 (native tabs + stacks)
- expo-symbols for SF Symbols, native light/dark, `@/` alias to `src/`

## Running it (your workflow)

You are on Windows. iOS cannot be built locally here; Metro runs on the PC, the app
runs on your iPhone, and native builds happen on EAS (cloud Mac).

Day to day, with the demo running in Expo Go or a dev build:

```bash
cd ios-app
npx expo start --tunnel
```

Scan the QR with the iPhone. Tunnel mode works across networks. Fast Refresh applies
JS changes instantly. You only need a new native build when native modules or config
change, not for UI edits.

Typecheck before committing:

```bash
cd ios-app
npx tsc --noEmit
```

## Layout

```
src/
  app/
    _layout.tsx                root providers + auth-gated stack
    login.tsx                  login screen (demo entry)
    (tabs)/
      _layout.tsx              native tab bar
      (dashboard)/             home: next class, credits, exams
      (timetable)/             weekly schedule
      (grades)/                grades + averages
      (settings)/              language, about, sign out
  components/                  ui kit + tab stack
  constants/theme.ts           colors, spacing, radius
  i18n/                        hu + en strings, provider
  providers/auth.tsx           demo session state
  demo/data.ts                 fixture data (shapes mirror the real API)
```

## Next

1. Neptun auth lifecycle against a real institution
2. Live timetable, grades, exams from the modern API with legacy fallback
3. Offline cache + last-sync timestamps
4. Local notifications for exams and classes
5. EAS production build to TestFlight

## Attribution

Based on NHNK by Bali0531, itself a fork of Neptun 2 (domedav) by way of the Neptun
Mobile fork (zoligamer). MIT licensed, see `../LICENSE`.
