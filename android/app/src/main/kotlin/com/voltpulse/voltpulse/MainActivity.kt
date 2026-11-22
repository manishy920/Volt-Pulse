package com.voltpulse.voltpulse

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHODS = "voltpulse/methods"
        private const val BATTERY_STREAM = "voltpulse/battery"
        private const val POWER_STREAM = "voltpulse/power"
        private const val REQ_NOTIFICATIONS = 4242
    }

    private var batterySink: EventChannel.EventSink? = null
    private var powerSink: EventChannel.EventSink? = null
    private var pendingPermission: MethodChannel.Result? = null
    private val batteryListener: Listener = { batterySink?.success(it) }
    private val powerListener: Listener = { powerSink?.success(it) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BatteryMonitor.ensureStarted(this)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, METHODS).setMethodCallHandler { call, result ->
            try {
                handle(call, result)
            } catch (e: Exception) {
                result.error("NATIVE_ERROR", e.message, null)
            }
        }

        EventChannel(messenger, BATTERY_STREAM).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                batterySink = events
                BatteryMonitor.snapshotNow()?.let { events.success(it) }
                BatteryMonitor.addSnapshotListener(batteryListener)
            }

            override fun onCancel(arguments: Any?) {
                BatteryMonitor.removeSnapshotListener(batteryListener)
                batterySink = null
            }
        })

        EventChannel(messenger, POWER_STREAM).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                powerSink = events
                BatteryMonitor.addPowerListener(powerListener)
            }

            override fun onCancel(arguments: Any?) {
                BatteryMonitor.removePowerListener(powerListener)
                powerSink = null
            }
        })
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val store = BatteryMonitor.store
        when (call.method) {
            "getSnapshot" -> result.success(BatteryMonitor.snapshotNow())
            "getHistory" -> result.success(store?.pointsList() ?: emptyList<Any>())
            "getSessions" -> result.success(store?.sessionsList() ?: emptyList<Any>())
            "getCapacitySamples" -> result.success(store?.capacityList() ?: emptyList<Any>())
            "labelSession" -> {
                store?.labelSession(call.argument<String>("id")!!, call.argument<String>("label"))
                result.success(null)
            }
            "clearHistory" -> { store?.clear(); result.success(null) }
            "updateSettings" -> {
                val s = NativeSettings.save(this, call.arguments as Map<*, *>)
                if (s.liveNotification) BatteryMonitorService.start(this) else BatteryMonitorService.stop(this)
                result.success(null)
            }
            "requestNotificationPermission" -> {
                if (Build.VERSION.SDK_INT >= 33 &&
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                ) {
                    pendingPermission = result
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFICATIONS)
                } else result.success(true)
            }
            "playFeedback" -> {
                AlertManager.playPlugFeedback(this, call.argument<Boolean>("connected") ?: true)
                result.success(null)
            }
            "stopAlarm" -> { AlertManager.stopAlarm(); result.success(null) }
            "setKeepScreenOn" -> {
                val on = call.argument<Boolean>("on") ?: false
                val brightness = call.argument<Double>("brightness")
                runOnUiThread {
                    if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    window.attributes = window.attributes.apply {
                        screenBrightness = if (on && brightness != null) brightness.toFloat()
                        else WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                    }
                }
                result.success(null)
            }
            "getDeviceInfo" -> result.success(DeviceInfoReader.read(this))
            "saveCsv" -> result.success(
                MediaExporter.saveCsv(
                    this, call.argument<String>("fileName")!!, call.argument<String>("content")!!,
                    call.argument<Boolean>("share") ?: false
                )
            )
            "shareImage" -> {
                MediaExporter.shareImage(this, call.argument<ByteArray>("png")!!, call.argument<String>("fileName")!!)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_NOTIFICATIONS) {
            pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            pendingPermission = null
        }
    }

    override fun onDestroy() {
        BatteryMonitor.removeSnapshotListener(batteryListener)
        BatteryMonitor.removePowerListener(powerListener)
        super.onDestroy()
    }
}
