package com.omniflow.app

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.IBinder
import android.util.Log
import org.json.JSONObject
import java.io.BufferedWriter
import java.io.OutputStreamWriter
import java.net.ServerSocket
import java.net.Socket
import kotlin.concurrent.thread

class ConnectionService : Service() {

    private val TAG = "OmniFlowService"
    private var serverSocket: ServerSocket? = null
    private val activeClients = mutableListOf<Socket>()

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                             status == BatteryManager.BATTERY_STATUS_FULL
            
            val batteryPct = (level.toFloat() / scale.toFloat() * 100).toInt()
            sendTelemetry(batteryPct, isCharging)
        }
    }

    override fun onCreate() {
        super.onCreate()
        CompanionHelper.registerService(this)
        // Register battery receiver
        registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        
        // Start TCP Server
        startServer()
    }

    private fun startServer() {
        thread {
            try {
                serverSocket = ServerSocket(8080)
                Log.d(TAG, "Server listening on port 8080")
                while (true) {
                    val socket = serverSocket?.accept() ?: break
                    Log.d(TAG, "Mac client connected: ${socket.inetAddress}")
                    synchronized(activeClients) {
                        activeClients.add(socket)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Server error: ${e.message}")
            }
        }
    }

    fun broadcastMessage(message: JSONObject) {
        val payload = message.toString() + "\n"
        thread {
            synchronized(activeClients) {
                val iterator = activeClients.iterator()
                while (iterator.hasNext()) {
                    val client = iterator.next()
                    try {
                        val writer = BufferedWriter(OutputStreamWriter(client.getOutputStream()))
                        writer.write(payload)
                        writer.flush()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error sending to client: ${e.message}")
                        try { client.close() } catch (ex: Exception) {}
                        iterator.remove()
                    }
                }
            }
        }
    }

    private fun sendTelemetry(batteryPct: Int, isCharging: Boolean) {
        // Respect user's toggle preference
        val prefs = getSharedPreferences("omniflow_prefs", MODE_PRIVATE)
        if (!prefs.getBoolean("battery_enabled", true)) return
        
        val json = JSONObject()
        json.put("type", "telemetry")
        json.put("battery", batteryPct)
        json.put("charging", isCharging)
        broadcastMessage(json)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        CompanionHelper.unregisterService()
        unregisterReceiver(batteryReceiver)
        try {
            serverSocket?.close()
        } catch (e: Exception) {}
        synchronized(activeClients) {
            for (client in activeClients) {
                try { client.close() } catch (e: Exception) {}
            }
            activeClients.clear()
        }
    }
}
