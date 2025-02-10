import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:superdeliver/models/transfer_items.dart';
import 'package:superdeliver/stores/store.dart';

class TransferProvider with ChangeNotifier {
  String apiUrl = '';

  TransferProvider(String apiUrlParam) {
    apiUrl = apiUrlParam;
  }

  // Fetch all transfers by store
  Future<List<TransferItem>> fetchTransfers(int store) async {
    final url = Uri.parse('$apiUrl/driver_transfer/transfers');
    final token = await retrieveTokenSecurely();
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Deliver-Auth': token,
      },
      body: jsonEncode({'store': store}),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => TransferItem.fromJson(json)).toList();
    } else if (response.statusCode == 400) {
      throw Exception('Store ID is required.');
    } else if (response.statusCode == 404) {
      throw Exception('No transfer items found for the specified store.');
    } else {
      throw Exception(
          'Failed to fetch transfers. Status code: ${response.statusCode}');
    }
  }

  // Fetch categorized transfers
  Future<Map<String, List<TransferItem>>> fetchCategorizedTransfers() async {
    final url = Uri.parse('$apiUrl/driver_transfer/transfers/categories');
    final token = await retrieveTokenSecurely();
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Deliver-Auth': token,
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data.map((key, value) {
        final List<TransferItem> items = (value as List<dynamic>)
            .map((json) => TransferItem.fromJson(json))
            .toList();
        return MapEntry(key, items);
      });
    } else if (response.statusCode == 404) {
      throw Exception('No transfers found.');
    } else {
      throw Exception(
          'Failed to fetch categorized transfers. Status code: ${response.statusCode}');
    }
  }

  // Fetch customer-specific transfers
  Future<List<TransferItem>> fetchCustomerTransfers(String customerId) async {
    final url = Uri.parse('$apiUrl/driver_transfer/transfers/customer_items');
    final token = await retrieveTokenSecurely();
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Deliver-Auth': token,
      },
      body: jsonEncode({'customer': customerId}),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => TransferItem.fromJson(json)).toList();
    } else if (response.statusCode == 404) {
      throw Exception('No transfer items found for the specified customer.');
    } else {
      throw Exception(
          'Failed to fetch customer transfers. Status code: ${response.statusCode}');
    }
  }

  // Archive a transfer item
  Future<bool> archiveTransferItem(String customerId, String upc) async {
    final url = Uri.parse('$apiUrl/driver_transfer/transfers/archive_item');
    final token = await retrieveTokenSecurely();
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Deliver-Auth': token,
      },
      body: jsonEncode({
        'customer': customerId,
        'upc': upc,
      }),
    );

    if (response.statusCode == 200) {
      notifyListeners();
      return true;
    } else if (response.statusCode == 404) {
      throw Exception('Transfer item not found or already archived.');
    } else {
      throw Exception(
          'Failed to archive item. Status code: ${response.statusCode}');
    }
  }

  // Bypass batch scan
  Future<bool> bypassBatchScan(String customerId, String upc) async {
    final url =
        Uri.parse('$apiUrl/driver_transfer/transfers/bypass_batch_scan');
    final token = await retrieveTokenSecurely();
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Deliver-Auth': token,
      },
      body: jsonEncode({
        'customer': customerId,
        'upc': upc,
      }),
    );

    if (response.statusCode == 200) {
      notifyListeners();
      return true;
    } else if (response.statusCode == 404) {
      throw Exception('Transfer item not found or already archived.');
    } else {
      throw Exception(
          'Failed to bypass batch scan. Status code: ${response.statusCode}');
    }
  }
}
