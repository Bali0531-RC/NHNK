// Shapes for the Neptun client. Names follow the captured API, not the Dart source,
// so the JSON maps straight onto these.

export type Institute = {
  name: string;
  url: string;
  fallbacks: string[];
};

// Mirrors the Dart login return codes (0/1/2) as something the UI can switch on.
// 'twoFactor' means the server accepted the password and now wants a code.
// 'failed' is a real rejection (wrong password, locked account); message is Neptun's own.
// 'network' is no answer at all, which must never be shown as a wrong password.
export type LoginOutcome =
  | { kind: 'ok' }
  | { kind: 'twoFactor' }
  | { kind: 'failed'; message: string | null }
  | { kind: 'network' };

export type StoredSession = {
  instituteUrl: string;
  username: string;
  isModernApi: boolean;
  isDemo: boolean;
};
