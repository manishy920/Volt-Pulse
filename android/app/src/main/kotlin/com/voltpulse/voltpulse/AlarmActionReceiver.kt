package com.voltpulse.voltpulse

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmActionReceiver : BroadcastReceiver() {
    companion object { const val ACTION_STOP = "com.voltpulse.app.STOP_ALARM" }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_STOP) AlertManager.stopAlarm()
    }
}
