package com.plusvpn.plus_vpn

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast

class VpnTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        update()
    }

    private fun update() {
        val tile = qsTile ?: return
        val state = VpnBridge.liveState()
        tile.icon = Icon.createWithResource(this, R.drawable.ic_vpn)
        tile.label = VpnBridge.label(this)
        tile.state = if (state == "CONNECTED") Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        if (Build.VERSION.SDK_INT >= 29) tile.subtitle = when (state) {
            "CONNECTED" -> "Подключено"
            "CONNECTING" -> "Подключение…"
            "DISCONNECTING" -> "Отключение…"
            else -> "Отключено"
        }
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (isLocked) unlockAndRun { toggle() } else toggle()
    }

    private fun toggle() {
        try {
            when (VpnBridge.liveState()) {
                "CONNECTED" -> VpnBridge.stop(this)
                "CONNECTING", "DISCONNECTING" -> return
                else -> {
                    if (VpnService.prepare(this) == null) VpnBridge.start(this)
                    else {
                        // Android requires a visible consent activity for the very first start.
                        val intent = Intent(this, VpnPermissionActivity::class.java)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        if (Build.VERSION.SDK_INT >= 34) startActivityAndCollapse(PendingIntent.getActivity(
                            this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                        else @Suppress("DEPRECATION") startActivityAndCollapse(intent)
                    }
                }
            }
        } catch (e: Exception) {
            Toast.makeText(this, e.message ?: "Не удалось переключить VPN", Toast.LENGTH_LONG).show()
        }
        update()
    }
}
