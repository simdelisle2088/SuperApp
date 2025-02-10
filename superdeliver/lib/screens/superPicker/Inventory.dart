import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/providers/Inventory_provider.dart';
import 'package:superdeliver/variables/svg.dart';
import '../../widget/background_image.dart';

class Inventory extends StatefulWidget {
  const Inventory({Key? key}) : super(key: key);

  @override
  _InventoryState createState() => _InventoryState();
}

class _InventoryState extends State<Inventory> {
  static const MethodChannel channel = MethodChannel('datawedge');

  String? scannedLocation;

  @override
  void initState() {
    super.initState();
    initializeDataWedge();
    WidgetsBinding.instance.addPostFrameCallback((_) => precacheImages());
  }

  Future<void> precacheImages() async {
    await precacheImage(
      const AssetImage('assets/images/background_hp-vert.png'),
      context,
    );
  }

  Future<void> initializeDataWedge() async {
    try {
      await channel.invokeMethod('startScan');
      channel.setMethodCallHandler((MethodCall call) async {
        if (call.method == 'barcodeScanned') {
          final String scannedData = call.arguments;
          if (kDebugMode) print('Scanned Data: $scannedData');
          setState(() {
            scannedLocation = scannedData;
          });

          // Fetch items for the scanned location
          final inventoryProvider =
              Provider.of<InventoryProvider>(context, listen: false);
          await inventoryProvider.fetchItemsByLocation(scannedData);
        }
      });
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print("Failed to initialize scanner: '${e.message}'.");
      }
    }
  }

  void clearInventoryAndNavigateBack(BuildContext context) {
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    inventoryProvider.clearItems();
    Navigator.pushNamed(context, '/scanLocation'); // Navigate back
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = Provider.of<InventoryProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          const BackgroundImage(
            url: 'assets/images/background_hp-vert.png',
          ),
          SafeArea(
            child: Column(
              children: [
                // Header showing the scanned location
                if (scannedLocation != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Location: $scannedLocation',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      itemCount: inventoryProvider.items.length,
                      itemBuilder: (context, index) {
                        final item = inventoryProvider.items[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          tileColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          title: Text(
                            '${item.name} (Count: ${item.count})', // Include the count
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text('UPC: ${item.upc}'),
                          trailing: const Icon(Icons.inventory),
                        );
                      },
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: () {
                        clearInventoryAndNavigateBack(context);
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all<Color>(
                          const Color.fromARGB(255, 255, 0, 0),
                        ),
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.all(8.0),
                        ),
                      ),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                            Colors.white, BlendMode.srcIn),
                        child: SvgPicture.string(backIconString),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
