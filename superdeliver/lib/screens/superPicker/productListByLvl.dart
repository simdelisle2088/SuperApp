import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/providers/picker_provider.dart';
import 'package:superdeliver/stores/store.dart';
import 'package:superdeliver/variables/svg.dart';

class ProductListByLvl extends StatefulWidget {
  final int initialLevel;
  const ProductListByLvl({super.key, required this.initialLevel});

  @override
  // ignore: library_private_types_in_public_api
  _ProductListByLvlState createState() => _ProductListByLvlState();
}

class _ProductListByLvlState extends State<ProductListByLvl> {
  String? _selectedOrderAndItem;
  String? currentUserId;
  PickerProvider? pickerProvider;

  static const MethodChannel channel = MethodChannel('datawedge');
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeScan();
    _loadUserId();
    // Update time difference every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (pickerProvider == null) {
      pickerProvider = Provider.of<PickerProvider>(context, listen: false);
      // Retrieve the level from the passed arguments
      final int initialLevel =
          ModalRoute.of(context)?.settings.arguments as int;
      pickerProvider!.fetchPickingOrdersByLevel(initialLevel);
      pickerProvider!.startPeriodicRefresh(initialLevel);
    }
  }

  @override
  void dispose() {
    pickerProvider?.stopPeriodicRefresh();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickerProvider = Provider.of<PickerProvider>(context);
    final ordersByOrderNumber = pickerProvider.ordersByOrderNumber;

    if (ordersByOrderNumber.isEmpty) {
      return Scaffold(
        body: Stack(
          children: [
            const BackgroundImage(),
            const Center(
              child: Text(
                'Aucune Items Disponible',
                style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
            ),
            _buildBackButton(pickerProvider, ordersByOrderNumber),
          ],
        ),
      );
    }

    // First, prioritize orders starting with "F01", "F02", or "F03"
    final List<MapEntry<String, List<Map<String, dynamic>>>> topPriorityOrders =
        ordersByOrderNumber.entries.where((entry) {
      return entry.key.startsWith('F01') ||
          entry.key.startsWith('F02') ||
          entry.key.startsWith('F03');
    }).toList();

    // Sort top priority orders by created_at (oldest first)
    topPriorityOrders.sort((a, b) {
      final aCreatedAt = DateTime.parse(a.value.first['created_at']);
      final bCreatedAt = DateTime.parse(b.value.first['created_at']);
      return aCreatedAt.compareTo(bCreatedAt);
    });

    // Next, filter and prioritize orders that start with any letter
    final List<MapEntry<String, List<Map<String, dynamic>>>>
        letterPriorityOrders = ordersByOrderNumber.entries.where((entry) {
      return RegExp(r'^[A-Za-z]').hasMatch(entry.key) &&
          !entry.key.startsWith('F01') &&
          !entry.key.startsWith('F02') &&
          !entry.key.startsWith('F03');
    }).toList();

    // Sort letter-prioritized orders by created_at (oldest first)
    letterPriorityOrders.sort((a, b) {
      final aCreatedAt = DateTime.parse(a.value.first['created_at']);
      final bCreatedAt = DateTime.parse(b.value.first['created_at']);
      return aCreatedAt.compareTo(bCreatedAt);
    });

    // Lastly, add the remaining orders that don't start with F01, F02, F03, or any letter
    final List<MapEntry<String, List<Map<String, dynamic>>>> remainingOrders =
        ordersByOrderNumber.entries.where((entry) {
      return !RegExp(r'^[A-Za-z]').hasMatch(entry.key) &&
          !entry.key.startsWith('F01') &&
          !entry.key.startsWith('F02') &&
          !entry.key.startsWith('F03');
    }).toList();

    // Sort remaining orders by created_at (oldest first)
    remainingOrders.sort((a, b) {
      final aCreatedAt = DateTime.parse(a.value.first['created_at']);
      final bCreatedAt = DateTime.parse(b.value.first['created_at']);
      return aCreatedAt.compareTo(bCreatedAt);
    });

    // Combine all prioritized orders
    final List<MapEntry<String, List<Map<String, dynamic>>>> sortedOrders = [
      ...topPriorityOrders,
      ...letterPriorityOrders,
      ...remainingOrders,
    ];

    // Limit the number of displayed orders to 5
    final List<MapEntry<String, List<Map<String, dynamic>>>> limitedOrders =
        sortedOrders.take(10).toList();

    return Scaffold(
      body: Stack(
        children: [
          const BackgroundImage(),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(
                  top: 30.0, left: 20, right: 20, bottom: 70),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: limitedOrders
                      .map<Widget>((order) => _buildOrder(order))
                      .toList(),
                ),
              ),
            ),
          ),
          _buildBackButton(pickerProvider, ordersByOrderNumber),
        ],
      ),
    );
  }

  Widget _buildOrder(MapEntry<String, List<Map<String, dynamic>>> entry) {
    final orderNumber = entry.key;
    final items = entry.value;
    final createdAt = items.first['created_at'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOrderHeader(orderNumber, createdAt),
        _buildOrderItems(orderNumber, items),
      ],
    );
  }

  String calculateTimeDifference(String createdAt) {
    DateTime createdTime = DateTime.parse(createdAt);
    Duration difference = DateTime.now().difference(createdTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildOrderHeader(String orderNumber, String createdAt) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              'Order: $orderNumber',
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              calculateTimeDifference(createdAt),
              style: const TextStyle(
                fontSize: 14.0,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems(
      String orderNumber, List<Map<String, dynamic>> items) {
    final visibleItems = items
        .where((item) =>
            (item['is_archived'] == null || item['is_archived'] == false) &&
            (item['is_missing'] == null || item['is_missing'] == false))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.0),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _OrderItemsHeader(),
          const Divider(color: Colors.grey),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: visibleItems
                .map((item) => _buildItemRow(orderNumber, item))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String orderNumber, Map<String, dynamic> item) {
    final String itemKey = item['item'].toString();
    final String displayItemKey = itemKey.length > 11
        ? '${itemKey.substring(0, 11)}\n${itemKey.substring(11)}'
        : itemKey;

    final String itemDesc = item['description'];
    final String orderAndItemKey = '$orderNumber-$itemKey';
    final isSelected = _selectedOrderAndItem == orderAndItemKey;
    final isReservedByOther = item['is_reserved'] &&
        item['reserved_by'] != null &&
        item['reserved_by'] != currentUserId;
    final String selectedLocation = item['loc'] ?? 'Unknown Location';

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: GestureDetector(
        onTap: isReservedByOther
            ? null
            : () => _onItemTap(orderNumber, item, isSelected, selectedLocation),
        child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color.fromARGB(255, 253, 175, 214)
                  : (isReservedByOther ? Colors.grey : Colors.transparent),
              borderRadius: BorderRadius.circular(3.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 20, // Optional size control
                      height: 20, // Optional size control
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.help_outline,
                            color: Color.fromARGB(218, 255, 174, 0),
                            size: 20.0),
                        onPressed: () => _showOptionsDialog(context, item),
                      ),
                    ),
                    Text(displayItemKey,
                        style: const TextStyle(
                            fontSize: 16.0, fontWeight: FontWeight.bold)),
                    Text('|${item['units']}|',
                        style: const TextStyle(fontSize: 16.0)),
                    _buildItemLocation(context, item),
                  ],
                ),
                Text(itemDesc,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 12.0)),
                const Divider(color: Color.fromARGB(255, 29, 16, 16)),
              ],
            )),
      ),
    );
  }

  Widget _buildItemLocation(BuildContext context, Map<String, dynamic> item) {
    // Safely process 'loc' into a list of locations
    final List<String> locations =
        (item['loc'] != null && item['loc'] is String)
            ? (item['loc'] as String)
                .split(',')
                .map((loc) => loc.trim())
                .where((loc) => loc.isNotEmpty)
                .toList()
            : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: locations.map((loc) {
        // Extract location details from each 'loc'
        final row = loc.substring(3, 5);
        final side = loc.substring(5, 6);
        final column = loc.substring(6, 8);
        final sides = loc.substring(8, 9);
        final bin = (loc.length == 10 && loc.substring(9, 10) != '0')
            ? loc.substring(9, 10)
            : '';

        return Row(
          children: [
            Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              children: [
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Text(row, style: const TextStyle(fontSize: 16.0)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Text(side, style: const TextStyle(fontSize: 16.0)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child:
                          Text(column, style: const TextStyle(fontSize: 16.0)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child:
                          Text(sides, style: const TextStyle(fontSize: 16.0)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Text(bin, style: const TextStyle(fontSize: 16.0)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildBackButton(PickerProvider pickerProvider,
      Map<String, List<Map<String, dynamic>>> ordersByOrderNumber) {
    return Positioned(
      bottom: 16.0,
      left: 16.0,
      child: ElevatedButton(
        onPressed: () async {
          if (_selectedOrderAndItem != null) {
            try {
              final previousOrderAndItem = _selectedOrderAndItem!.split('-');
              final previousOrderNumber = previousOrderAndItem[0];
              final previousItemKey = previousOrderAndItem[1];

              // Find the corresponding item using order number and item key
              final List<Map<String, dynamic>>? orderItems =
                  ordersByOrderNumber[previousOrderNumber];

              if (orderItems != null) {
                final item = orderItems.firstWhere(
                  (item) => item['item'] == previousItemKey,
                  orElse: () => <String, Object>{},
                );

                final itemId = item['id'];
                await pickerProvider.setItemUnreserved(itemId);
              }
            } catch (e) {
              print('Error unreserving item $_selectedOrderAndItem: $e');
            }
          }
          Navigator.pushReplacementNamed(context, '/scanLocation');
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all<Color>(
              const Color.fromARGB(255, 66, 59, 59)),
        ),
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          child: SvgPicture.string(backIconString),
        ),
      ),
    );
  }

  Future<void> _loadUserId() async {
    currentUserId = await retrieveUserId();
    setState(() {});
  }

  Future<void> _initializeScan() async {
    await channel.invokeMethod('startScan');
    // Set up the MethodChannel to listen for intents
    channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'barcodeScanned') {
        final scannedUPC = call.arguments.toString();
        // Call scanAndArchiveItem when a barcode is scanned
        await scanAndArchiveItem(scannedUPC);
      }
    });
  }

  Future<void> scanAndArchiveItem(String scannedUPC) async {
    try {
      if (scannedUPC.isNotEmpty) {
        final pickerProvider =
            Provider.of<PickerProvider>(context, listen: false);
        final String username = await retrieveUsername();

        // Call findAndArchiveItemByUPC to check and archive the scanned item
        await pickerProvider.findAndArchiveItemByUPC(context, scannedUPC, '',
            username); // Pass empty orderNumber initially
      } else {
        print('No UPC scanned or scanning was canceled');
      }
    } catch (e) {
      print('Error during scan and archive process: $e');
    }
  }

  Future<void> _onItemTap(String orderNumber, Map<String, dynamic> item,
      bool isSelected, String selectedLocation) async {
    final pickerProvider = Provider.of<PickerProvider>(context, listen: false);
    final String itemKey = item['item'];
    final String orderAndItemKey = '$orderNumber-$itemKey';

    try {
      if (isSelected) {
        setState(() {
          _selectedOrderAndItem = null;
        });
        await pickerProvider.setItemUnreserved(item['id']);
      } else {
        if (_selectedOrderAndItem != null &&
            _selectedOrderAndItem != orderAndItemKey) {
          final previousOrderAndItem = _selectedOrderAndItem!.split('-');
          final previousOrderNumber = previousOrderAndItem[0];
          final previousItemKey = previousOrderAndItem[1];

          final previousItem = pickerProvider
              .ordersByOrderNumber[previousOrderNumber]
              ?.firstWhere((i) => i['item'] == previousItemKey,
                  orElse: () => <String, Object>{});

          if (previousItem != null) {
            await pickerProvider.setItemUnreserved(previousItem['id']);
          }
        }

        final String currentUserId = await retrieveUserId();

        setState(() {
          _selectedOrderAndItem = orderAndItemKey;
        });

        // Pass the selectedLocation here
        await pickerProvider.toggleItemReserved(
          context,
          orderNumber,
          item,
          int.parse(currentUserId),
          selectedLocation: selectedLocation,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Une erreur s'est produite, veuillez réessayer."),
        ),
      );
    }
  }

  void _showOptionsDialog(BuildContext context, Map<String, dynamic> item) {
    final scaffoldMessengerContext = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Choisir votre option:'),
          actions: <Widget>[
            TextButton(
              child: const Text('Barre code endommagé'),
              onPressed: () async {
                Navigator.of(dialogContext)
                    .pop(); // Use dialogContext to close the dialog

                final pickerProvider =
                    Provider.of<PickerProvider>(context, listen: false);

                // Retrieve the username from secure storage
                final String username = await retrieveUsername();

                final success = await pickerProvider.byPassScanItem(
                  context,
                  item['item'],
                  item['order_number'],
                  username,
                );

                scaffoldMessengerContext.showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Élément contourné et archivé avec succès.'
                        : "Échec du contournement et de l'archivage de l'élément."),
                  ),
                );
              },
            ),
            TextButton(
              child: const Text('Marquer comme manquant'),
              onPressed: () async {
                try {
                  final pickerProvider =
                      Provider.of<PickerProvider>(context, listen: false);

                  await pickerProvider.setItemMissing(item['id']);
                  setState(() {
                    // Update the list of orders and items
                    pickerProvider.ordersByOrderNumber[item['order_number']]
                        ?.removeWhere((i) => i['id'] == item['id']);

                    final allItemsMissing = pickerProvider
                            .ordersByOrderNumber[item['order_number']]
                            ?.every((i) => i['is_missing'] == true) ??
                        false;

                    if (allItemsMissing) {
                      pickerProvider.ordersByOrderNumber
                          .remove(item['order_number']);
                    } else if (pickerProvider
                            .ordersByOrderNumber[item['order_number']]
                            ?.isEmpty ??
                        false) {
                      pickerProvider.ordersByOrderNumber
                          .remove(item['order_number']);
                    }
                  });

                  Navigator.of(dialogContext).pop(); // Close the dialog
                } catch (e) {
                  scaffoldMessengerContext.showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Échec du marquage de l'élément comme manquant."),
                    ),
                  );
                  Navigator.of(dialogContext).pop(); // Ensure the dialog closes
                }
              },
            ),
          ],
        );
      },
    );
  }
}

// CLASSES ===============================================
class _OrderItemsHeader extends StatelessWidget {
  const _OrderItemsHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Text('Item',
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
        Text('Qté',
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
        Text('Localisation',
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
      ],
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
            image: AssetImage('assets/images/background_hp-red.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
