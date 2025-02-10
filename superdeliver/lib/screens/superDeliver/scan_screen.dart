// ignore_for_file: prefer_const_constructors, library_private_types_in_public_api, use_build_context_synchronously
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/providers/order_provider.dart';
import 'package:superdeliver/variables/colors.dart';
import 'package:superdeliver/widget/version.dart';
import '../../widget/help_button.dart';

dynamic ordersData = ordersData;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const MethodChannel channel = MethodChannel('datawedge');
  String scannedBarcode = '';

  @override
  void initState() {
    super.initState();
    initializeDataWedge();
    WidgetsBinding.instance.addPostFrameCallback((_) => precacheImages());
  }

  @override
  void dispose() {
    channel.invokeMethod('stopScan');
    super.dispose();
  }

  void initializeDataWedge() async {
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

  void precacheImages() {
    precacheImage(const AssetImage("assets/images/background_hp.png"), context);
    precacheImage(const AssetImage("assets/images/barcode_image.png"), context);
    precacheImage(const AssetImage("assets/images/tc26.png"), context);
  }

  void showSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height / 2 - 24,
          left: 12,
          right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: const <Widget>[
          // Removed const here
          BackgroundImage(),
          BarcodeImage(),
          ScanPrompt(),
          LogoutButton(),
          Positioned(
            left: 20,
            bottom: 20,
            child: HelpButton(initialLocation: "1"),
          ),
          VersionDisplay(),
        ],
      ),
    );
  }
}

class BackgroundImage extends StatelessWidget {
  const BackgroundImage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background_hp.png"),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class BarcodeImage extends StatelessWidget {
  const BarcodeImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Image.asset("assets/images/barcode_image.png"),
      ),
    );
  }
}

class ScanPrompt extends StatelessWidget {
  const ScanPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/images/tc26.png",
            width: 250,
            height: 250,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 20),
            child: Text(
              'Commencez le scan de vos factures',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: superRed,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: () => showLogoutConfirmationDialog(context),
          icon: const Icon(
            Icons.logout,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
