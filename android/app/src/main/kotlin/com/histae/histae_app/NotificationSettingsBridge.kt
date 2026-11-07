package com.histae.histae_app

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.net.Uri
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Stable channel IDs also belong to the server's NotificationType contract. */
class NotificationSettingsBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "histae/notifications")

    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = activity.getSystemService(NotificationManager::class.java)
            val names = mapOf(
                "histae_messages" to R.string.notification_messages,
                "histae_matches" to R.string.notification_matches,
                "histae_continuations" to R.string.notification_continuations,
                "histae_photos" to R.string.notification_photos,
                "histae_reminders" to R.string.notification_reminders,
                "histae_account" to R.string.notification_account,
            )
            for ((id, name) in names) {
                val category = NotificationChannel(id, activity.getString(name), NotificationManager.IMPORTANCE_DEFAULT)
                category.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                // Re-creation updates names without overriding the user's sound/importance choices.
                manager.createNotificationChannel(category)
            }
        }
        channel.setMethodCallHandler { call, result ->
            if (call.method != "openNotificationSettings") {
                result.notImplemented()
            } else {
                try {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:${activity.packageName}"))
                    }
                    activity.startActivity(intent)
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }
        }
    }

    fun dispose() { channel.setMethodCallHandler(null) }
}
