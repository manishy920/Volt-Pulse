package com.voltpulse.voltpulse

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import kotlin.math.max

/**
 * Persists battery history natively so it keeps recording while the Flutter UI is closed
 * (as long as the process is alive — the foreground service keeps it alive).
 *
 *  - points.json    : sampled % / temperature / current, last 7 days
 *  - sessions.json  : finished charging sessions
 *  - capacity.json  : one full-capacity estimate per day (wear tracker)
 */
class HistoryStore(private val ctx: Context) {
    private val prefs = ctx.getSharedPreferences("voltpulse_store", Context.MODE_PRIVATE)
    private val pointsFile = File(ctx.filesDir, "points.json")
    private val sessionsFile = File(ctx.filesDir, "sessions.json")
    private val capacityFile = File(ctx.filesDir, "capacity.json")

    private val points: JSONArray = load(pointsFile)
    private val sessions: JSONArray = load(sessionsFile)
    private val capacity: JSONArray = load(capacityFile)

    private var lastPointAt = 0L
    private var lastPointLevel = -1.0
    private var unsavedPoints = 0
    private var lastLevelSeen = -1

    // Active charging session (persisted so it survives a process restart)
    private var active: JSONObject? = prefs.getString("active_session", null)?.let {
        try { JSONObject(it) } catch (_: Exception) { null }
    }
    private var lastSessionTick = 0L

    // ---------- full capacity estimate (for decimal %) ----------

    fun fullCapacityEstimate(level: Int, counterMah: Double?): Double? {
        var est = prefs.getFloat("full_est", 0f).toDouble()
        var count = prefs.getInt("full_est_count", 0)
        if (counterMah != null && level != lastLevelSeen && level in 15..95) {
            // At the moment Android steps to a new integer level the true fraction is closest to it.
            val sample = counterMah * 100.0 / level
            val alpha = 1.0 / minOf(count + 1, 20)
            est = if (count == 0) sample else est + alpha * (sample - est)
            count++
            prefs.edit().putFloat("full_est", est.toFloat()).putInt("full_est_count", count).apply()
        }
        lastLevelSeen = level
        return if (count > 0 && est > 0) est else null
    }

    private fun capacityConfidence(): Int = prefs.getInt("full_est_count", 0)

    // ---------- snapshot ingestion ----------

    /** Returns a finished session map if this snapshot ended one. */
    fun onSnapshot(s: Map<String, Any?>): Map<String, Any?>? {
        val now = s["timestamp"] as Long
        val percent = s["percent"] as Double
        val charger = s["charger"] as String
        val plugged = charger != "none"
        val current = s["currentMa"] as Double
        val temp = s["temperatureC"] as Double
        val watts = (s["voltageMv"] as Int) / 1000.0 * kotlin.math.abs(current) / 1000.0

        recordPoint(now, percent, temp, current, plugged && current > 0, s["screenOn"] as Boolean)
        recordCapacity(now, s["fullCapacityMah"] as Double?)

        var finished: Map<String, Any?>? = null
        if (plugged) {
            val a = active ?: JSONObject().apply {
                put("id", now.toString())
                put("start", now)
                put("startLevel", percent)
                put("charger", charger)
                put("energyWs", 0.0)
                put("seconds", 0.0)
                put("peakW", 0.0)
                put("maxTemp", temp)
                put("alarmLevelFired", false)
                put("alarmFullFired", false)
                lastSessionTick = now
            }.also { active = it }
            val dt = if (lastSessionTick == 0L) 0.0 else (now - lastSessionTick) / 1000.0
            lastSessionTick = now
            if (dt in 0.0..60.0 && current > 0) {
                a.put("energyWs", a.getDouble("energyWs") + watts * dt)
                a.put("seconds", a.getDouble("seconds") + dt)
            }
            if (current > 0) a.put("peakW", max(a.getDouble("peakW"), watts))
            a.put("maxTemp", max(a.getDouble("maxTemp"), temp))
            a.put("lastLevel", percent)
            if (a.optString("charger") == "none") a.put("charger", charger)
            persistActive()
        } else {
            active?.let { a ->
                val start = a.getLong("start")
                if (now - start >= 60_000) {
                    val sess = JSONObject().apply {
                        put("id", a.getString("id"))
                        put("start", start)
                        put("end", now)
                        put("startLevel", a.getDouble("startLevel"))
                        put("endLevel", a.optDouble("lastLevel", percent))
                        put("avgW", avgW(a))
                        put("peakW", a.getDouble("peakW"))
                        put("maxTemp", a.getDouble("maxTemp"))
                        put("charger", a.optString("charger", "usb"))
                        put("label", JSONObject.NULL)
                    }
                    sessions.put(sess)
                    while (sessions.length() > 300) sessions.remove(0)
                    save(sessionsFile, sessions)
                    finished = jsonToMap(sess)
                }
                active = null
                lastSessionTick = 0L
                persistActive()
                flushPoints()
            }
        }
        return finished
    }

