import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/providers/order_provider.dart';
import 'package:superdeliver/screens/superDeliver/order_details.dart';
import 'package:superdeliver/variables/colors.dart';
import 'package:superdeliver/variables/svg.dart';
import 'package:path_provider/path_provider.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  OrderListScreenState createState() => OrderListScreenState();
}

class OrderListScreenState extends State<OrderListScreen>
    with WidgetsBindingObserver {
  static const MethodChannel channel = MethodChannel('datawedge');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeDataWedge();
    fetchOrders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    channel.invokeMethod('stopScan');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchOrders();
      initializeDataWedge();
    }
  }

  void initializeDataWedge() async {
    try {
      await channel.invokeMethod('startScan');
      channel.setMethodCallHandler((MethodCall call) async {
        if (call.method == 'barcodeScanned') {
          var orderProvider =
              Provider.of<OrderProvider>(context, listen: false);
          await orderProvider.addOrderBasedOnBarcode(
              context, call.arguments.toString());
        }
      });
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print("Failed to initialize scanner: '${e.message}'.");
      }
    }
  }

  void fetchOrders() {
    Provider.of<OrderProvider>(context, listen: false)
        .initializeOrders(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/background_hp.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 40, bottom: 60),
            child: Column(
              children: [
                buildTopButton(),
                buildOrdersList(),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: ElevatedButton(
              onPressed: () => showLogoutConfirmationDialog(context),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all<Color>(superRed),
              ),
              child: ColorFiltered(
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                child: SvgPicture.string(backIconString),
              ),
            ),
          ),
          const Positioned(
            bottom: 20,
            right: 30,
            child: RefreshButton(),
          ),
        ],
      ),
    );
  }

  Widget buildTopButton() {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Consumer<OrderProvider>(
          builder: (context, orderProvider, child) {
            return ElevatedButton(
              onPressed: orderProvider.areAllOrdersComplete()
                  ? () async {
                      bool routeStarted = false;
                      while (!routeStarted) {
                        routeStarted = await orderProvider.startRoute(context);
                        if (!routeStarted) {
                          if (kDebugMode) {
                            print('Retrying to start route...');
                          }
                          await Future.delayed(const Duration(
                              seconds: 2)); // Optional delay before retrying
                        }
                      }
                      // Check if the widget is still mounted before navigating
                      if (mounted) {
                        await Navigator.pushReplacementNamed(
                            context, '/orderRoutes');
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Commencer votre route',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildOrdersList() {
    return Expanded(
      child: Padding(
          padding:
              const EdgeInsets.only(top: 20, left: 30, right: 30, bottom: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Consumer<OrderProvider>(
                builder: (context, orderProvider, child) {
                  if (orderProvider.getOrderCount() == 0) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ReorderableListView.builder(
                    onReorder: (
                      int oldIndex,
                      int newIndex,
                    ) {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      orderProvider.reorderOrders(
                        context,
                        oldIndex,
                        newIndex,
                        orderProvider.driverId, //passing Driver Id
                      );
                    },
                    itemCount: orderProvider.getOrderCount(),
                    itemBuilder: (context, index) {
                      var orderData = orderProvider.getOrderCopyAt(index);
                      return ListTile(
                        key: ValueKey(orderData.order_number),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(
                          '#${orderData.tracking_number} - ${orderData.client_name.toLowerCase()}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetails(
                                currentOrderNumber: orderData.order_number,
                                storeId: orderData.store,
                              ),
                            ),
                          );
                        },
                        trailing: CircleAvatar(
                          backgroundColor: orderProvider
                                  .isOrderComplete(orderData.order_number)
                              ? Colors.green
                              : Colors.red,
                          radius: 10,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          )),
    );
  }
}

class RefreshButton extends StatefulWidget {
  const RefreshButton({super.key});

  @override
  _RefreshButtonState createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<RefreshButton> {
  double turns = 1;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(50),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedRotation(
              turns: turns,
              curve: Curves.ease,
              duration: const Duration(milliseconds: 700),
              child: IconButton(
                icon: const Icon(Icons.refresh),
                color: Colors.white,
                iconSize: 26,
                onPressed: () => {_refreshPage()},
              ))),
    );
  }

  Future<void> _refreshPage() async {
    await _clearCache();
    if (mounted) {
      setState(() {
        turns += 1;
      });
    }
  }

  Future<void> _clearCache() async {
    final tempDir = await getTemporaryDirectory();
    await tempDir.exists() ? tempDir.delete(recursive: true) : null;
    clearAppCache();
    setState(() {});
  }
}
