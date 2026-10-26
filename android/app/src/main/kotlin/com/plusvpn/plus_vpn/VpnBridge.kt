package com.plusvpn.plus_vpn

import android.app.Application
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.service.quicksettings.TileService
import dev.amirzr.flutter_v2ray_client.v2ray.V2rayController
import dev.amirzr.flutter_v2ray_client.v2ray.core.V2rayCoreManager
import dev.amirzr.flutter_v2ray_client.v2ray.utils.AppConfigs
import dev.amirzr.flutter_v2ray_client.v2ray.utils.Utilities
import org.json.JSONArray
import org.json.JSONObject

class PlusVpnApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        VpnBridge.initialize(this)
    }
}

/** One process owns Flutter, TileService and Xray. Never infer live state from a saved boolean. */
object VpnBridge {
    private val handler = Handler(Looper.getMainLooper())
    private var initialized = false
    private var starting = false
    private var stopping = false
    private var startedAt = 0L
    private var generation = 0
    private var lastState = "DISCONNECTED"
    private var uploadSpeed = 0L
    private var downloadSpeed = 0L
    private var error = ""
    private fun prefs(c: Context) = c.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun initialize(context: Context) {
        if (initialized) return
        initialized = true
        V2rayController.init(context, R.drawable.ic_vpn, "PlusVPN")
        AppConfigs.NOTIFICATION_DISCONNECT_BUTTON_NAME = "Отключить"
        AppConfigs.ENABLE_TRAFFIC_AND_SPEED_STATICS = true
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                uploadSpeed = intent.getLongExtra("UPLOAD_SPEED", 0)
                downloadSpeed = intent.getLongExtra("DOWNLOAD_SPEED", 0)
                val state = liveState()
                if (state == "CONNECTED" && startedAt == 0L) startedAt = SystemClock.elapsedRealtime()
                if (state == "DISCONNECTED") startedAt = 0
                if (state != lastState) {
                    lastState = state
                    prefs(c).edit().putBoolean("flutter.vpn_connected", state == "CONNECTED").apply()
                    refreshTile(c)
                }
            }
        }
        val filter = IntentFilter(context.packageName + ".V2RAY_CONNECTION_INFO")
        if (Build.VERSION.SDK_INT >= 33) context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        else @Suppress("DEPRECATION") context.registerReceiver(receiver, filter)
    }

    fun label(c: Context): String = prefs(c).getString("flutter.selected_server_label", "PlusVPN") ?: "PlusVPN"

    fun save(c: Context, args: Map<*, *>) {
        val config = args["config"] as? String ?: ""
        if (config.isNotEmpty()) JSONObject(config)
        val packages = args["excludedApps"] as? List<*> ?: emptyList<String>()
        val included = args["includedApps"] as? List<*> ?: emptyList<String>()
        check(prefs(c).edit()
            .putString("flutter.last_vpn_config", config)
            .putString("flutter.selected_server_id", args["id"] as? String)
            .putString("flutter.selected_server_label", args["label"] as? String ?: "PlusVPN")
            .putString("flutter.excluded_apps_json", JSONArray(packages).toString())
            .putBoolean("flutter.include_only", args["includeOnly"] == true)
            .putString("flutter.included_apps_json", JSONArray(included).toString()).commit()) { "Не удалось сохранить профиль" }
        refreshTile(c)
    }

    fun liveState(): String {
        val running = V2rayCoreManager.getInstance().isV2rayCoreRunning
        return when {
            stopping && running -> "DISCONNECTING"
            running -> { starting = false; stopping = false; "CONNECTED" }
            starting -> "CONNECTING"
            else -> { stopping = false; "DISCONNECTED" }
        }
    }

    fun snapshot(): Map<String, Any> {
        val state = liveState()
        if (state == "CONNECTED" && startedAt == 0L) startedAt = SystemClock.elapsedRealtime()
        if (state == "DISCONNECTED") startedAt = 0
        val seconds = if (startedAt == 0L) 0L else (SystemClock.elapsedRealtime() - startedAt) / 1000
        val duration = "%02d:%02d:%02d".format(seconds / 3600, seconds / 60 % 60, seconds % 60)
        val failure = error
        error = ""
        return mapOf("state" to state, "duration" to duration, "uploadSpeed" to uploadSpeed,
            "downloadSpeed" to downloadSpeed, "error" to failure)
    }

    fun start(c: Context) {
        check(VpnService.prepare(c) == null) { "Требуется разрешение Android на VPN" }
        if (liveState() != "DISCONNECTED") return
        val p = prefs(c)
        val config = p.getString("flutter.last_vpn_config", "") ?: ""
        check(config.isNotBlank()) { "Сначала добавьте и выберите сервер в приложении" }
        val excluded = JSONArray(p.getString("flutter.excluded_apps_json", "[]"))
        val packages = ArrayList<String>()
        for (i in 0 until excluded.length()) packages.add(excluded.getString(i))
        val includeOnly = p.getBoolean("flutter.include_only", false)
        val selected = if (includeOnly) {
            val included = JSONArray(p.getString("flutter.included_apps_json", "[]"))
            ArrayList<String>().apply { for (i in 0 until included.length()) add(included.getString(i)) }
        } else packages
        check(!includeOnly || selected.any { it.isNotBlank() && it != c.packageName }) { "Выберите хотя бы одно приложение для VPN" }
        starting = true
        val token = ++generation
        try {
            AppConfigs.V2RAY_CONNECTION_MODE = AppConfigs.V2RAY_CONNECTION_MODES.VPN_TUN
            AppConfigs.V2RAY_CONFIG = checkNotNull(Utilities.parseV2rayJsonFile(label(c), config, packages, null)) { "Ядро отклонило конфигурацию" }
            val intent = Intent(c, PlusVpnService::class.java).setAction(PlusVpnService.ACTION_START)
                .putExtra("INCLUDE_ONLY", includeOnly).putStringArrayListExtra("SELECTED_APPS", selected)
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(intent) else c.startService(intent)
        } catch (e: Exception) {
            starting = false
            throw e
        }
        refreshTile(c)
        handler.postDelayed({
            if (token == generation && starting) {
                starting = false
                if (!V2rayCoreManager.getInstance().isV2rayCoreRunning) {
                    error = "Не удалось запустить Xray. Проверьте ключ и параметры сервера."
                    c.stopService(Intent(c, PlusVpnService::class.java))
                }
                refreshTile(c)
            }
        }, 15000)
    }

    fun stop(c: Context) {
        ++generation
        starting = false
        stopping = V2rayCoreManager.getInstance().isV2rayCoreRunning
        if (!c.stopService(Intent(c, PlusVpnService::class.java))) onServiceStopped(c)
        uploadSpeed = 0; downloadSpeed = 0
        refreshTile(c)
    }

    fun reportFailure(c: Context, message: String) {
        error = message
        starting = false
        refreshTile(c)
    }

    fun onServiceStopped(c: Context) {
        ++generation
        starting = false; stopping = false; startedAt = 0
        uploadSpeed = 0; downloadSpeed = 0
        AppConfigs.V2RAY_STATE = AppConfigs.V2RAY_STATES.V2RAY_DISCONNECTED
        prefs(c).edit().putBoolean("flutter.vpn_connected", false).apply()
        refreshTile(c)
    }

    fun refreshTile(c: Context) {
        TileService.requestListeningState(c, ComponentName(c, VpnTileService::class.java))
    }
}