    private fun avgW(a: JSONObject): Double {
        val secs = a.getDouble("seconds")
        return if (secs > 0) a.getDouble("energyWs") / secs else 0.0
    }

    fun activeSessionMap(): Map<String, Any?>? = active?.let {
        mapOf(
            "id" to it.getString("id"),
            "start" to it.getLong("start"),
            "startLevel" to it.getDouble("startLevel"),
            "avgW" to avgW(it),
            "peakW" to it.getDouble("peakW"),
            "maxTemp" to it.getDouble("maxTemp"),
            "charger" to it.optString("charger"),
        )
    }

    fun activeFlag(key: String): Boolean = active?.optBoolean(key, false) ?: false
    fun setActiveFlag(key: String, value: Boolean) {
        active?.put(key, value); persistActive()
    }

    private fun persistActive() {
        prefs.edit().putString("active_session", active?.toString()).apply()
    }

    private fun recordPoint(now: Long, percent: Double, temp: Double, current: Double, charging: Boolean, screen: Boolean) {
        val levelChanged = kotlin.math.abs(percent - lastPointLevel) >= 1.0
        if (now - lastPointAt < 120_000 && !(levelChanged && now - lastPointAt > 20_000)) return
        lastPointAt = now
        lastPointLevel = percent
        points.put(JSONArray().apply {
            put(now); put(Math.round(percent * 100) / 100.0); put(temp)
            put(Math.round(current).toInt()); put(if (charging) 1 else 0); put(if (screen) 1 else 0)
        })
        val cutoff = now - 7L * 24 * 3600 * 1000
        while (points.length() > 0 && (points.getJSONArray(0).getLong(0) < cutoff || points.length() > 6000)) points.remove(0)
        if (++unsavedPoints >= 5) flushPoints()
    }

    fun flushPoints() {
        if (unsavedPoints == 0) return
        unsavedPoints = 0
        save(pointsFile, points)
    }

    private fun recordCapacity(now: Long, fullMah: Double?) {
        if (fullMah == null || capacityConfidence() < 8) return
        val last = if (capacity.length() > 0) capacity.getJSONObject(capacity.length() - 1).getLong("t") else 0L
        if (now - last < 24L * 3600 * 1000) return
        capacity.put(JSONObject().put("t", now).put("mah", fullMah))
        while (capacity.length() > 400) capacity.remove(0)
        save(capacityFile, capacity)
    }

    // ---------- reads for Flutter ----------

    fun pointsList(): List<Map<String, Any?>> = (0 until points.length()).map {
        val p = points.getJSONArray(it)
        mapOf(
            "t" to p.getLong(0), "level" to p.getDouble(1), "temp" to p.getDouble(2),
            "currentMa" to p.getInt(3), "charging" to (p.getInt(4) == 1), "screenOn" to (p.getInt(5) == 1),
        )
    }

    fun sessionsList(): List<Map<String, Any?>> = (0 until sessions.length()).map { jsonToMap(sessions.getJSONObject(it)) }

    fun capacityList(): List<Map<String, Any?>> = (0 until capacity.length()).map {
        val c = capacity.getJSONObject(it); mapOf("t" to c.getLong("t"), "mah" to c.getDouble("mah"))
    }

    fun labelSession(id: String, label: String?) {
        for (i in 0 until sessions.length()) {
            val s = sessions.getJSONObject(i)
            if (s.getString("id") == id) s.put("label", if (label.isNullOrBlank()) JSONObject.NULL else label)
        }
        save(sessionsFile, sessions)
    }

    fun clear() {
        while (points.length() > 0) points.remove(0)
        while (sessions.length() > 0) sessions.remove(0)
        while (capacity.length() > 0) capacity.remove(0)
        save(pointsFile, points); save(sessionsFile, sessions); save(capacityFile, capacity)
    }

    private fun jsonToMap(o: JSONObject): Map<String, Any?> = mapOf(
        "id" to o.getString("id"), "start" to o.getLong("start"), "end" to o.getLong("end"),
        "startLevel" to o.getDouble("startLevel"), "endLevel" to o.getDouble("endLevel"),
        "avgW" to o.getDouble("avgW"), "peakW" to o.getDouble("peakW"), "maxTemp" to o.getDouble("maxTemp"),
        "charger" to o.optString("charger"), "label" to (if (o.isNull("label")) null else o.getString("label")),
    )

    private fun load(f: File): JSONArray = try {
        if (f.exists()) JSONArray(f.readText()) else JSONArray()
    } catch (_: Exception) { JSONArray() }

    private fun save(f: File, a: JSONArray) {
        try {
            val tmp = File(f.parentFile, f.name + ".tmp")
            tmp.writeText(a.toString())
            tmp.renameTo(f)
        } catch (_: Exception) {
        }
    }
}
