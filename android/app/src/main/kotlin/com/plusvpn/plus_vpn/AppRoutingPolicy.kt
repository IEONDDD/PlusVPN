package com.plusvpn.plus_vpn

/** Android builders must use either an allow list or a bypass list, never both. */
object AppRoutingPolicy {
    fun apply(
        includeOnly: Boolean,
        selected: List<String>,
        ownPackage: String,
        allow: (String) -> Boolean,
        bypass: (String) -> Unit
    ) {
        val packages = selected.filter { it.isNotBlank() && it != ownPackage }.distinct()
        if (includeOnly) {
            require(packages.isNotEmpty()) { "Выберите хотя бы одно приложение для VPN" }
            val installedCount = packages.count { allow(it) }
            check(installedCount > 0) { "Выбранные приложения удалены. Выберите приложения для VPN заново." }
        } else {
            bypass(ownPackage)
            packages.forEach(bypass)
        }
    }
}
