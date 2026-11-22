package com.voltpulse.voltpulse

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import kotlin.math.abs

/** Home-screen widget: battery %, wattage and charging status. */
class BatteryWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val snap = BatteryMonitor.last ?: BatteryReader.read(context, null, BatteryMonitor.store)
        updateAll(context, snap)
    }

    companion object {
        fun updateAll(ctx: Context, s: Map<String, Any?>) {
            val manager = AppWidgetManager.getInstance(ctx)
            val ids = manager.getAppWidgetIds(ComponentName(ctx, BatteryWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val level = s["level"] as Int
            val charger = s["charger"] as String
            val status = s["status"] as String
            val watts = (s["voltageMv"] as Int) / 1000.0 * abs(s["currentMa"] as Double) / 1000.0
            val statusText = when {
                status == "full" -> "Full · unplug now"
                charger != "none" -> "Charging via ${charger.uppercase()}"
                else -> "Discharging"
            }
            val open = PendingIntent.getActivity(
                ctx, 10, Intent(ctx, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val views = RemoteViews(ctx.packageName, R.layout.battery_widget).apply {
                setTextViewText(R.id.widget_percent, "$level%")
                setTextViewText(R.id.widget_watts, "%s%.1f W".format(if (charger != "none") "⚡ " else "", watts))
                setTextViewText(R.id.widget_status, statusText)
                setProgressBar(R.id.widget_progress, 100, level, false)
                setOnClickPendingIntent(R.id.widget_root, open)
            }
            manager.updateAppWidget(ids, views)
        }
    }
}
