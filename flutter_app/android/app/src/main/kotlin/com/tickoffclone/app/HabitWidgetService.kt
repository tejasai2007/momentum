package com.tickoffclone.app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class HabitWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return HabitRemoteViewsFactory(applicationContext)
    }
}

private data class WidgetHabit(
    val id: String,
    val name: String,
    val color: String,
    val doneToday: Boolean,
    val streak: Int,
)

class HabitRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var habits: List<WidgetHabit> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        // HomeWidgetPlugin stores data in the same SharedPreferences file
        // that `HomeWidget.saveWidgetData` writes to from Dart.
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString("today_habits_json", null) ?: "[]"
        habits = try {
            parseHabits(raw)
        } catch (e: Exception) {
            emptyList()
        }
    }

    override fun onDestroy() {
        habits = emptyList()
    }

    override fun getCount(): Int = habits.size

    override fun getViewAt(position: Int): RemoteViews {
        val habit = habits[position]
        val views = RemoteViews(context.packageName, R.layout.habit_widget_item)
        views.setTextViewText(R.id.item_habit_name, habit.name)
        views.setTextViewText(R.id.item_habit_streak, "${habit.streak}d")
        views.setImageViewResource(
            R.id.item_habit_check,
            if (habit.doneToday) R.drawable.ic_check_circle_filled else R.drawable.ic_check_circle_outline
        )
        try {
            views.setTextColor(R.id.item_habit_name, Color.parseColor(habit.color))
        } catch (_: Exception) { /* fall back to default color from XML */ }

        // Fill in the template PendingIntent set on the ListView in
        // HabitWidgetProvider — this is what makes tapping THIS row tick or
        // un-tick THIS habit, even while the app is closed. Android merges this
        // Intent's `data` Uri into the container's PendingIntent template.
        // We attach it to the whole row (`item_container`) so tapping anywhere
        // on a habit row toggles it, not just the small check mark.
        // `doneToday` tells HabitTickReceiver whether this tap is a tick
        // (was not done) or an un-tick (was already done).
        val fillInIntent = Intent().apply {
            putExtra("habitId", habit.id)
            putExtra("doneToday", habit.doneToday)
            data = android.net.Uri.parse(
                "tickoffclone://tickhabit?habitId=${habit.id}&doneToday=${habit.doneToday}"
            )
        }
        views.setOnClickFillInIntent(R.id.item_container, fillInIntent)
        views.setOnClickFillInIntent(R.id.item_habit_check, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    private fun parseHabits(raw: String): List<WidgetHabit> {
        val arr = JSONArray(raw)
        val list = mutableListOf<WidgetHabit>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            list.add(
                WidgetHabit(
                    id = o.getString("id"),
                    name = o.getString("name"),
                    color = o.optString("color", "#6C5CE7"),
                    doneToday = o.optBoolean("doneToday", false),
                    streak = o.optInt("streak", 0),
                )
            )
        }
        return list
    }
}
