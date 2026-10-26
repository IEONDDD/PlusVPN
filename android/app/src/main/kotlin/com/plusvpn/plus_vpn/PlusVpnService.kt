package com.plusvpn.plus_vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import dev.amirzr.flutter_v2ray_client.v2ray.core.V2rayCoreManager
import dev.amirzr.flutter_v2ray_client.v2ray.interfaces.V2rayServicesListener
import dev.amirzr.flutter_v2ray_client.v2ray.utils.AppConfigs
import dev.amirzr.flutter_v2ray_client.v2ray.utils.Utilities
import org.json.JSONObject

/** Xray owns the TUN FD; this service owns Android app routing and its lifecycle. */
class PlusVpnService : VpnService(), V2rayServicesListener {
    companion object {
        const val ACTION_START = "com.plusvpn.START"
        const val ACTION_STOP = "com.plusvpn.STOP"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL = "plusvpn.connection"
        private const val MTU = 1500
    }
    private var tun: ParcelFileDescriptor? = null
    private var stopping = false
    private var foreground = false
    private val core get() = V2rayCoreManager.getInstance()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_START) {
            stopTunnel()
            return START_NOT_STICKY
        }
        if (tun != null) return START_NOT_STICKY
        stopping = false
        try {
            showNotification("Подключение…")
            check(prepare(this) == null) { "Требуется разрешение Android на VPN" }
            val config = checkNotNull(AppConfigs.V2RAY_CONFIG) { "Не сохранена конфигурация VPN" }
            val includeOnly = intent.getBooleanExtra("INCLUDE_ONLY", false)
            val selected = intent.getStringArrayListExtra("SELECTED_APPS") ?: arrayListOf()
            val builder = Builder().setSession(config.REMARK ?: "PlusVPN").setMtu(MTU)
                .addAddress("26.26.26.1", 30).addRoute("0.0.0.0", 0)
                .addAddress("fd00:1:fd00:1:fd00:1:fd00:1", 126).addRoute("::", 0)
            AppRoutingPolicy.apply(includeOnly, selected, packageName,
                allow = { app ->
                    try { builder.addAllowedApplication(app); true }
                    catch (_: PackageManager.NameNotFoundException) { false }
                },
                bypass = { app ->
                    try { builder.addDisallowedApplication(app) }
                    catch (_: PackageManager.NameNotFoundException) { /* App removed since selection. */ }
                })
            addDns(builder, config.V2RAY_FULL_JSON_CONFIG)
            if (Build.VERSION.SDK_INT >= 29) builder.setMetered(false)
            tun = checkNotNull(builder.establish()) { "Android не создал VPN-интерфейс" }
            core.setUpListener(this)
            config.V2RAY_FULL_JSON_CONFIG = Utilities.ensureTunInbound(config.V2RAY_FULL_JSON_CONFIG, MTU)
            check(core.startCore(config, tun!!.fd) && core.isV2rayCoreRunning) { "Не удалось запустить Xray. Проверьте профиль." }
            // Replace the library's generic notification with the application's controls.
            showNotification(if (includeOnly) "VPN для выбранных приложений" else "VPN подключён")
            VpnBridge.refreshTile(this)
        } catch (e: Exception) {
            // Do not log configurations or credentials on failures.
            Log.e("PlusVpnService", "VPN startup failed: ${e.javaClass.simpleName}")
            VpnBridge.reportFailure(this, e.message ?: "Не удалось подключить VPN")
            stopTunnel()
        }
        return START_NOT_STICKY
    }

    private fun addDns(builder: Builder, raw: String) {
        val servers = JSONObject(raw).optJSONObject("dns")?.optJSONArray("servers")
        var added = false
        for (i in 0 until (servers?.length() ?: 0)) {
            val item = servers!!.opt(i)
            val address = if (item is JSONObject) item.optString("address") else item as? String
            if (address != null && isNumericAddress(address)) {
                try { builder.addDnsServer(address); added = true }
                catch (_: IllegalArgumentException) { /* Xray handles non-system DNS entries. */ }
            }
        }
        if (!added) builder.addDnsServer("1.1.1.1").addDnsServer("8.8.8.8")
    }

    private fun isNumericAddress(value: String): Boolean {
        if (value.contains(':')) return value.matches(Regex("[0-9a-fA-F:]+"))
        val parts = value.split('.')
        return parts.size == 4 && parts.all { it.toIntOrNull() in 0..255 }
    }

    private fun showNotification(message: String) {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "Подключение PlusVPN", NotificationManager.IMPORTANCE_LOW))
        val immutable = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        val open = PendingIntent.getActivity(this, 10, Intent(this, MainActivity::class.java), immutable)
        val stop = PendingIntent.getService(this, 11,
            Intent(this, PlusVpnService::class.java).setAction(ACTION_STOP), immutable)
        @Suppress("DEPRECATION")
        val notification = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this))
            .setSmallIcon(R.drawable.ic_vpn).setContentTitle(VpnBridge.label(this)).setContentText(message)
            .setContentIntent(open).setOngoing(true).setShowWhen(false).setOnlyAlertOnce(true)
            .addAction(Notification.Action.Builder(null, "Отключить", stop).build()).build()
        startForeground(NOTIFICATION_ID, notification)
        foreground = true
    }

    private fun stopTunnel() {
        if (stopping) return
        stopping = true
        try { core.stopCore() }
        finally {
            closeInterface()
            AppConfigs.V2RAY_CONFIG = null
            VpnBridge.onServiceStopped(this)
            stopSelf()
        }
    }

    private fun closeInterface() {
        try { tun?.close() } catch (_: Exception) { /* Already closed by the core. */ }
        tun = null
        if (foreground) { stopForeground(STOP_FOREGROUND_REMOVE); foreground = false }
    }

    override fun onDestroy() { stopTunnel(); super.onDestroy() }
    override fun onRevoke() { stopTunnel(); super.onRevoke() }
    override fun onProtect(socket: Int): Boolean = protect(socket)
    override fun getService(): Service = this
    override fun startService() { check(tun != null) { "VPN-интерфейс не готов" } }
    override fun stopService() { closeInterface(); stopSelf() }
}
