import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:superdeliver/models/transfer_items.dart';
import 'package:superdeliver/providers/transfer_provider.dart';

class TransferPage extends StatefulWidget {
  final String customerId;
  final TransferProvider transferProvider;

  const TransferPage({
    super.key,
    required this.customerId,
    required this.transferProvider,
  });

  @override
  _TransferPageState createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  late Future<List<TransferItem>> _futureTransfers;
  static const MethodChannel _channel = MethodChannel('datawedge');

  @override
  void initState() {
    super.initState();
    _fetchTransfers();
    _initializeScanner();
  }

  void _fetchTransfers() {
    setState(() {
      _futureTransfers =
          widget.transferProvider.fetchCustomerTransfers(widget.customerId);
    });
  }

  void _initializeScanner() {
    _channel.invokeMethod('startScan');
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'barcodeScanned') {
        final scannedUPC = call.arguments.toString();
        await _scanAndProcessItem(scannedUPC);
      }
    });
  }

  Future<void> _scanAndProcessItem(String scannedUPC) async {
    try {
      // Call the archiveTransferItem function
      final success = await widget.transferProvider.archiveTransferItem(
        widget.customerId,
        scannedUPC,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item processed successfully.')),
        );
        _fetchTransfers(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process the item.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _bypassScan(TransferItem transfer) async {
    try {
      final success = await widget.transferProvider.bypassBatchScan(
        widget.customerId,
        transfer.upc ?? '',
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Item bypassed and archived successfully.')),
        );
        _fetchTransfers(); // Refresh the list
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error bypassing scan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transfers - ${widget.customerId}'),
      ),
      body: FutureBuilder<List<TransferItem>>(
        future: _futureTransfers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          } else {
            return _buildTransferList(snapshot.data!);
          }
        },
      ),
    );
  }

  void _showBypassPrompt(BuildContext context, TransferItem transfer) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Voulez-vous bypass scan l\'item?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _bypassScan(transfer);
              },
              child: const Text('Oui'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80.0,
            color: Colors.red,
          ),
          const SizedBox(height: 16.0),
          Text(
            'Error: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18.0, color: Colors.red),
          ),
          const SizedBox(height: 24.0),
          ElevatedButton(
            onPressed: _fetchTransfers,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.transfer_within_a_station,
            size: 80.0,
            color: Colors.grey,
          ),
          SizedBox(height: 16.0),
          Text(
            'No transfer details available!',
            style: TextStyle(fontSize: 18.0, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferList(List<TransferItem> transfers) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: ListTile(
            leading: IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showBypassPrompt(context, transfer),
            ),
            title: Text(
              transfer.item ?? "Unknown item",
              style:
                  const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              transfer.description ?? 'No description available',
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Text(
              'Qty: ${transfer.qtySellingUnits}',
              style: const TextStyle(fontSize: 14.0),
            ),
          ),
        );
      },
    );
  }
}
