package com.voltpulse.voltpulse

import android.app.ActivityManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.SystemClock

object DeviceInfoReader {
    fun read(ctx: Context): Map<String, Any?> {
        val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mem = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        val stat = StatFs(Environment.getDataDirectory().path)
        val processor = if (Build.VERSION.SDK_INT >= 31 && Build.SOC_MODEL != Build.UNKNOWN) {
            "${Build.SOC_MANUFACTURER} ${Build.SOC_MODEL}"
        } else Build.HARDWARE
        return mapOf(
            "manufacturer" to Build.MANUFACTURER.replaceFirstChar { it.uppercase() },
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "processor" to processor,
            "cores" to Runtime.getRuntime().availableProcessors(),
            "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: ""),
            "totalRam" to mem.totalMem,
            "availRam" to mem.availMem,
            "totalStorage" to stat.totalBytes,
            "freeStorage" to stat.availableBytes,
            "uptimeMs" to SystemClock.elapsedRealtime(),
            "network" to network(ctx),
        )
    }

    private fun network(ctx: Context): String {
        val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return "Offline"
        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Mobile data"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "VPN"
            else -> "Connected"
        }
    }
}
