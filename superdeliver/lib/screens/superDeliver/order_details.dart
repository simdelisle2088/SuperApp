// ignore_for_file: avoid_function_literals_in_foreach_calls, non_constant_identifier_names, use_build_context_synchronously, library_private_types_in_public_api
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/models/order_details.dart';
import 'package:superdeliver/providers/order_provider.dart';
import 'package:superdeliver/screens/superDeliver/orders.dart';
import 'package:superdeliver/variables/colors.dart';
import 'package:superdeliver/variables/svg.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class OrderDetails extends StatefulWidget {
  final String currentOrderNumber;
  final int storeId;

  const OrderDetails({
    super.key,
    required this.currentOrderNumber,
    required this.storeId,
  });

  @override
  OrderDetailsState createState() => OrderDetailsState();
}

class OrderDetailsState extends State<OrderDetails> {
  static const MethodChannel channel = MethodChannel('datawedge');

  @override
  void initState() {
    super.initState();
    initializeDataWedge();
  }

  void initializeDataWedge() async {
    try {
      await channel.invokeMethod('startScan');
      channel.setMethodCallHandler((MethodCall call) async {
        if (call.method != 'barcodeScanned') return;
        final scannedBarcode = call.arguments.toString();

        await Provider.of<OrderProvider>(context, listen: false).updateParts(
            context, widget.currentOrderNumber, widget.storeId, scannedBarcode);
      });
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print("Failed to initialize scanner: '${e.message}'.");
      }
    }
  }

  void deleteOrder(String orderNumber, int storeId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content:
              const Text("Êtes-vous sûr de vouloir supprimer cette commande ?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Consumer<OrderProvider>(
              builder: (context, orderProvider, child) {
                return TextButton(
                  child: const Text("Delete"),
                  onPressed: () async {
                    await orderProvider.removeOrder(
                        context, orderNumber, storeId);
                  },
                );
              },
            ),
          ],
        );
      },
    );
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
              // Retrieve order details
              var orderDetails = orderProvider
                  .getOrderCopyByOrderNumber(widget.currentOrderNumber);

              // Group items by their original order number
              final groupedItems = <String, List<Item>>{};
              for (var item in orderDetails.orderInfo) {
                groupedItems.putIfAbsent(item.order_number, () => []).add(item);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (orderDetails.orderInfo.isEmpty)
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
                            child: ListView(
                              children: groupedItems.entries.map((entry) {
                                // Render each order_number as a section title
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        'Order Number: ${entry.key}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    // Render items under each order number
                                    ...entry.value.map((item) {
                                      return OrderItemWidget(
                                        partNumber: item.part_number,
                                        store: widget.storeId,
                                        orderNumber: widget.currentOrderNumber,
                                      );
                                    }),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Your bottom row with buttons (back, refresh, delete)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/orderList');
                        },
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all<Color>(superRed),
                        ),
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          child: SvgPicture.string(backIconString),
                        ),
                      ),
                      const RefreshButton(),
                      Container(
                        decoration: BoxDecoration(
                          color: superRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: () {
                            deleteOrder(
                                widget.currentOrderNumber, widget.storeId);
                          },
                        ),
                      )
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class OrderItemWidget extends StatefulWidget {
  final String orderNumber;
  final String partNumber;
  final int store;

  const OrderItemWidget({
    super.key,
    required this.partNumber,
    required this.store,
    required this.orderNumber,
  });

  @override
  _OrderItemWidgetState createState() => _OrderItemWidgetState();
}

class _OrderItemWidgetState extends State<OrderItemWidget> {
  late Color backgroundConfirmColor;
  late Color backgroundColor;
  late String trailingText;
  late int unitsAsInt;

  @override
  void initState() {
    super.initState();
  }

  void promptdDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la mise à jour'),
          content: const Text(
              "Êtes-vous sûr de vouloir mettre à jour cette pièces?"),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Consumer<OrderProvider>(
              builder: (context, orderProvider, child) {
                return TextButton(
                  child: const Text('Confirmez'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    orderProvider.updateBatchPart(context, widget.partNumber,
                        widget.store, widget.orderNumber);
                  },
                );
              },
            ),
          ],
        );
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
                onPressed: promptdDialog,
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
                    "[ ${orderProvider.getItemCopyByPartNumber(widget.orderNumber, widget.partNumber).num_scanned}/${orderProvider.getItemCopyByPartNumber(widget.orderNumber, widget.partNumber).units} ]",
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              CircleAvatar(
                backgroundColor: orderProvider.getItemScanState(
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
