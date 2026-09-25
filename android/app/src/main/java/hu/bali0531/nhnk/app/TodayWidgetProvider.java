package hu.bali0531.nhnk.app;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.os.SystemClock;
import android.view.View;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import es.antonborri.home_widget.HomeWidgetBackgroundIntent;
import es.antonborri.home_widget.HomeWidgetPlugin;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;

public class TodayWidgetProvider extends AppWidgetProvider {

    private static final String PREFS = "FlutterSharedPreferences";
    private static final String PREFIX = "flutter.";
    private static final String BOUNDARY = "hu.bali0531.nhnk.WIDGET_BOUNDARY";

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        for (int id : ids) {
            manager.updateAppWidget(id, buildViews(context));
        }
        scheduleNextBoundary(context);
    }

    @Override
    public void onEnabled(Context context) {
        super.onEnabled(context);
        try {
            refreshIntent(context).send();
        } catch (PendingIntent.CanceledException ignored) {
        }
    }

    @Override
    public void onDisabled(Context context) {
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarms != null) alarms.cancel(boundaryIntent(context));
        super.onDisabled(context);
    }

    private static PendingIntent refreshIntent(Context context) {
        return HomeWidgetBackgroundIntent.INSTANCE.getBroadcast(context, Uri.parse("nhnk://refresh"));
    }

    private static PendingIntent boundaryIntent(Context context) {
        Intent intent = new Intent(context, TodayWidgetProvider.class).setAction(BOUNDARY);
        return PendingIntent.getBroadcast(context, 1, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private void scheduleNextBoundary(Context context) {
        try {
            SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            long now = System.currentTimeMillis();
            Calendar tomorrow = Calendar.getInstance();
            tomorrow.set(Calendar.HOUR_OF_DAY, 0);
            tomorrow.set(Calendar.MINUTE, 0);
            tomorrow.set(Calendar.SECOND, 0);
            tomorrow.set(Calendar.MILLISECOND, 0);
            tomorrow.add(Calendar.DAY_OF_MONTH, 1);
            long next = tomorrow.getTimeInMillis();

            for (String[] row : readToday(prefs, snapshot(context, prefs))) {
                try {
                    long start = Long.parseLong(row[3]);
                    long end = Long.parseLong(row[4]);
                    if (start > now) next = Math.min(next, start);
                    if (end > now) next = Math.min(next, end);
                } catch (NumberFormatException ignored) {
                    // A malformed row should not stop the rest from scheduling.
                }
            }
            AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (alarms == null) {
                return;
            }
            PendingIntent pending = boundaryIntent(context);
            boolean exactAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms();
            try {
                if (exactAllowed) {
                    alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next + 1000L, pending);
                    return;
                }
            } catch (SecurityException ignored) {
            }
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next + 1000L, pending);
        } catch (Exception ignored) {
            // The widget is still correct without this, just coarser.
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        String action = intent.getAction();
        if (BOUNDARY.equals(action) || Intent.ACTION_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)
                || Intent.ACTION_TIME_CHANGED.equals(action) || Intent.ACTION_TIMEZONE_CHANGED.equals(action)
                || (AppWidgetManager.ACTION_APPWIDGET_UPDATE.equals(action)
                    && intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS) == null)) {
            AppWidgetManager manager = AppWidgetManager.getInstance(context);
            int[] ids = manager.getAppWidgetIds(new android.content.ComponentName(context, TodayWidgetProvider.class));
            if (ids.length > 0) onUpdate(context, manager, ids);
        }
    }

    private boolean signedIn(SharedPreferences prefs) {
        return prefs.getLong(PREFIX + "HasLogin", 0) != 0
                || prefs.getLong(PREFIX + "ICS_HasIcsUpload", 0) != 0;
    }

    private JSONObject snapshot(Context context, SharedPreferences prefs) {
        if (!signedIn(prefs)) return new JSONObject();
        String raw = HomeWidgetPlugin.Companion.getData(context).getString("calendar_snapshot", null);
        if (raw == null) return null;
        try {
            JSONObject data = new JSONObject(raw);
            if (!data.optString("account").equals(prefs.getString(PREFIX + "Username", ""))
                    || !data.optString("institution").equals(prefs.getString(PREFIX + "URL", ""))) {
                return new JSONObject();
            }
            return data;
        } catch (JSONException ignored) {
            return null;
        }
    }

    private RemoteViews buildViews(Context context) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_today);
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);

        JSONObject data = snapshot(context, prefs);
        String language = data == null ? Locale.getDefault().getLanguage()
            : data.optString("language", Locale.getDefault().getLanguage());
        boolean hungarian = language.startsWith("hu");
        views.setTextViewText(R.id.widget_title, hungarian ? "Mai órák" : "Today");
        views.setContentDescription(R.id.widget_refresh, hungarian ? "Órarend frissítése" : "Refresh timetable");
        views.setOnClickPendingIntent(R.id.widget_refresh, refreshIntent(context));

        List<String[]> today = readToday(prefs, data);
        long writtenAt = data == null ? prefs.getLong(PREFIX + "CalendarCacheWrittenAt", 0)
            : data.optLong("writtenAt", 0);
        String cacheTime = data == null ? prefs.getString(PREFIX + "CalendarCacheTime", null) : null;
        boolean stale = isStale(writtenAt, cacheTime);
        views.setViewVisibility(R.id.widget_next, View.GONE);
        views.setViewVisibility(R.id.widget_countdown, View.GONE);
        views.setChronometer(R.id.widget_countdown, SystemClock.elapsedRealtime(), null, false);

        if (!signedIn(prefs)) {
            views.setTextViewText(R.id.widget_body, hungarian ? "Jelentkezz be az appban." : "Sign in to the app.");
        } else if (today.isEmpty()) {
            views.setTextViewText(R.id.widget_body, stale
                ? (hungarian ? "Nincs friss adat. Koppints a frissítésre."
                     : "No recent data. Tap refresh.")
                    : (hungarian ? "Ma nincs \u00f3r\u00e1d." : "No classes today."));
            views.setViewVisibility(R.id.widget_next, android.view.View.GONE);
        } else {
            showCountdown(views, today, hungarian);

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
    private List<String[]> readToday(SharedPreferences prefs, JSONObject data) {
        List<String[]> out = new ArrayList<>();
        JSONArray rows = data == null ? null : data.optJSONArray("entries");
        long length = data == null ? prefs.getLong(PREFIX + "CachedCalendarLength", 0)
                : (rows == null ? 0 : rows.length());

        Calendar dayStart = Calendar.getInstance();
        dayStart.set(Calendar.HOUR_OF_DAY, 0);
        dayStart.set(Calendar.MINUTE, 0);
        dayStart.set(Calendar.SECOND, 0);
        dayStart.set(Calendar.MILLISECOND, 0);
        long from = dayStart.getTimeInMillis();
        dayStart.add(Calendar.DAY_OF_MONTH, 1);
        long to = dayStart.getTimeInMillis();

        for (int index = 0; index < length; index++) {
            String raw = data == null ? prefs.getString(PREFIX + "CachedCalendar_" + index, null)
                    : rows.optString(index, null);
            if (raw == null) {
                continue;
            }
            String[] parts = raw.split("\n", -1);
            if (parts.length < 4) {
                continue;
            }
            long start;
            long end;
            try {
                start = Long.parseLong(parts[0].trim());
                end = Long.parseLong(parts[1].trim());
            } catch (NumberFormatException ignored) {
                continue;
            }
            if (start < from || start >= to || end <= start) {
                continue;
            }
            Calendar c = Calendar.getInstance();
            c.setTimeInMillis(start);
            String clock = String.format(Locale.getDefault(), "%02d:%02d",
                    c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE));
            out.add(new String[]{clock, parts[3], parts[2], parts[0].trim(), parts[1].trim()});
        }
        out.sort((first, second) -> Long.compare(Long.parseLong(first[3]), Long.parseLong(second[3])));
        return out;
    }

    /**
     * "Now" beats "next": during a class the useful answer is when it ends, and after the
     * last one there is nothing worth a headline at all.
     */
    private void showCountdown(RemoteViews views, List<String[]> today, boolean hungarian) {
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

            if (end <= now) continue;
            boolean active = start <= now;
            long boundary = active ? end : start;
            views.setTextViewText(R.id.widget_next,
                    (active ? (hungarian ? "Most: " : "Now: ") : (hungarian ? "Következő: " : "Next: ")) + row[1]);
            views.setViewVisibility(R.id.widget_next, View.VISIBLE);
            views.setViewVisibility(R.id.widget_countdown, View.VISIBLE);
            views.setChronometerCountDown(R.id.widget_countdown, true);
            views.setChronometer(R.id.widget_countdown, SystemClock.elapsedRealtime() + boundary - now,
                    active ? (hungarian ? "Hátralévő: %s" : "%s left")
                            : (hungarian ? "Kezdésig: %s" : "Starts in %s"), true);
            return;
        }
    }

    /**
     * Installs that predate CalendarCacheWrittenAt have no real timestamp, so fall back
     * to the cache date. Treating a missing key as stale would tell every existing user
     * to refresh the moment they update.
     */
    private boolean isStale(long writtenAt, String iso) {
        if (writtenAt > 0) {
            return System.currentTimeMillis() - writtenAt >= 24L * 60L * 60L * 1000L;
        }
        if (iso == null || iso.length() < 10) {
            return true;
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
                return hungarian ? days + " napos adat" : days + "d old";
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
