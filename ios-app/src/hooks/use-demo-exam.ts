import { useEffect } from 'react';
import { AppState } from 'react-native';

import { useI18n } from '@/i18n';
import { syncDemoExam } from '@/lib/exams';
import { demo } from '@/neptun/demo';
import { useAuth } from '@/providers/auth';

// demo only. the evening zh next to today's live class, so the calendar shows the whole thing without setup
export function useDemoExam(): void {
  const { status, isDemo } = useAuth();
  const { lang } = useI18n();
  useEffect(() => {
    if (status !== 'signedIn' || !isDemo) return;
    const run = () => {
      const h = demo.hero();
      if (!h) return;
      const titles = demo.examTitles();
      void syncDemoExam(h.examMs, titles, titles[lang === 'en' ? 1 : lang === 'de' ? 2 : 0]);
    };
    run();
    // opened before 8 or left open overnight, catch up on the next foreground
    const sub = AppState.addEventListener('change', (s) => {
      if (s === 'active') run();
    });
    return () => sub.remove();
  }, [status, isDemo, lang]);
}