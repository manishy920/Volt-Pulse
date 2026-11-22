package com.voltpulse.voltpulse

import android.content.Context

/** Subset of the Flutter settings the native side needs (alarms, notification, sounds). */
data class NativeSettings(
    val chargeAlarmEnabled: Boolean = true,
    val chargeAlarmLevel: Int = 80,
    val fullAlarmEnabled: Boolean = true,
    val overheatEnabled: Boolean = true,
    val overheatThresholdC: Double = 40.0,
    val liveNotification: Boolean = false,
    val soundEnabled: Boolean = true,
    val hapticsEnabled: Boolean = true,
    val fahrenheit: Boolean = false,
) {
    companion object {
        private const val PREFS = "voltpulse_native_settings"
        @Volatile private var cached: NativeSettings? = null

        fun get(ctx: Context): NativeSettings {
            cached?.let { return it }
            val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return NativeSettings(
                chargeAlarmEnabled = p.getBoolean("chargeAlarmEnabled", true),
                chargeAlarmLevel = p.getInt("chargeAlarmLevel", 80),
                fullAlarmEnabled = p.getBoolean("fullAlarmEnabled", true),
                overheatEnabled = p.getBoolean("overheatEnabled", true),
                overheatThresholdC = p.getFloat("overheatThresholdC", 40f).toDouble(),
                liveNotification = p.getBoolean("liveNotification", false),
                soundEnabled = p.getBoolean("soundEnabled", true),
                hapticsEnabled = p.getBoolean("hapticsEnabled", true),
                fahrenheit = p.getBoolean("fahrenheit", false),
            ).also { cached = it }
        }

        fun save(ctx: Context, m: Map<*, *>): NativeSettings {
            val cur = get(ctx)
            val s = NativeSettings(
                chargeAlarmEnabled = m["chargeAlarmEnabled"] as? Boolean ?: cur.chargeAlarmEnabled,
                chargeAlarmLevel = (m["chargeAlarmLevel"] as? Number)?.toInt() ?: cur.chargeAlarmLevel,
                fullAlarmEnabled = m["fullAlarmEnabled"] as? Boolean ?: cur.fullAlarmEnabled,
                overheatEnabled = m["overheatEnabled"] as? Boolean ?: cur.overheatEnabled,
                overheatThresholdC = (m["overheatThresholdC"] as? Number)?.toDouble() ?: cur.overheatThresholdC,
                liveNotification = m["liveNotification"] as? Boolean ?: cur.liveNotification,
                soundEnabled = m["soundEnabled"] as? Boolean ?: cur.soundEnabled,
                hapticsEnabled = m["hapticsEnabled"] as? Boolean ?: cur.hapticsEnabled,
                fahrenheit = m["fahrenheit"] as? Boolean ?: cur.fahrenheit,
            )
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("chargeAlarmEnabled", s.chargeAlarmEnabled)
                .putInt("chargeAlarmLevel", s.chargeAlarmLevel)
                .putBoolean("fullAlarmEnabled", s.fullAlarmEnabled)
                .putBoolean("overheatEnabled", s.overheatEnabled)
                .putFloat("overheatThresholdC", s.overheatThresholdC.toFloat())
                .putBoolean("liveNotification", s.liveNotification)
                .putBoolean("soundEnabled", s.soundEnabled)
                .putBoolean("hapticsEnabled", s.hapticsEnabled)
                .putBoolean("fahrenheit", s.fahrenheit)
                .apply()
            cached = s
            return s
        }
    }
}
