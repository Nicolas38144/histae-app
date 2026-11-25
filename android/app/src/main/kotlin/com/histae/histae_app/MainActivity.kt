package com.histae.histae_app

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.google.firebase.installations.FirebaseInstallations
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var storeUpdates: StoreUpdateBridge? = null
    private var notificationSettings: NotificationSettingsBridge? = null
    private var pushChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        storeUpdates = StoreUpdateBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        notificationSettings = NotificationSettingsBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        pushChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "histae/push")
        pushChannel?.setMethodCallHandler { call, result ->
            if (call.method == "deleteInstallation") {
                FirebaseInstallations.getInstance().delete().addOnCompleteListener { task ->
                    if (task.isSuccessful) {
                        result.success(null)
                    } else {
                        result.error("push_installation_unavailable", null, null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        storeUpdates?.dispose()
        storeUpdates = null
        notificationSettings?.dispose()
        notificationSettings = null
        pushChannel?.setMethodCallHandler(null)
        pushChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Set before Flutter can draw its first frame; never toggle on navigation.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
        super.onCreate(savedInstanceState)
    }
}
