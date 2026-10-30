package com.histae.histae_app

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Play decides availability for this account, device and release track. */
class StoreUpdateBridge(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "histae/store-updates")
    private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "check") {
                result.notImplemented()
            } else if (!isPlayRelease()) {
                result.success(null)
            } else {
                AppUpdateManagerFactory.create(context).appUpdateInfo
                    .addOnSuccessListener { info ->
                        if (!closed) {
                            val available = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE ||
                                info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                            val installed = context.packageManager.getPackageInfo(context.packageName, 0)
                            @Suppress("DEPRECATION")
                            val current = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) installed.longVersionCode
                                else installed.versionCode.toLong()
                            result.success(mapOf(
                                "platform" to "android",
                                "package" to context.packageName,
                                "available" to (available && info.availableVersionCode().toLong() > current)
                            ))
                        }
                    }
                    .addOnFailureListener {
                        if (!closed) result.error("store_unavailable", "Store check unavailable", null)
                    }
            }
        }
    }

    private fun isPlayRelease(): Boolean {
        if ((context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0) return false
        return try {
            @Suppress("DEPRECATION")
            val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
                else context.packageManager.getInstallerPackageName(context.packageName)
            installer == "com.android.vending"
        } catch (_: Exception) {
            false
        }
    }

    fun dispose() {
        closed = true
        channel.setMethodCallHandler(null)
    }
}
