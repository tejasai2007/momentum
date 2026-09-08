package com.tickoffclone.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val timezoneChannelName = "tickoffclone/timezone"
    private val widgetSyncChannelName = "tickoffclone/widget_sync"
    private var widgetSyncChannel: MethodChannel? = null

    private val habitTickReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val habitId = intent?.getStringExtra("habitId")
            val doneToday = intent?.getBooleanExtra("doneToday", false) ?: false
            widgetSyncChannel?.invokeMethod(
                "onHabitToggled",
                mapOf("habitId" to habitId, "doneToday" to doneToday)
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, timezoneChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLocalTimezone" -> result.success(TimeZone.getDefault().id)
                    else -> result.notImplemented()
                }
            }

        widgetSyncChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetSyncChannelName)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(HabitTickReceiver.ACTION_HABIT_TICKED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(habitTickReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(habitTickReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(habitTickReceiver)
        } catch (_: Exception) {}
    }
}