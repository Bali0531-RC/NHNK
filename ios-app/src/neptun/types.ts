// neptun client shapes, named after the real api

export type Institute = {
  name: string;
  url: string;
  fallbacks: string[];
};

// twoFactor = password ok, wants a code. failed = real rejection. network = no answer, never a wrong password
export type LoginOutcome =
  | { kind: 'ok' }
  | { kind: 'twoFactor' }
  | { kind: 'failed'; message: string | null; legacy?: boolean; server?: boolean }
  | { kind: 'network' };

export type StoredSession = {
  instituteUrl: string;
  username: string;
  isModernApi: boolean;
  isDemo: boolean;
};