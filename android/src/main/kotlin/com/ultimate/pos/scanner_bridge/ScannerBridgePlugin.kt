package com.ultimate.pos.scanner_bridge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel

class ScannerBridgePlugin : FlutterPlugin, ScannerHostApi, EventChannel.StreamHandler {
    private var context: Context? = null
    private var listening = false
    private var eventSink: EventChannel.EventSink? = null
    private var scansChannel: EventChannel? = null
    private var receiver: BroadcastReceiver? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        ScannerHostApi.setUp(binding.binaryMessenger, this)
        scansChannel = EventChannel(binding.binaryMessenger, SCANS_CHANNEL)
        scansChannel?.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopListening()
        ScannerHostApi.setUp(binding.binaryMessenger, null)
        scansChannel?.setStreamHandler(null)
        scansChannel = null
        eventSink = null
        context = null
    }

    override fun inspectHost(): ScannerHostInspection {
        return ScannerHostInspection(
            listening = listening,
            preferNativeBroadcast = looksLikeImin(),
        )
    }

    override fun startListening() {
        val current = checkNotNull(context) { "scanner bridge is detached" }
        if (listening) {
            return
        }
        val nextReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != RESULT_ACTION) {
                    return
                }
                val barcode = intent.getStringExtra(EXTRA_DECODE_DATA_STR)
                    ?: intent.getByteArrayExtra(EXTRA_DECODE_DATA)?.toString(Charsets.UTF_8)
                    ?: return
                val trimmed = barcode.trim()
                if (trimmed.isEmpty()) {
                    return
                }
                eventSink?.success(hashMapOf("barcode" to trimmed))
            }
        }
        val filter = IntentFilter(RESULT_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            current.registerReceiver(nextReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            current.registerReceiver(nextReceiver, filter)
        }
        receiver = nextReceiver
        listening = true
    }

    override fun stopListening() {
        val current = context
        val active = receiver
        if (current != null && active != null) {
            current.unregisterReceiver(active)
        }
        receiver = null
        listening = false
    }

    override fun preferBroadcastOutput(): Boolean {
        val current = context ?: return false
        val intent = Intent(CONFIG_ACTION)
            .putExtra("type", 0)
            .putExtra("broadcast", true)
            .putExtra("broadcastAction", RESULT_ACTION)
            .putExtra("broadcastExtraStr", EXTRA_DECODE_DATA_STR)
            .putExtra("broadcastExtraByte", EXTRA_DECODE_DATA)
        current.sendBroadcast(intent)
        return looksLikeImin()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun looksLikeImin(): Boolean {
        val haystack = listOf(Build.MANUFACTURER, Build.BRAND, Build.MODEL)
            .joinToString(separator = " ")
            .lowercase()
        return haystack.contains("imin")
    }

    private companion object {
        const val SCANS_CHANNEL = "com.ultimate.pos/scanner_scans"
        const val RESULT_ACTION = "com.imin.scanner.api.RESULT_ACTION"
        const val CONFIG_ACTION = "com.imin.scanner.builtin.config"
        const val EXTRA_DECODE_DATA_STR = "decode_data_str"
        const val EXTRA_DECODE_DATA = "decode_data"
    }
}
