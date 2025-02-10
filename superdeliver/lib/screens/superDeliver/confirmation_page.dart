import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:superdeliver/providers/order_provider.dart';
import 'package:superdeliver/screens/superDeliver/order_routes.dart';

class ConfirmationPage extends StatefulWidget {
  const ConfirmationPage({super.key});

  @override
  ConfirmationPageState createState() => ConfirmationPageState();
}

class ConfirmationPageState extends State<ConfirmationPage> {
  static const MethodChannel channel = MethodChannel('datawedge');

  @override
  void initState() {
    super.initState();
    initializeDataWedge();
  }

  /// Initializes the DataWedge scanner.
  ///
  /// This function starts the scanner and sets up a method call handler to listen for
  /// barcode scanned events. When a barcode is scanned, it confirms the parts with
  /// the `OrderProvider`.
  ///
  /// Example:
  /// ```dart
  /// await initializeDataWedge();
  /// ```
  void initializeDataWedge() async {
    try {
      await channel.invokeMethod('startScan');
      channel.setMethodCallHandler((MethodCall call) async {
        if (call.method != 'barcodeScanned') return;
        final scannedBarcode = call.arguments.toString();

        if (scannedBarcode.isEmpty) {
          return;
        }

        OrderProvider orderProvider =
            Provider.of<OrderProvider>(context, listen: false);
        await orderProvider.confirmParts(context, scannedBarcode);
      });
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print("Failed to initialize scanner: '${e.message}'.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundContainer(
        child: Padding(
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 50, bottom: 30),
          child: Consumer<OrderProvider>(
            builder: (context, orderProvider, child) {
              var orderCopy = orderProvider.getCurrentOrderCopy(context);
              bool isOrderConfirmed = orderProvider.isOrderConfirmed(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Back button placed at the top
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text('Reculez au commande',
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                    onPressed: () {
                      // Set route_started to false for the current route
                      orderProvider.setRouteStarted(false, context);
                      Navigator.pushReplacementNamed(context, '/orderList');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors
                          .transparent, // Customize background color if needed
                      elevation: 0, // Remove elevation if you want it flat
                    ),
                  ),

                  if (orderCopy.orderInfo.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('Aucun détail de commande disponible.'),
                      ),
                    )
                  else
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListView.separated(
                              itemCount: orderCopy.orderInfo.length,
                              separatorBuilder: (_, __) => const Divider(
                                  indent: 20, endIndent: 20, height: 1),
                              itemBuilder: (context, index) {
                                return OrderItemConfirmWidget(
                                  partNumber:
                                      orderCopy.orderInfo[index].part_number,
                                  store: orderCopy.store,
                                  orderNumber: orderCopy.order_number,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: 20.0), // Adjust the padding as needed
                          child: SizedBox(
                            width: 300,
                            child: ElevatedButton(
                              onPressed: () {
                                returnOrders(
                                    orderCopy.order_number, orderCopy.store);
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                backgroundColor:
                                    const Color.fromARGB(255, 240, 147, 7),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Client Non Présent'),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: ElevatedButton(
                            onPressed: isOrderConfirmed
                                ? () {
                                    Navigator.pushReplacementNamed(
                                        context, '/menuBon');
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Menu'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void returnOrders(String orderNumber, int storeId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer Retour"),
          content:
              const Text("Êtes-vous sûr de vouloir retourner cette commande?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Consumer<OrderProvider>(
              builder: (context, orderProvider, child) {
                return TextButton(
                  child: const Text("Retour en magasin"),
                  onPressed: () async {
                    await orderProvider.returnOrder(
                        context, orderNumber, storeId);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderRoute(),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  // void cancelOrders(String orderNumber, int storeId) {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         content: const Text(
  //             "Êtes-vous sûr de vouloir effectuer la cancellation cette commande?"),
  //         actions: <Widget>[
  //           Consumer<OrderProvider>(
  //             builder: (context, orderProvider, child) {
  //               return TextButton(
  //                 child: const Text("Cancellation de la commande"),
  //                 onPressed: () async {
  //                   await orderProvider.cancelOrder(
  //                       context, orderNumber, storeId);
  //                   Navigator.pushReplacement(
  //                     context,
  //                     MaterialPageRoute(
  //                       builder: (context) => const OrderRoute(),
  //                     ),
  //                   );
  //                 },
  //               );
  //             },
  //           ),
  //           TextButton(
  //             child: const Text("Annuler"),
  //             onPressed: () => Navigator.of(context).pop(),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
}

class BackgroundContainer extends StatelessWidget {
  final Widget child;

  const BackgroundContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/background_hp.png"),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}

class OrderItemConfirmWidget extends StatefulWidget {
  final int store;
  final String orderNumber;
  final String partNumber;

  const OrderItemConfirmWidget({
    super.key,
    required this.partNumber,
    required this.store,
    required this.orderNumber,
  });

  @override
  OrderItemConfirmWidgetState createState() => OrderItemConfirmWidgetState();
}

class OrderItemConfirmWidgetState extends State<OrderItemConfirmWidget> {
  late Color backgroundConfirmColor;
  late Color backgroundColor;
  late String trailingText;
  late int unitsAsInt;

  @override
  void initState() {
    super.initState();
  }

  void promptDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<OrderProvider>(
            builder: (context, orderProvider, child) {
          return AlertDialog(
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: SingleChildScrollView(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        child: const Text('Confirmer'),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await orderProvider.byPassScan(
                              context,
                              widget.orderNumber,
                              widget.store,
                              widget.partNumber);
                        },
                      ),
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        return Container(
          padding:
              const EdgeInsets.only(left: 0, right: 20, bottom: 5, top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: promptDialog,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.partNumber,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      orderProvider
                          .getItemCopyByPartNumber(
                              widget.orderNumber, widget.partNumber)
                          .description,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(right: 10),
                  alignment: Alignment.centerRight,
                  child: Text(
                    "[ ${orderProvider.getItemCopyByPartNumber(widget.orderNumber, widget.partNumber).confirmed_scanned}/${orderProvider.getItemCopyByPartNumber(widget.orderNumber, widget.partNumber).units} ]",
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              CircleAvatar(
                backgroundColor: orderProvider.getItemConfirmationState(
                        widget.orderNumber, widget.partNumber)
                    ? Colors.green
                    : Colors.red,
                radius: 12,
              ),
            ],
          ),
        );
      },
    );
  }
}
