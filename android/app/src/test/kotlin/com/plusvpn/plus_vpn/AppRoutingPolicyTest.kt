package com.plusvpn.plus_vpn

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppRoutingPolicyTest {
    @Test fun onlySelectedAppsAreAllowedAndNoBypassListIsCreated() {
        val allowed = mutableListOf<String>()
        val bypassed = mutableListOf<String>()
        AppRoutingPolicy.apply(true, listOf("one.app", "two.app", "one.app", "plusvpn"), "plusvpn",
            allow = { allowed.add(it); true }, bypass = { bypassed.add(it) })
        assertEquals(listOf("one.app", "two.app"), allowed)
        assertTrue(bypassed.isEmpty())
    }
    @Test fun exclusionsKeepTheCoreOutsideTheTunnelAndNeverCreateAnAllowList() {
        val bypassed = mutableListOf<String>()
        AppRoutingPolicy.apply(false, listOf("excluded.app", "plusvpn", "excluded.app"), "plusvpn",
            allow = { error("Exclude mode must not invoke addAllowedApplication") },
            bypass = { bypassed.add(it) })
        assertEquals(listOf("plusvpn", "excluded.app"), bypassed)
    }
    @Test(expected = IllegalArgumentException::class)
    fun emptyIncludeListIsRejectedRatherThanRoutingAllApps() {
        AppRoutingPolicy.apply(true, emptyList(), "plusvpn", allow = { true }, bypass = {})
    }
    @Test(expected = IllegalStateException::class)
    fun removedIncludeAppsAreRejectedRatherThanRoutingAllApps() {
        AppRoutingPolicy.apply(true, listOf("removed.app"), "plusvpn", allow = { false }, bypass = {})
    }
    @Test fun removedEntriesDoNotPreventOtherSelectedAppsFromUsingVpn() {
        val allowed = mutableListOf<String>()
        AppRoutingPolicy.apply(true, listOf("removed.app", "installed.app"), "plusvpn",
            allow = { if (it == "installed.app") { allowed.add(it); true } else false },
            bypass = { error("Allow and bypass lists must not be combined") })
        assertEquals(listOf("installed.app"), allowed)
    }
}
