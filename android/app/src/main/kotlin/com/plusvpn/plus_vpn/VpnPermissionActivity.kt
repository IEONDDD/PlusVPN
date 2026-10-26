package com.plusvpn.plus_vpn

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.widget.Toast

/** A native consent trampoline; it never creates a Flutter engine. */
class VpnPermissionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState != null) return
        val consent = VpnService.prepare(this)
        if (consent == null) connect() else @Suppress("DEPRECATION") startActivityForResult(consent, 701)
    }

    @Deprecated("Android activity result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 701 && resultCode == RESULT_OK) connect() else finish()
    }

    private fun connect() {
        try { VpnBridge.start(this) }
        catch (e: Exception) { Toast.makeText(this, e.message, Toast.LENGTH_LONG).show() }
        finish()
    }
}
