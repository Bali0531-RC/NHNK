// keep junk out of neptun so nobody gets their account locked
const CONTROL = /[\u0000-\u001F\u007F]/g;

export const cleanCode = (s: string) => s.replace(/[^A-Za-z0-9._@-]/g, '').slice(0, 64);
export const cleanPassword = (s: string) => s.replace(CONTROL, '').slice(0, 128);
export const cleanOtp = (s: string) => s.replace(/\D/g, '').slice(0, 6);

export function otpFromText(text: string): string | null {
  const hit = text.match(/(?<!\d)\d{3}[\s-]?\d{3}(?!\d)/);
  return hit ? hit[0].replace(/\D/g, '') : null;
}

let failures = 0;
let lockedUntil = 0;

export function cooldownLeft(now = Date.now()): number {
  return Math.max(0, Math.ceil((lockedUntil - now) / 1000));
}

export function noteAttempt(ok: boolean, now = Date.now()) {
  if (ok) {
    failures = 0;
    lockedUntil = 0;
    return;
  }
  failures += 1;
  if (failures >= 3) lockedUntil = now + Math.min(300, 15 * 2 ** (failures - 3)) * 1000;
}