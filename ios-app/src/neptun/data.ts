// Typed reads over fetchModernData. Each one returns null when the value is not available,
// so screens keep their fallback instead of showing a blank or a wrong number. Only fields
// whose shape is confirmed in API-DOCS/schemas.md are trusted here; the rest wait for a
// captured shape rather than a guess.

import { fetchModernData } from './client';

export type CreditProgress = { completed: number; required: number };

// dashboard/creditprogress. Only completedCredit and requiredCredit are dependable; the
// breakdown fields are null even on institutions that serve this route.
export async function getCreditProgress(): Promise<CreditProgress | null> {
  const data = await fetchModernData<Record<string, unknown>>('dashboard/creditprogress');
  if (!data) return null;
  const completed = data.completedCredit;
  const required = data.requiredCredit;
  if (typeof completed === 'number' && typeof required === 'number' && required > 0) {
    return { completed, required };
  }
  return null;
}

// Message/GetUnreadedMessagesCount. One integer, used for the messages badge.
export async function getUnreadMessageCount(): Promise<number | null> {
  const data = await fetchModernData<Record<string, unknown>>('Message/GetUnreadedMessagesCount');
  if (!data) return null;
  const count = data.count;
  return typeof count === 'number' ? count : null;
}
