package com.example.sorted_out

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

class AddEntryWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, buildRemoteViews(context))
        }
    }

    companion object {
        fun refreshAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName =
                android.content.ComponentName(context, AddEntryWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (appWidgetId in appWidgetIds) {
                appWidgetManager.updateAppWidget(appWidgetId, buildRemoteViews(context))
            }
        }

        private fun buildRemoteViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.add_entry_widget)
            views.setOnClickPendingIntent(
                R.id.widget_add_entry_button,
                createAddEntryIntent(context),
            )

            val incomingTitles = IncomingWidgetDataStore.loadIncomingTitles(context)
            val titleViewIds =
                listOf(
                    R.id.widget_incoming_item_1,
                    R.id.widget_incoming_item_2,
                    R.id.widget_incoming_item_3,
                    R.id.widget_incoming_item_4,
                )

            if (incomingTitles.isEmpty()) {
                views.setViewVisibility(R.id.widget_incoming_empty, View.VISIBLE)
                titleViewIds.forEach { id -> views.setViewVisibility(id, View.GONE) }
            } else {
                views.setViewVisibility(R.id.widget_incoming_empty, View.GONE)
                titleViewIds.forEachIndexed { index, id ->
                    if (index < incomingTitles.size) {
                        views.setTextViewText(id, "\u2022 ${incomingTitles[index]}")
                        views.setViewVisibility(id, View.VISIBLE)
                    } else {
                        views.setViewVisibility(id, View.GONE)
                    }
                }
            }

            return views
        }

        private fun createAddEntryIntent(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_ADD_START_ENTRY
                flags =
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
