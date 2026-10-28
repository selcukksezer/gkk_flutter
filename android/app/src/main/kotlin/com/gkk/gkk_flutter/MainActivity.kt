package com.gkk.gkk_flutter

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gkk/device_performance"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getDeviceSpecs") {
                try {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    val memInfo = ActivityManager.MemoryInfo()
                    am?.getMemoryInfo(memInfo)
                    val totalRamMb = if (memInfo.totalMem > 0L) {
                        (memInfo.totalMem / (1024L * 1024L)).toInt()
                    } else {
                        0
                    }
                    val availRamMb = if (memInfo.availMem > 0L) {
                        (memInfo.availMem / (1024L * 1024L)).toInt()
                    } else {
                        0
                    }
                    val isLowRam = am?.isLowRamDevice ?: false
                    val cores = Runtime.getRuntime().availableProcessors()
                    val model = "${Build.MANUFACTURER} ${Build.MODEL}".trim()
                    result.success(
                        mapOf(
                            "totalRamMb" to totalRamMb,
                            "availRamMb" to availRamMb,
                            "isLowRamDevice" to isLowRam,
                            "cpuCores" to cores,
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "deviceModel" to model,
                            "hardware" to (Build.HARDWARE ?: "")
                        )
                    )
                } catch (_: Throwable) {
                    result.success(emptyMap<String, Any>())
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
