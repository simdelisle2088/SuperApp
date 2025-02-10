import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/providers/order_provider.dart';

void initializeScanPartDataWedge(
    MethodChannel channel, BuildContext context) async {
  try {
    await channel.invokeMethod('startScan');
    channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'barcodeScanned') {
        await Provider.of<OrderProvider>(context, listen: false)
            .addOrderBasedOnBarcode(context, call.arguments.toString());
      }
    });
  } on PlatformException catch (e) {
    if (kDebugMode) {
      print("Failed to initialize scanner: '${e.message}'.");
    }
  }
}
