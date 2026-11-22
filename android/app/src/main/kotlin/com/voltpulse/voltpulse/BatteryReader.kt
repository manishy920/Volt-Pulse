package com.voltpulse.voltpulse

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import java.io.File
import kotlin.math.abs

/**
 * Reads raw battery data from BatteryManager, the sticky ACTION_BATTERY_CHANGED intent
 * and (where readable) sysfs, and normalizes vendor quirks:
 *  - current_now may be in µA or mA, and its sign differs between vendors
 *  - charge_counter may be in µAh or mAh
 *  - voltage may be in V, mV or µV
 */
object BatteryReader {
    private var designCapacity: Double? = null
    private var designResolved = false
    private val sysfsDirs = listOf("/sys/class/power_supply/battery", "/sys/class/power_supply/bms")

    fun stickyIntent(ctx: Context): Intent? {
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        return if (Build.VERSION.SDK_INT >= 33) {
            ctx.registerReceiver(null, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            ctx.registerReceiver(null, filter)
        }
    }

    fun read(ctx: Context, cached: Intent?, store: HistoryStore?): MutableMap<String, Any?> {
        val bm = ctx.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val i = cached ?: stickyIntent(ctx)

        val rawLevel = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = i?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val level = if (rawLevel >= 0 && scale > 0) rawLevel * 100 / scale
        else bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).coerceIn(0, 100)

        val plugged = i?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val charger = when {
            plugged and BatteryManager.BATTERY_PLUGGED_AC != 0 -> "ac"
            plugged and BatteryManager.BATTERY_PLUGGED_USB != 0 -> "usb"
            plugged and BatteryManager.BATTERY_PLUGGED_WIRELESS != 0 -> "wireless"
            Build.VERSION.SDK_INT >= 33 && plugged and BatteryManager.BATTERY_PLUGGED_DOCK != 0 -> "dock"
            else -> "none"
        }

        val statusCode = i?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val status = when (statusCode) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
            BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
            BatteryManager.BATTERY_STATUS_FULL -> "full"
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "not_charging"
            else -> if (charger != "none") "charging" else "discharging"
        }

        val voltageMv = normalizeVoltage(i?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0) ?: 0)
        val temperatureC = (i?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0) / 10.0
        val technology = i?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY)?.takeIf { it.isNotBlank() } ?: "Unknown"
        val health = when (i?.getIntExtra(BatteryManager.EXTRA_HEALTH, 1)) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "overheat"
            BatteryManager.BATTERY_HEALTH_DEAD -> "dead"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "over_voltage"
            BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "failure"
            BatteryManager.BATTERY_HEALTH_COLD -> "cold"
            else -> "unknown"
        }

        // Current: positive = flowing into the battery.
        val rawCurrent = bm.getLongProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        var currentMa = 0.0
        if (rawCurrent != Long.MIN_VALUE && rawCurrent != 0L) {
            val magnitude = if (abs(rawCurrent) > 15_000) abs(rawCurrent) / 1000.0 else abs(rawCurrent).toDouble()
            val charging = charger != "none" && status != "discharging"
            currentMa = if (charging) magnitude else -magnitude
            // Plugged in but the phone draws more than the charger supplies.
            if (charging && status == "not_charging") currentMa = -magnitude
        }

        // Remaining charge in mAh.
        val rawCounter = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        val counterMah: Double? = when {
            rawCounter == Int.MIN_VALUE || rawCounter <= 0 -> null
            rawCounter > 100_000 -> rawCounter / 1000.0
            else -> rawCounter.toDouble()
        }

        val sysFull = readSysLong("charge_full")?.let { if (it > 100_000) it / 1000.0 else it.toDouble() }
        val fullCapacity = sysFull ?: store?.fullCapacityEstimate(level, counterMah)
        val design = designCapacity(ctx)

        val percent: Double = if (counterMah != null && fullCapacity != null && fullCapacity > 0) {
            (counterMah / fullCapacity * 100.0).coerceIn((level - 0.99).coerceAtLeast(0.0), (level + 0.99).coerceAtMost(100.0))
        } else level.toDouble()

        val cycles: Int? = (if (Build.VERSION.SDK_INT >= 34)
            i?.getIntExtra(BatteryManager.EXTRA_CYCLE_COUNT, -1)?.takeIf { it >= 0 } else null)
            ?: readSysLong("cycle_count")?.toInt()

        val chargeTimeMs: Long? = if (Build.VERSION.SDK_INT >= 28) {
            bm.computeChargeTimeRemaining().takeIf { it > 0 }
        } else null

        val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager

        return mutableMapOf(
            "level" to level,
            "percent" to percent,
            "status" to status,
            "charger" to charger,
            "voltageMv" to voltageMv,
            "currentMa" to currentMa,
            "temperatureC" to temperatureC,
            "technology" to technology,
            "health" to health,
            "chargeCounterMah" to counterMah,
            "fullCapacityMah" to fullCapacity,
            "designCapacityMah" to design,
            "cycleCount" to cycles,
            "chargeTimeRemainingMs" to chargeTimeMs,
            "screenOn" to pm.isInteractive,
            "timestamp" to System.currentTimeMillis(),
        )
    }

    private fun normalizeVoltage(v: Int): Int = when {
        v in 1..20 -> v * 1000            // reported in volts
        v > 100_000 -> v / 1000           // reported in µV
        else -> v
    }

    private fun readSysLong(name: String): Long? {
        for (dir in sysfsDirs) {
            try {
                val f = File(dir, name)
                if (f.canRead()) return f.readText().trim().toLongOrNull()?.takeIf { it > 0 }
            } catch (_: Exception) {
            }
        }
        return null
    }

    @Suppress("PrivateApi")
    fun designCapacity(ctx: Context): Double? {
        if (designResolved) return designCapacity
        designResolved = true
        designCapacity = try {
            val cls = Class.forName("com.android.internal.os.PowerProfile")
            val profile = cls.getConstructor(Context::class.java).newInstance(ctx)
            (cls.getMethod("getBatteryCapacity").invoke(profile) as Double).takeIf { it > 500 }
        } catch (_: Throwable) {
            null
        } ?: readSysLong("charge_full_design")?.let { if (it > 100_000) it / 1000.0 else it.toDouble() }
        return designCapacity
    }
}
