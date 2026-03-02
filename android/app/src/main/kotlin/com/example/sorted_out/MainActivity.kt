package com.example.sorted_out

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val ACTION_ADD_START_ENTRY = "com.example.sorted_out.ADD_START_ENTRY"
        private const val WIDGET_CHANNEL = "mind/widget_actions"
    }

    private var pendingAddEntryRequest = false
    private var widgetChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isAddEntryIntent(intent)) {
            pendingAddEntryRequest = true
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (!isAddEntryIntent(intent)) {
            return
        }

        if (widgetChannel == null) {
            pendingAddEntryRequest = true
            return
        }

        widgetChannel?.invokeMethod("openAddEntry", null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL,
        )
        widgetChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingAddEntry" -> {
                    result.success(pendingAddEntryRequest)
                    pendingAddEntryRequest = false
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAddEntryIntent(intent: Intent?): Boolean {
        return intent?.action == ACTION_ADD_START_ENTRY
    }
}
