package com.voltpulse.voltpulse

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/** Charge-level, full-charge and overheat alarms plus plug-in sound/haptics. */
object AlertManager {
    const val CHANNEL_LIVE = "voltpulse_live"
    const val CHANNEL_ALERTS = "voltpulse_alerts"
    private const val ID_LEVEL = 2001
    private const val ID_FULL = 2002
    private const val ID_HEAT = 2003

    private val handler = Handler(Looper.getMainLooper())
    private var ringtone: Ringtone? = null
    private var lastHeatAlertAt = 0L
    private var heatArmed = true

    fun createChannels(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_LIVE, "Live battery status", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Persistent notification with battery % and watts"
                setShowBadge(false)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ALERTS, "Battery alarms", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Charge level, full charge and overheat alarms"
                enableVibration(true)
            }
        )
    }

    fun evaluate(ctx: Context, s: Map<String, Any?>, store: HistoryStore) {
        val cfg = NativeSettings.get(ctx)
        val plugged = s["charger"] != "none"
        val percent = s["percent"] as Double
        val level = s["level"] as Int
        val temp = s["temperatureC"] as Double

        if (plugged) {
            if (cfg.chargeAlarmEnabled && cfg.chargeAlarmLevel < 100 && percent >= cfg.chargeAlarmLevel &&
                !store.activeFlag("alarmLevelFired")
            ) {
                store.setActiveFlag("alarmLevelFired", true)
                // Started charging above the target — don't nag.
                val startLevel = store.activeSessionMap()?.get("startLevel") as? Double ?: 0.0
                if (startLevel < cfg.chargeAlarmLevel) {
                    notifyAlert(ctx, ID_LEVEL, "Battery at ${cfg.chargeAlarmLevel}%",
                        "Unplug now to keep your battery healthy (20–80% is the sweet spot).")
                    if (cfg.soundEnabled) playAlarm(ctx, 8_000)
                    if (cfg.hapticsEnabled) vibrate(ctx, longArrayOf(0, 400, 200, 400))
                }
            }
            val full = s["status"] == "full" || level >= 100
            if (cfg.fullAlarmEnabled && full && !store.activeFlag("alarmFullFired")) {
                store.setActiveFlag("alarmFullFired", true)
                notifyAlert(ctx, ID_FULL, "Your phone is 100%", "Unplug now to reduce battery wear.")
                if (cfg.soundEnabled) playAlarm(ctx, 15_000)
                if (cfg.hapticsEnabled) vibrate(ctx, longArrayOf(0, 600, 300, 600, 300, 600))
            }
        }

        if (cfg.overheatEnabled) {
            val now = System.currentTimeMillis()
            if (temp >= cfg.overheatThresholdC && heatArmed && now - lastHeatAlertAt > 10 * 60_000) {
                heatArmed = false
                lastHeatAlertAt = now
                val shown = if (cfg.fahrenheit) "%.1f°F".format(temp * 9 / 5 + 32) else "%.1f°C".format(temp)
                val tip = if (plugged) "Stop charging and remove the case to let it cool down."
                else "Close heavy apps and remove the case to let it cool down."
                notifyAlert(ctx, ID_HEAT, "Battery is hot ($shown)", tip)
                if (cfg.hapticsEnabled) vibrate(ctx, longArrayOf(0, 250, 150, 250))
            } else if (temp < cfg.overheatThresholdC - 2) {
                heatArmed = true
            }
        }
    }

    private fun notifyAlert(ctx: Context, id: Int, title: String, text: String) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 33 && !nm.areNotificationsEnabled()) return
        val open = PendingIntent.getActivity(
            ctx, id, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stop = PendingIntent.getBroadcast(
            ctx, 0, Intent(ctx, AlarmActionReceiver::class.java).setAction(AlarmActionReceiver.ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n = Notification.Builder(ctx, CHANNEL_ALERTS)
            .setSmallIcon(R.drawable.ic_stat_bolt)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(open)
            .setDeleteIntent(stop)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .addAction(Notification.Action.Builder(null, "Stop alarm", stop).build())
            .build()
        nm.notify(id, n)
    }

    fun playAlarm(ctx: Context, durationMs: Long) {
        stopAlarm()
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION) ?: return
        ringtone = RingtoneManager.getRingtone(ctx, uri)?.apply {
            audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            play()
        }
        handler.postDelayed({ stopAlarm() }, durationMs)
    }

    fun stopAlarm() {
        handler.removeCallbacksAndMessages(null)
        ringtone?.stop()
        ringtone = null
    }

    fun playPlugFeedback(ctx: Context, connected: Boolean) {
        val cfg = NativeSettings.get(ctx)
        if (cfg.soundEnabled) {
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)?.let {
                RingtoneManager.getRingtone(ctx, it)?.play()
            }
        }
        if (cfg.hapticsEnabled) {
            vibrate(ctx, if (connected) longArrayOf(0, 60, 80, 120) else longArrayOf(0, 80))
        }
    }

    fun vibrate(ctx: Context, pattern: LongArray) {
        val v: Vibrator = if (Build.VERSION.SDK_INT >= 31) {
            ctx.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (v.hasVibrator()) v.vibrate(VibrationEffect.createWaveform(pattern, -1))
    }
}
