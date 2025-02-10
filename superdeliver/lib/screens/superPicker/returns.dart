import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/providers/picker_provider.dart';
import 'package:superdeliver/variables/svg.dart';

class ReturnScreen extends StatefulWidget {
  const ReturnScreen({Key? key}) : super(key: key);

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  late PickerProvider _pickerProvider;
  static const MethodChannel channel = MethodChannel('datawedge');
  bool _isScanning = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pickerProvider = Provider.of<PickerProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickerProvider.fetchReturnItems();
      _pickerProvider.startPeriodicReturnRefresh();
      _initializeScan();
    });
  }

  // Initialize DataWedge scanning
  Future<void> _initializeScan() async {
    try {
      await channel.invokeMethod('startScan');

      channel.setMethodCallHandler((MethodCall call) async {
        print('[DEBUG] Method call from platform: ${call.method}');
        print('[DEBUG] Arguments: ${call.arguments}');

        if (call.method == 'barcodeScanned') {
          final scannedUPC = call.arguments.toString();
          print('[DEBUG] scannedUPC: $scannedUPC');
          await scanAndArchiveItem(scannedUPC);
        }
      });
    } catch (e) {
      print('Error initializing scan: $e');
    }
  }

  Future<void> scanAndArchiveItem(String scannedUPC) async {
    if (_isScanning) return;

    try {
      setState(() => _isScanning = true);

      if (scannedUPC.isEmpty) {
        _showMessage('No UPC scanned', isError: true);
        return;
      }

      print('[DEBUG] Searching for UPC: $scannedUPC');

      // Find the item by checking UPC in either array or single value
      final itemIndex = _pickerProvider.returnItems.indexWhere((item) {
        final itemUPC = item['upc'];
        if (itemUPC is List) {
          return itemUPC.contains(scannedUPC);
        } else {
          return itemUPC.toString() == scannedUPC;
        }
      });

      if (itemIndex == -1) {
        _showMessage('Item not found in returns list', isError: true);
        return;
      }

      final item = _pickerProvider.returnItems[itemIndex];
      final locFromItem = (item['loc'] ?? '').toString();

      print('[DEBUG] Found item: ${item['item']} at location: $locFromItem');

      // Archive the item
      final responseData = await _pickerProvider.archiveReturnItem(
        upc: scannedUPC,
        loc: locFromItem,
      );

      final status = responseData['status'] as String?;
      final message = responseData['message'] as String?;

      if (status == 'success') {
        // Update the local state
        if (mounted) {
          final currentUnits = int.parse(item['units'].toString());
          if (currentUnits > 0) {
            // Calculate new units count
            final newUnits = currentUnits - 1;

            if (newUnits == 0) {
              // If no units left, remove the item from the list
              setState(() {
                _pickerProvider.returnItems.removeAt(itemIndex);
              });
            } else {
              // Otherwise update the units count
              final updatedItem = Map<String, dynamic>.from(item);
              updatedItem['units'] = newUnits.toString();
              setState(() {
                _pickerProvider.returnItems[itemIndex] = updatedItem;
              });
            }
          }
        }
        _showMessage(message ?? 'Item archived successfully');
      } else if (status == 'already_archived') {
        _showMessage(message ?? 'Item was already archived');
      } else {
        _showMessage('Unknown response status: $status', isError: true);
      }
    } catch (e) {
      print('[DEBUG] Error in scanAndArchiveItem: $e');
      _showMessage('Error processing scan: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildBackButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.pushReplacementNamed(context, '/scanLocation');
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all<Color>(
          const Color.fromARGB(255, 66, 59, 59),
        ),
      ),
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        child: SvgPicture.string(backIconString),
      ),
    );
  }

  @override
  void dispose() {
    _pickerProvider.stopPeriodicRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_yellow-green.png',
              fit: BoxFit.cover,
            ),
          ),
          // White container for listing items
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(
                      bottom: 70.0,
                      top: 30.0,
                      right: 15.0,
                      left: 15.0,
                    ),
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
                    child: Consumer<PickerProvider>(
                      builder: (context, provider, child) {
                        if (provider.returnItems.isEmpty) {
                          return const Center(
                            child: Text(
                              'No returns available',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.returnItems.length,
                          itemBuilder: (context, index) {
                            final item = provider.returnItems[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              child: ListTile(
                                title: Text(
                                  item['item'] ?? 'Unknown Item',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.inventory_2, size: 16),
                                        const SizedBox(width: 4),
                                        Text('Units: ${item['units'] ?? '0'}'),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.location_on, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Location: ${item['loc'] ?? 'Unknown'}',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Back button positioned at the bottom
          Positioned(
            bottom: 16.0,
            left: 16.0,
            child: _buildBackButton(),
          ),
          // Scanning status indicator
          if (_isScanning)
            Positioned(
              top: 40.0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.black54,
                child: const Text(
                  'Processing scan...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
