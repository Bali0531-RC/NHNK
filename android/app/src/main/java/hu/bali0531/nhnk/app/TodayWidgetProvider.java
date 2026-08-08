package hu.bali0531.nhnk.app;

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
    }

    private RemoteViews buildViews(Context context) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget_today);
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);

        boolean hungarian = Locale.getDefault().getLanguage().startsWith("hu");
        views.setTextViewText(R.id.widget_title, hungarian ? "Mai órák" : "Today");

        List<String[]> today = readToday(prefs);
        if (today.isEmpty()) {
            views.setTextViewText(R.id.widget_body,
                    hungarian ? "Ma nincs órád." : "No classes today.");
        } else {
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

        String cacheTime = prefs.getString(PREFIX + "CalendarCacheTime", null);
        views.setTextViewText(R.id.widget_updated, shortTime(cacheTime));

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
            out.add(new String[]{clock, parts[3], parts[2]});
        }
        return out;
    }

    private String shortTime(String iso) {
        if (iso == null || iso.length() < 16) {
            return "";
        }
        return iso.substring(11, 16);
    }
}
