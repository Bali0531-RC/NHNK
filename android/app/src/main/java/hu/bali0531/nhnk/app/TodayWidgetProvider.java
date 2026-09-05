package hu.bali0531.nhnk.app;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;

/**
 * Reads the timetable straight out of the cache the Flutter side already writes, so the
 * widget needs no plugin, no extra permission and no background work of its own.
 * shared_preferences stores under FlutterSharedPreferences with a "flutter." key prefix.
 */
public class TodayWidgetProvider extends AppWidgetProvider {

    private static final String PREFS = "FlutterSharedPreferences";
    private static final String PREFIX = "flutter.";

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        for (int id : ids) {
            manager.updateAppWidget(id, buildViews(context));
        }
        scheduleNextBoundary(context);
    }

    /**
     * updatePeriodMillis cannot go below 30 minutes, which would leave the countdown wrong
     * by up to half an hour. An inexact alarm at the next class boundary costs no permission
     * and pulls the widget back in line at the only moments the text actually changes.
     */
    private void scheduleNextBoundary(Context context) {
        try {
            SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            long now = System.currentTimeMillis();
            long next = Long.MAX_VALUE;

            for (String[] row : readToday(prefs)) {
                try {
                    long start = Long.parseLong(row[3]);
                    long end = Long.parseLong(row[4]);
                    if (start > now) next = Math.min(next, start);
                    if (end > now) next = Math.min(next, end);
                } catch (NumberFormatException ignored) {
                    // A malformed row should not stop the rest from scheduling.
                }
            }
            if (next == Long.MAX_VALUE) {
                return;
            }

            AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (alarms == null) {
                return;
            }
            Intent intent = new Intent(context, TodayWidgetProvider.class);
            intent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
            PendingIntent pending = PendingIntent.getBroadcast(
                    context, 1, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            alarms.set(AlarmManager.RTC, next + 1000L, pending);
        } catch (Exception ignored) {
            // The widget is still correct without this, just coarser.
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        if (AppWidgetManager.ACTION_APPWIDGET_UPDATE.equals(intent.getAction())) {
            AppWidgetManager manager = AppWidgetManager.getInstance(context);
            int[] ids = manager.getAppWidgetIds(new android.content.ComponentName(context, TodayWidgetProvider.class));
            for (int id : ids) {
                manager.updateAppWidget(id, buildViews(context));
            }
        }
    }

    private RemoteViews buildViews(Context context) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_today);
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);

        boolean hungarian = Locale.getDefault().getLanguage().startsWith("hu");
        views.setTextViewText(R.id.widget_title, hungarian ? "Mai órák" : "Today");

        List<String[]> today = readToday(prefs);
        long writtenAt = prefs.getLong(PREFIX + "CalendarCacheWrittenAt", 0);
        String cacheTime = prefs.getString(PREFIX + "CalendarCacheTime", null);
        // The widget cannot fetch anything itself, so an app that has not been opened
        // for a day leaves it confidently showing yesterday. Say so rather than
        // presenting stale data as current.
        boolean stale = isStale(writtenAt, cacheTime);

        if (today.isEmpty()) {
            views.setTextViewText(R.id.widget_body, stale
                    ? (hungarian ? "Nyisd meg az appot a friss\u00edt\u00e9shez."
                                 : "Open the app to refresh.")
                    : (hungarian ? "Ma nincs \u00f3r\u00e1d." : "No classes today."));
            views.setViewVisibility(R.id.widget_next, android.view.View.GONE);
        } else {
            String headline = buildHeadline(today, hungarian);
            if (headline == null) {
                views.setViewVisibility(R.id.widget_next, android.view.View.GONE);
            } else {
                views.setTextViewText(R.id.widget_next, headline);
                views.setViewVisibility(R.id.widget_next, android.view.View.VISIBLE);
            }

            StringBuilder body = new StringBuilder();
            for (String[] row : today) {
                if (body.length() > 0) {
                    body.append('\n');
                }
                body.append(row[0]).append("  ").append(row[1]);
                if (row[2] != null && !row[2].isEmpty() && !"NULL".equals(row[2])) {
                    body.append(" · ").append(row[2]);
                }
            }
            views.setTextViewText(R.id.widget_body, body.toString());
        }

        views.setTextViewText(R.id.widget_updated, updatedLabel(writtenAt, cacheTime, stale, hungarian));

        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (launch != null) {
            PendingIntent pending = PendingIntent.getActivity(
                    context, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            views.setOnClickPendingIntent(R.id.widget_body, pending);
            views.setOnClickPendingIntent(R.id.widget_title, pending);
        }
        return views;
    }

    /** Entries are stored as newline separated fields: start, end, location, title, ... */
    private List<String[]> readToday(SharedPreferences prefs) {
        List<String[]> out = new ArrayList<>();
        long length = prefs.getLong(PREFIX + "CachedCalendarLength", 0);

        Calendar dayStart = Calendar.getInstance();
        dayStart.set(Calendar.HOUR_OF_DAY, 0);
        dayStart.set(Calendar.MINUTE, 0);
        dayStart.set(Calendar.SECOND, 0);
        dayStart.set(Calendar.MILLISECOND, 0);
        long from = dayStart.getTimeInMillis();
        long to = from + 24L * 60L * 60L * 1000L;

        for (int i = 0; i < length; i++) {
            String raw = prefs.getString(PREFIX + "CachedCalendar_" + i, null);
            if (raw == null) {
                continue;
            }
            String[] parts = raw.split("\n");
            if (parts.length < 4) {
                continue;
            }
            long start;
            try {
                start = Long.parseLong(parts[0].trim());
            } catch (NumberFormatException ignored) {
                continue;
            }
            if (start < from || start >= to) {
                continue;
            }
            Calendar c = Calendar.getInstance();
            c.setTimeInMillis(start);
            String clock = String.format(Locale.getDefault(), "%02d:%02d",
                    c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE));
            out.add(new String[]{clock, parts[3], parts[2], parts[0].trim(), parts[1].trim()});
        }
        return out;
    }

    /**
     * "Now" beats "next": during a class the useful answer is when it ends, and after the
     * last one there is nothing worth a headline at all.
     */
    private String buildHeadline(List<String[]> today, boolean hungarian) {
        long now = System.currentTimeMillis();

        for (String[] row : today) {
            long start;
            long end;
            try {
                start = Long.parseLong(row[3]);
                end = Long.parseLong(row[4]);
            } catch (NumberFormatException ignored) {
                continue;
            }

            if (now >= start && now < end) {
                long minutes = Math.max(1, (end - now) / 60000L);
                return (hungarian ? "Most: " : "Now: ") + row[1]
                        + (hungarian ? "  (még " + describe(minutes, true) + ")"
                                     : "  (" + describe(minutes, false) + " left)");
            }
            if (start > now) {
                long minutes = Math.max(1, (start - now) / 60000L);
                return (hungarian ? "Következő " + describe(minutes, true) + " múlva: "
                                  : "Next in " + describe(minutes, false) + ": ") + row[1];
            }
        }
        return null;
    }

    private String describe(long minutes, boolean hungarian) {
        if (minutes < 60) {
            return minutes + (hungarian ? " perc" : " min");
        }
        long hours = minutes / 60;
        long rest = minutes % 60;
        if (rest == 0) {
            return hours + (hungarian ? " óra" : "h");
        }
        return hours + (hungarian ? " óra " + rest + " perc" : "h " + rest + "m");
    }

    /**
     * Installs that predate CalendarCacheWrittenAt have no real timestamp, so fall back
     * to the cache date. Treating a missing key as stale would tell every existing user
     * to refresh the moment they update.
     */
    private boolean isStale(long writtenAt, String iso) {
        if (writtenAt > 0) {
            return System.currentTimeMillis() - writtenAt > 24L * 60L * 60L * 1000L;
        }
        if (iso == null || iso.length() < 10) {
            return false;
        }
        Calendar midnight = Calendar.getInstance();
        midnight.set(Calendar.HOUR_OF_DAY, 0);
        midnight.set(Calendar.MINUTE, 0);
        midnight.set(Calendar.SECOND, 0);
        midnight.set(Calendar.MILLISECOND, 0);
        return !iso.substring(0, 10).equals(String.format(Locale.US, "%04d-%02d-%02d",
                midnight.get(Calendar.YEAR), midnight.get(Calendar.MONTH) + 1,
                midnight.get(Calendar.DAY_OF_MONTH)));
    }

    /**
     * Older builds only stored the cache date at midnight, so there is no real time to
     * show for them; the date is the honest answer rather than a fake 00:00.
     */
    private String updatedLabel(long writtenAt, String iso, boolean stale, boolean hungarian) {
        if (writtenAt > 0) {
            if (stale) {
                // stale only becomes true past the 24h mark, so this is at least 1.
                long days = (System.currentTimeMillis() - writtenAt) / (24L * 60L * 60L * 1000L);
                return hungarian ? days + " napja" : days + "d ago";
            }
            Calendar c = Calendar.getInstance();
            c.setTimeInMillis(writtenAt);
            return String.format(Locale.getDefault(), "%02d:%02d",
                    c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE));
        }
        if (iso != null && iso.length() >= 10) {
            return iso.substring(0, 10);
        }
        return "";
    }
}
