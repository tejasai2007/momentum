package com.tickoffclone.app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Base64
import android.util.Log
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Handles a tap on a widget habit row *natively*.
 *
 * Why not the `home_widget` Dart background callback? The background isolate
 * spawned by `home_widget` is a bare FlutterEngine that does NOT register the
 * Flutter plugins, so `shared_preferences` (which `supabase_flutter` needs to
 * restore the logged-in session) is unavailable there and every tap silently
 * failed. Instead we tick the habit straight from Kotlin using the Supabase
 * REST API, authenticating with the session token the app stores in the
 * widget's SharedPreferences (see lib/services/widget_service.dart).
 */
class HabitTickReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val pendingResult = goAsync()

        // Extract habitId and done status from extras (primary) or URI data (fallback)
        val habitId = intent?.getStringExtra("habitId")
            ?: intent?.data?.getQueryParameter("habitId")

        if (habitId == null) {
            Log.w(TAG, "Missing habitId in tick intent")
            pendingResult.finish()
            return
        }

        val wasDone = if (intent != null && intent.hasExtra("doneToday")) {
            intent.getBooleanExtra("doneToday", false)
        } else {
            intent?.data?.getQueryParameter("doneToday")?.toBoolean() ?: false
        }

        val targetDone = !wasDone
        val prefs = HomeWidgetPlugin.getData(context)

        // 1. Instantly update widget UI optimistically (checkbox & streak)
        setDoneLocally(context, prefs, habitId, targetDone)

        // 2. Broadcast to the running app so UI can update immediately if open
        val syncIntent = Intent(ACTION_HABIT_TICKED).apply {
            setPackage(context.packageName)
            putExtra("habitId", habitId)
            putExtra("doneToday", targetDone)
        }
        context.sendBroadcast(syncIntent)

        val url = prefs.getString(KEY_URL, null)
        val anonKey = prefs.getString(KEY_ANON, null)
        var token = prefs.getString(KEY_TOKEN, null)
        val refreshToken = prefs.getString(KEY_REFRESH, null)
        val storedUserId = prefs.getString(KEY_USER_ID, null)

        if (url == null || anonKey == null || token == null) {
            Log.w(TAG, "Supabase config/session missing; toggled locally in widget only")
            pendingResult.finish()
            return
        }

        val displayDate = SimpleDateFormat(DATE_FMT, Locale.US).format(Date())

        val initialToken = token

        Thread {
            try {
                var currentToken = initialToken
                val userId = storedUserId ?: jwtSub(currentToken)
                if (userId == null) {
                    Log.e(TAG, "Cannot determine user ID for Supabase tick")
                    return@Thread
                }

                var respCode = if (targetDone) {
                    tickInSupabase(url, anonKey, currentToken, habitId, userId, displayDate)
                } else {
                    untickInSupabase(url, anonKey, currentToken, habitId, displayDate)
                }

                // If unauthorized (e.g. JWT expired after 1 hr), refresh token and retry
                if (respCode == 401 && refreshToken != null) {
                    Log.i(TAG, "Token expired (401), attempting session refresh...")
                    val refreshed = refreshTokens(url, anonKey, refreshToken)
                    if (refreshed != null) {
                        currentToken = refreshed.first
                        prefs.edit()
                            .putString(KEY_TOKEN, refreshed.first)
                            .putString(KEY_REFRESH, refreshed.second)
                            .apply()

                        respCode = if (targetDone) {
                            tickInSupabase(url, anonKey, currentToken, habitId, userId, displayDate)
                        } else {
                            untickInSupabase(url, anonKey, currentToken, habitId, displayDate)
                        }
                    }
                }

                val success = respCode in 200..299
                if (!success) {
                    Log.e(TAG, "Supabase write failed (code $respCode); reverting widget state")
                    setDoneLocally(context, prefs, habitId, wasDone)
                    val revertIntent = Intent(ACTION_HABIT_TICKED).apply {
                        setPackage(context.packageName)
                        putExtra("habitId", habitId)
                        putExtra("doneToday", wasDone)
                    }
                    context.sendBroadcast(revertIntent)
                } else {
                    Log.i(TAG, "Supabase sync succeeded for habit $habitId (done=$targetDone)")
                }
            } catch (t: Throwable) {
                Log.e(TAG, "Widget tick failed unexpectedly", t)
                setDoneLocally(context, prefs, habitId, wasDone)
            } finally {
                pendingResult.finish()
            }
        }.start()
    }

    /** Inserts or updates today's log in Supabase REST API. Returns HTTP response code. */
    private fun tickInSupabase(
        url: String,
        anonKey: String,
        token: String,
        habitId: String,
        userId: String,
        logDate: String,
    ): Int {
        val endpoint = "$url/rest/v1/habit_logs?on_conflict=habit_id,log_date"
        val body = JSONObject()
            .put("habit_id", habitId)
            .put("user_id", userId)
            .put("log_date", logDate)
            .toString()

        val conn = URL(endpoint).openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.connectTimeout = CONNECT_TIMEOUT_MS
            conn.readTimeout = READ_TIMEOUT_MS
            setSupabaseHeaders(conn, anonKey, token)
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Prefer", "resolution=merge-duplicates,return=minimal")
            OutputStreamWriter(conn.outputStream).use { it.write(body) }

            val code = conn.responseCode
            if (code !in 200..299) {
                val err = conn.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
                Log.e(TAG, "Supabase tick failed: HTTP $code: $err")
            }
            code
        } catch (e: Exception) {
            Log.e(TAG, "Supabase tick error", e)
            -1
        } finally {
            conn.disconnect()
        }
    }

    /** Deletes today's habit_log row in Supabase REST API. Returns HTTP response code. */
    private fun untickInSupabase(
        url: String,
        anonKey: String,
        token: String,
        habitId: String,
        logDate: String,
    ): Int {
        val endpoint = "$url/rest/v1/habit_logs" +
            "?habit_id=eq.$habitId" +
            "&log_date=eq.$logDate"
        val conn = URL(endpoint).openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = "DELETE"
            conn.connectTimeout = CONNECT_TIMEOUT_MS
            conn.readTimeout = READ_TIMEOUT_MS
            setSupabaseHeaders(conn, anonKey, token)

            val code = conn.responseCode
            if (code !in 200..299) {
                val err = conn.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
                Log.e(TAG, "Supabase untick failed: HTTP $code: $err")
            }
            code
        } catch (e: Exception) {
            Log.e(TAG, "Supabase untick error", e)
            -1
        } finally {
            conn.disconnect()
        }
    }

    /** Refreshes an expired access token using the stored refresh token. */
    private fun refreshTokens(
        url: String,
        anonKey: String,
        refreshToken: String,
    ): Pair<String, String>? {
        val endpoint = "$url/auth/v1/token?grant_type=refresh_token"
        val body = JSONObject().put("refresh_token", refreshToken).toString()
        val conn = URL(endpoint).openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.connectTimeout = CONNECT_TIMEOUT_MS
            conn.readTimeout = READ_TIMEOUT_MS
            conn.setRequestProperty("apikey", anonKey)
            conn.setRequestProperty("Content-Type", "application/json")
            OutputStreamWriter(conn.outputStream).use { it.write(body) }

            val code = conn.responseCode
            if (code in 200..299) {
                val resp = conn.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(resp)
                val newAccess = json.optString("access_token", "")
                val newRefresh = json.optString("refresh_token", "")
                if (newAccess.isNotEmpty() && newRefresh.isNotEmpty()) {
                    Pair(newAccess, newRefresh)
                } else {
                    null
                }
            } else {
                val err = conn.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
                Log.e(TAG, "Token refresh failed: HTTP $code: $err")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Token refresh network error", e)
            null
        } finally {
            conn.disconnect()
        }
    }

    private fun setSupabaseHeaders(conn: HttpURLConnection, anonKey: String, token: String) {
        conn.setRequestProperty("apikey", anonKey)
        conn.setRequestProperty("Authorization", "Bearer $token")
    }

    /**
     * Updates `doneToday` and `streak` for the tapped habit in the stored widget JSON
     * so the widget redraws immediately without waiting for server network responses.
     */
    private fun setDoneLocally(
        context: Context,
        prefs: android.content.SharedPreferences,
        habitId: String,
        done: Boolean,
    ) {
        val raw = prefs.getString("today_habits_json", null) ?: return
        val arr = try {
            JSONArray(raw)
        } catch (e: Exception) {
            return
        }
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            if (habitId == o.optString("id")) {
                val previousDone = o.optBoolean("doneToday", false)
                o.put("doneToday", done)
                val currentStreak = o.optInt("streak", 0)
                if (done && !previousDone) {
                    o.put("streak", currentStreak + 1)
                } else if (!done && previousDone && currentStreak > 0) {
                    o.put("streak", currentStreak - 1)
                }
            }
        }
        prefs.edit().putString("today_habits_json", arr.toString()).apply()

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, HabitWidgetProvider::class.java)
        )
        manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_habit_list)
        context.sendBroadcast(
            Intent(context, HabitWidgetProvider::class.java)
                .setAction("com.tickoffclone.app.REFRESH_WIDGET")
        )
    }

    /** Decodes the `sub` (user id) claim from the access-token JWT payload. */
    private fun jwtSub(token: String): String? {
        return try {
            val parts = token.split(".")
            if (parts.size < 2) return null
            val payload = String(Base64.decode(parts[1], Base64.URL_SAFE or Base64.NO_WRAP))
            JSONObject(payload).optString("sub").takeIf { it.isNotEmpty() }
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        private const val TAG = "HabitTickReceiver"
        const val ACTION_HABIT_TICKED = "com.tickoffclone.app.HABIT_TICKED"
        private const val KEY_URL = "supabase_url"
        private const val KEY_ANON = "supabase_anon_key"
        private const val KEY_TOKEN = "supabase_access_token"
        private const val KEY_REFRESH = "supabase_refresh_token"
        private const val KEY_USER_ID = "user_id"
        private const val DATE_FMT = "yyyy-MM-dd"
        private const val CONNECT_TIMEOUT_MS = 6000
        private const val READ_TIMEOUT_MS = 6000
    }
}
