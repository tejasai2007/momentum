package com.tickoffclone.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Renders the "Today's Habits" home screen widget.
 *
 * Data flow:
 *  - Flutter writes JSON into HomeWidget's SharedPreferences via
 *    `HomeWidget.saveWidgetData` (see lib/services/widget_service.dart).
 *  - This provider just points a ListView at [HabitWidgetService], which
 *    reads that same SharedPreferences file and renders one row per habit.
 *  - Tapping the whole widget opens the app. Tapping a habit row fires a
 *    broadcast handled by [HabitTickReceiver], which ticks the habit via the
 *    Supabase REST API *without* opening the UI, then asks the widget to
 *    refresh.
 */
class HabitWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == "com.tickoffclone.app.REFRESH_WIDGET"
        ) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(context, HabitWidgetProvider::class.java)
            )
            manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_habit_list)
        }
    }

    companion object {
        const val ACTION_TICK_HABIT = "com.tickoffclone.app.ACTION_TICK_HABIT"

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.habit_widget_layout)

            // Bind the ListView to our RemoteViewsService (one row per habit).
            // The unique `data` Uri (per widget id) is required so Android
            // treats each widget instance's adapter intent as distinct.
            val serviceIntent = Intent(context, HabitWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse("tickoffclone://widget/$appWidgetId")
            }
            views.setRemoteAdapter(R.id.widget_habit_list, serviceIntent)
            views.setEmptyView(R.id.widget_habit_list, R.id.widget_empty_view)

            // Template so each row's PendingIntent (set in the RemoteViewsFactory)
            // knows what to fill in — required for collection-based widgets.
            // FLAG_MUTABLE is mandatory on Android 12+ (API 31+) so the
            // fill-in intent can supply the habitId and toggle state to HabitTickReceiver.
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            val clickTemplateIntent = PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, HabitTickReceiver::class.java).apply {
                    action = ACTION_TICK_HABIT
                },
                flags
            )
            views.setPendingIntentTemplate(R.id.widget_habit_list, clickTemplateIntent)

            // Tapping the header opens the app itself.
            val openAppIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_title, openAppIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_habit_list)
        }
    }
}
