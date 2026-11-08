package com.omniflow.app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent
import org.json.JSONObject

class NotificationService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        // Respect user's toggle preference
        val prefs = getSharedPreferences("omniflow_prefs", MODE_PRIVATE)
        if (!prefs.getBoolean("notifications_enabled", true)) return
        
        val packageName = sbn.packageName

        val extras = sbn.notification.extras
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""

        if (title.isNotEmpty() || text.isNotEmpty()) {
            val json = JSONObject()
            json.put("type", "notification")
            json.put("app", getAppName(packageName))
            json.put("title", title)
            json.put("body", text)
            
            // Forward to connection service
            CompanionHelper.broadcastNotification(json)
        }
    }

    private fun getAppName(packageName: String): String {
        return try {
            val pm = packageManager
            val info = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            packageName.split(".").last().replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // Optional: handle notification dismissal
    }
}
