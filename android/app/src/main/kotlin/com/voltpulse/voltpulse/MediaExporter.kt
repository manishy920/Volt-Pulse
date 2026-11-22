package com.voltpulse.voltpulse

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/** Saves CSV exports to Downloads/VoltPulse and share-card PNGs to Pictures/VoltPulse, then opens the share sheet. */
object MediaExporter {
    fun saveCsv(activity: Activity, fileName: String, content: String, share: Boolean): String {
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "text/csv")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/VoltPulse")
            }
            val uri = activity.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create file")
            activity.contentResolver.openOutputStream(uri)?.use { it.write(content.toByteArray()) }
            if (share) shareStream(activity, uri, "text/csv")
            return "Downloads/VoltPulse/$fileName"
        }
        val dir = activity.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS) ?: activity.filesDir
        val f = File(dir, fileName).apply { writeText(content) }
        if (share) {
            val i = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, content)
            activity.startActivity(Intent.createChooser(i, "Share CSV"))
        }
        return f.absolutePath
    }

    fun shareImage(activity: Activity, png: ByteArray, fileName: String) {
        if (Build.VERSION.SDK_INT < 29) throw UnsupportedOperationException("Image sharing needs Android 10+")
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/VoltPulse")
        }
        val uri = activity.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Could not create image")
        activity.contentResolver.openOutputStream(uri)?.use { it.write(png) }
        shareStream(activity, uri, "image/png")
    }

    private fun shareStream(activity: Activity, uri: Uri, mime: String) {
        val i = Intent(Intent.ACTION_SEND).setType(mime)
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        activity.startActivity(Intent.createChooser(i, "Share"))
    }
}
