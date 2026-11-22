package com.voltpulse.voltpulse

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import kotlin.math.abs

/** Foreground service: keeps the monitor alive and shows a persistent "% · W" notification. */
class BatteryMonitorService : Service() {
    companion object {
        private const val NOTIFICATION_ID = 1001
        @Volatile var running = false
            private set
        private var lastNotifyAt = 0L

        fun start(ctx: Context) {
            val i = Intent(ctx, BatteryMonitorService::class.java)
            try {
                ctx.startForegroundService(i)
            } catch (_: Exception) {
                // Background-start restrictions (Android 12+) — it will start next time the app opens.
            }
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, BatteryMonitorService::class.java))
        }

        fun refresh(ctx: Context, s: Map<String, Any?>) {
            if (!running) return
            val now = System.currentTimeMillis()
            if (now - lastNotifyAt < 4000) return
            lastNotifyAt = now
            ctx.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, build(ctx, s))
        }

        fun build(ctx: Context, s: Map<String, Any?>?): Notification {
            val open = PendingIntent.getActivity(
                ctx, 0, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val b = Notification.Builder(ctx, AlertManager.CHANNEL_LIVE)
                .setSmallIcon(R.drawable.ic_stat_bolt)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setContentIntent(open)
            if (s == null) return b.setContentTitle("VoltPulse").setContentText("Monitoring battery…").build()

            val pct = s["percent"] as Double
            val level = s["level"] as Int
            val charger = s["charger"] as String
            val watts = (s["voltageMv"] as Int) / 1000.0 * abs(s["currentMa"] as Double) / 1000.0
            val temp = s["temperatureC"] as Double
            val f = NativeSettings.get(ctx).fahrenheit
            val tempText = if (f) "%.1f°F".format(temp * 9 / 5 + 32) else "%.1f°C".format(temp)
            val title = if (charger != "none") "⚡ Charging %.2f%% · %.1f W".format(pct, watts)
            else "%.2f%% · %.1f W draw".format(pct, watts)
            val mode = when (charger) { "ac" -> "AC"; "usb" -> "USB"; "wireless" -> "Wireless"; "dock" -> "Dock"; else -> "On battery" }
            return b.setContentTitle(title)
                .setContentText("$mode · $tempText · ${s["voltageMv"]} mV")
                .setProgress(100, level, false)
                .build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        BatteryMonitor.ensureStarted(this)
        val n = build(this, BatteryMonitor.last)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
        running = true
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        BatteryMonitor.store?.flushPoints()
        super.onDestroy()
    }
}
