package com.voltpulse.voltpulse

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restarts the live-notification service after reboot / app update if the user enabled it. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (NativeSettings.get(context).liveNotification) BatteryMonitorService.start(context)
    }
}
