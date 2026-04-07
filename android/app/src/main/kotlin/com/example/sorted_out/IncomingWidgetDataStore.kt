package com.example.sorted_out

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object IncomingWidgetDataStore {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val STATE_KEY = "flutter.task_board_state"

    fun loadIncomingTitles(context: Context, limit: Int = 4): List<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val rawJson = prefs.getString(STATE_KEY, null) ?: return emptyList()

        return try {
            val root = JSONObject(rawJson)
            val data = if (root.has("data")) root.getJSONObject("data") else root
            val incoming = data.optJSONArray("incomingTasks") ?: JSONArray()
            buildList {
                for (index in 0 until minOf(incoming.length(), limit)) {
                    val item = incoming.opt(index)
                    if (item is JSONObject) {
                        val title = item.optString("title").trim()
                        if (title.isNotEmpty()) {
                            add(title)
                        }
                    } else if (item is String) {
                        val title = item.trim()
                        if (title.isNotEmpty()) {
                            add(title)
                        }
                    }
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
