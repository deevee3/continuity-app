package com.omniflow.app

import org.json.JSONObject
import java.lang.ref.WeakReference

object CompanionHelper {
    private var serviceRef: WeakReference<ConnectionService>? = null

    fun registerService(service: ConnectionService) {
        serviceRef = WeakReference(service)
    }

    fun unregisterService() {
        serviceRef = null
    }

    fun broadcastNotification(notificationJson: JSONObject) {
        serviceRef?.get()?.broadcastMessage(notificationJson)
    }
}
