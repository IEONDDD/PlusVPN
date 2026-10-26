package com.plusvpn.plus_vpn

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private var fileResult: MethodChannel.Result? = null
    private val executor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.plusvpn/control")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "snapshot" -> result.success(VpnBridge.snapshot())
                        "saveProfile" -> {
                            VpnBridge.save(this, call.arguments as Map<*, *>)
                            result.success(null)
                        }
                        "prepare" -> prepare(result)
                        "start" -> { VpnBridge.start(this); result.success(null) }
                        "stop" -> { VpnBridge.stop(this); result.success(null) }
                        "pickConfigFile" -> {
                            if (fileResult != null) {
                                result.error("BUSY", "Выбор файла уже открыт", null)
                            } else {
                                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "*/*"
                                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                                }
                                fileResult = result
                                try {
                                    @Suppress("DEPRECATION")
                                    startActivityForResult(intent, 703)
                                } catch (e: Exception) {
                                    fileResult = null
                                    result.error("PICKER", "Не удалось открыть выбор файла", null)
                                }
                            }
                        }
                        "installedApps" -> executor.execute {
                            try {
                                val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                                @Suppress("DEPRECATION")
                                val apps = packageManager.queryIntentActivities(intent, 0)
                                    .filter { it.activityInfo.packageName != packageName }
                                    .map { mapOf("package" to it.activityInfo.packageName,
                                        "label" to it.loadLabel(packageManager).toString()) }
                                    .distinctBy { it["package"] }.sortedBy { it["label"]?.lowercase() }
                                runOnUiThread { result.success(apps) }
                            } catch (e: Exception) { runOnUiThread { result.error("APPS", e.message, null) } }
                        }
                        "openUrl" -> {
                            val url = call.argument<String>("url") ?: ""
                            try {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("OPEN_URL", e.message, null)
                            }
                        }
                        "isIgnoringBatteryOptimizations" -> {
                            val pm = getSystemService(POWER_SERVICE) as? PowerManager
                            val isIgnoring = pm?.isIgnoringBatteryOptimizations(packageName) ?: true
                            result.success(isIgnoring)
                        }
                        "requestIgnoreBatteryOptimizations" -> {
                            try {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                try {
                                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(intent)
                                    result.success(true)
                                } catch (_: Exception) {
                                    result.error("BATTERY", e.message, null)
                                }
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) { result.error("VPN", e.message, null) }
            }
    }

    private fun prepare(result: MethodChannel.Result) {
        if (permissionResult != null) { result.error("BUSY", "Запрос разрешения уже открыт", null); return }
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 702)
            permissionResult = result
            return
        }
        prepareVpn(result)
    }
    private fun prepareVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent == null) result.success(true)
        else {
            permissionResult = result
            @Suppress("DEPRECATION")
            startActivityForResult(intent, 701)
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 702) {
            val result = permissionResult ?: return
            permissionResult = null
            // Notification denial does not prevent Android from granting VPN permission.
            prepareVpn(result)
        }
    }
    @Deprecated("Android activity result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 701) {
            permissionResult?.success(resultCode == RESULT_OK)
            permissionResult = null
        }
        if (requestCode == 703) {
            val result = fileResult ?: return
            fileResult = null
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) {
                result.success(null)
                return
            }
            executor.execute {
                try {
                    val bytes = ByteArrayOutputStream()
                    contentResolver.openInputStream(uri).use { input ->
                        checkNotNull(input) { "Не удалось прочитать файл" }
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            check(bytes.size() + count <= 4 * 1024 * 1024) { "Файл больше 4 МБ" }
                            bytes.write(buffer, 0, count)
                        }
                    }
                    val text = bytes.toByteArray().toString(Charsets.UTF_8)
                    runOnUiThread { result.success(text) }
                } catch (e: Exception) {
                    runOnUiThread { result.error("FILE", "Не удалось прочитать JSON-файл (максимум 4 МБ)", null) }
                }
            }
        }
    }
    override fun onDestroy() {
        permissionResult?.error("DETACHED", "Окно разрешения закрыто", null)
        permissionResult = null
        fileResult?.error("DETACHED", "Выбор файла закрыт", null)
        fileResult = null
        executor.shutdown()
        super.onDestroy()
    }
}
