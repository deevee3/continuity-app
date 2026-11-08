package com.omniflow.app

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.Switch
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val btnRequestNotif: Button = findViewById(R.id.btn_request_notif)
        val tvStatus: TextView = findViewById(R.id.tv_status)
        val tvNotifStatus: TextView = findViewById(R.id.tv_notif_status)
        val switchNotifications: Switch = findViewById(R.id.switch_notifications)
        val switchBattery: Switch = findViewById(R.id.switch_battery)

        // Check and display notification listener permission status
        updateNotificationAccessStatus(tvNotifStatus, btnRequestNotif)

        btnRequestNotif.setOnClickListener {
            // Open settings for user to grant notification access
            val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
            startActivity(intent)
        }

        // Toggle handlers — persist preferences so services can check them
        switchNotifications.setOnCheckedChangeListener { _, isChecked ->
            getSharedPreferences("omniflow_prefs", MODE_PRIVATE)
                .edit()
                .putBoolean("notifications_enabled", isChecked)
                .apply()
        }

        switchBattery.setOnCheckedChangeListener { _, isChecked ->
            getSharedPreferences("omniflow_prefs", MODE_PRIVATE)
                .edit()
                .putBoolean("battery_enabled", isChecked)
                .apply()
        }

        // Load saved toggle states
        val prefs = getSharedPreferences("omniflow_prefs", MODE_PRIVATE)
        switchNotifications.isChecked = prefs.getBoolean("notifications_enabled", true)
        switchBattery.isChecked = prefs.getBoolean("battery_enabled", true)

        // Start background Connection Service
        val serviceIntent = Intent(this, ConnectionService::class.java)
        startService(serviceIntent)
    }

    override fun onResume() {
        super.onResume()
        // Re-check permission status when returning from settings
        val tvNotifStatus: TextView = findViewById(R.id.tv_notif_status)
        val btnRequestNotif: Button = findViewById(R.id.btn_request_notif)
        updateNotificationAccessStatus(tvNotifStatus, btnRequestNotif)
    }

    private fun updateNotificationAccessStatus(statusView: TextView, grantButton: Button) {
        val isGranted = isNotificationListenerEnabled()
        if (isGranted) {
            statusView.text = "Notification Access: ✅ Granted"
            statusView.setTextColor(0xFF006600.toInt())
            grantButton.text = "Notification Access Granted"
            grantButton.isEnabled = false
        } else {
            statusView.text = "Notification Access: ❌ Not Granted"
            statusView.setTextColor(0xFFCC0000.toInt())
            grantButton.text = "Grant Notification Access"
            grantButton.isEnabled = true
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val cn = ComponentName(this, NotificationService::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }
}
