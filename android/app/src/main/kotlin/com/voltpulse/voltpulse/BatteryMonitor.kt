package com.voltpulse.voltpulse

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper

typealias Listener = (Map<String, Any?>) -> Unit

/**
 * Process-wide battery monitor. Listens to ACTION_BATTERY_CHANGED and
 * ACTION_POWER_CONNECTED / DISCONNECTED, polls BatteryManager for live current,
 * feeds the history store, alarms, live notification and home-screen widget,
 * and fans snapshots out to Flutter EventChannel listeners.
 */
object BatteryMonitor {
    private val handler = Handler(Looper.getMainLooper())
    private var ctx: Context? = null
    private var started = false
    private var lastIntent: Intent? = null
    private val snapshotListeners = linkedSetOf<Listener>()
    private val powerListeners = linkedSetOf<Listener>()
    private var lastWidgetAt = 0L
    private var lastWidgetLevel = -1
    private var lastWidgetCharger = ""

    var store: HistoryStore? = null
        private set
    var last: Map<String, Any?>? = null
        private set

    fun ensureStarted(context: Context) {
        if (started) return
        started = true
        val app = context.applicationContext
        ctx = app
        store = HistoryStore(app)
        AlertManager.createChannels(app)
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_BATTERY_CHANGED)
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
        }
        lastIntent = if (Build.VERSION.SDK_INT >= 33) {
            app.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            app.registerReceiver(receiver, filter)
        }
        update()
        handler.postDelayed(poll, pollInterval())
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_BATTERY_CHANGED -> {
                    lastIntent = intent
                    update()
                }
                Intent.ACTION_POWER_CONNECTED, Intent.ACTION_POWER_DISCONNECTED -> {
                    val connected = intent.action == Intent.ACTION_POWER_CONNECTED
                    // The sticky battery intent can lag the power broadcast; refresh it.
                    lastIntent = BatteryReader.stickyIntent(c) ?: lastIntent
                    val snap = update()
                    val event = mapOf(
                        "type" to if (connected) "connected" else "disconnected",
                        "charger" to (snap?.get("charger") ?: "none"),
                        "timestamp" to System.currentTimeMillis(),
                    )
                    powerListeners.toList().forEach { it(event) }
                    // Re-read shortly after: charger type and current settle after a second or two.
                    handler.postDelayed({ lastIntent = BatteryReader.stickyIntent(c) ?: lastIntent; update() }, 1500)
                }
            }
        }
    }

    private val poll = object : Runnable {
        override fun run() {
            update()
            handler.postDelayed(this, pollInterval())
        }
    }

    /** 1 s while the UI is listening, otherwise 20 s (service / widget only). */
    private fun pollInterval(): Long = if (snapshotListeners.isNotEmpty()) 1000L else 20_000L

    fun snapshotNow(): Map<String, Any?>? = update()

    private fun update(): Map<String, Any?>? {
        val c = ctx ?: return null
        val st = store ?: return null
        val snap = BatteryReader.read(c, lastIntent, st)
        st.onSnapshot(snap)
        snap["session"] = st.activeSessionMap()
        last = snap
        AlertManager.evaluate(c, snap, st)
        BatteryMonitorService.refresh(c, snap)
        maybeUpdateWidget(c, snap)
        snapshotListeners.toList().forEach { it(snap) }
        return snap
    }

    private fun maybeUpdateWidget(c: Context, s: Map<String, Any?>) {
        val now = System.currentTimeMillis()
        val level = s["level"] as Int
        val charger = s["charger"] as String
        if (level != lastWidgetLevel || charger != lastWidgetCharger || now - lastWidgetAt > 60_000) {
            lastWidgetAt = now
            lastWidgetLevel = level
            lastWidgetCharger = charger
            BatteryWidgetProvider.updateAll(c, s)
        }
    }

    fun addSnapshotListener(l: Listener) {
        snapshotListeners.add(l)
        // Switch to fast polling immediately.
        handler.removeCallbacks(poll)
        handler.post(poll)
    }

    fun removeSnapshotListener(l: Listener) {
        snapshotListeners.remove(l)
        store?.flushPoints()
    }

    fun addPowerListener(l: Listener) = powerListeners.add(l)
    fun removePowerListener(l: Listener) = powerListeners.remove(l)
}
