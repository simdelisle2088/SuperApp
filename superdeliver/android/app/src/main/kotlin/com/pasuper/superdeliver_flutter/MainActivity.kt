package com.pasuper.superdeliver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL_NAME = "datawedge"
    private val DATAWEDGE_ACTION = "com.symbol.datawedge.api.RESULT_ACTION"
    private val EXTRA_DATA = "com.symbol.datawedge.data_string"
    private val PROFILE_NAME = "SuperDeliver"

    private lateinit var methodChannel: MethodChannel
    private lateinit var barcodeReceiver: BroadcastReceiver

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel =
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startScan" -> {
                    startScan()
                    result.success(null)
                }
                "stopScan" -> {
                    stopScan()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        initializeBarcodeReceiver()
    }

    private fun initializeBarcodeReceiver() {
        barcodeReceiver =
                object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        Log.d("MainActivity", "Intent received with action: ${intent?.action}")
                        intent?.extras?.keySet()?.forEach { key ->
                            Log.d("MainActivity", "Key $key: ${intent.extras?.get(key)}")
                        }

                        intent?.let {
                            if (it.action == DATAWEDGE_ACTION) {
                                val barcode = it.getStringExtra(EXTRA_DATA)
                                Log.d("MainActivity", "Barcode received: $barcode")
                                barcode?.let { data ->
                                    methodChannel.invokeMethod("barcodeScanned", data)
                                }
                                        ?: Log.d("MainActivity", "No barcode data received")
                            }
                        }
                    }
                }
        val filter = IntentFilter(DATAWEDGE_ACTION)
        registerReceiver(barcodeReceiver, filter)
    }

    private fun startScan() {
        val intent =
                Intent().apply {
                    action = DATAWEDGE_ACTION
                    putExtra("com.symbol.datawedge.api.START_SCANNING", true)
                    putExtra("SEND_RESULT", "true")
                    putExtra(PROFILE_NAME, true)
                }
        sendBroadcast(intent)
    }

    private fun stopScan() {
        val intent =
                Intent().apply {
                    action = DATAWEDGE_ACTION
                    putExtra("com.symbol.datawedge.api.STOP_SCANNING", true)
                    putExtra("SEND_RESULT", "true")
                    putExtra(PROFILE_NAME, true)
                }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(barcodeReceiver)
    }
}
