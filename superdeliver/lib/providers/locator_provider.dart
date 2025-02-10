import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:superdeliver/stores/store.dart';

class LocatorProvider with ChangeNotifier {
  String apiUrl = '';

  LocatorProvider(String apiUrlParam) {
    apiUrl = apiUrlParam;
  }

  Future<Map<String, dynamic>> fetchProductLocations(String upc) async {
    final url = Uri.parse('$apiUrl/picker/upclocations');
    final headers = {'Content-Type': 'application/json'};

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'upc': upc}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Group locations by count
        final List<String> locations =
            data['full_locations']?.cast<String>() ?? [];
        final Map<String, int> locationCounts = {};

        for (var location in locations) {
          locationCounts[location] = (locationCounts[location] ?? 0) + 1;
        }

        // Convert to a list of "location:count" format
        final List<String> groupedLocations =
            locationCounts.entries.map((entry) {
          return entry.value > 1
              ? '${entry.key} (count: ${entry.value})'
              : entry.key;
        }).toList();

        return {
          'status': response.statusCode,
          'data': groupedLocations,
        };
      } else {
        _handleError(Exception('Failed to fetch product locations'),
            'Failed to fetch product locations');
        return {
          'status': response.statusCode,
          'error': json.decode(response.body)['detail'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      _handleError(e, 'Error fetching product locations');
      return {'status': 503, 'error': e.toString()};
    }
  }

  Future<bool> checkNewOrders(level) async {
    final url = Uri.parse('$apiUrl/locator/get_new_order');
    final headers = {'Content-Type': 'application/json'};
    final storeId = await retrieveStoreId();
    final body = json.encode({'store_id': int.parse(storeId), 'level': level});
    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final bool data = json.decode(response.body);
        return data;
      } else {
        _handleError(Exception('Failed request'), 'Failed to fetch orders');
      }
    } catch (e) {
      _handleError(e, 'Error fetching orders');
    }
    return false;
  }

  Future<Map<String, dynamic>> fetchItem(String upc) async {
    final storeId = await retrieveStoreId();

    // First, fetch the item details
    final itemUrl = Uri.parse('$apiUrl/locator/get_info');
    try {
      final itemResponse = await http.post(
        itemUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"upc": upc, "store": storeId}),
      );

      if (itemResponse.statusCode == 200) {
        final Map<String, dynamic> itemData =
            json.decode(itemResponse.body)['data'];

        // Now, fetch locations for the UPC
        final locationResponse = await fetchProductLocations(upc);

        if (locationResponse['status'] == 200) {
          itemData['locations'] =
              locationResponse['data']; // Add locations to item data
        } else {
          itemData['locations'] = ["No locations available"];
        }

        return {
          "status": itemResponse.statusCode,
          "data": itemData,
        };
      } else {
        _handleError(
            Exception('Failed request'), 'Failed to fetch item details');
        return {'status': 204, "error": itemResponse.body};
      }
    } catch (e) {
      _handleError(e, 'Error fetching item');
      return {"status": 503, "error": e.toString()};
    }
  }

  Future<Map<String, dynamic>> setLocalisation({
    required List<String> upc,
    required List<String> name,
    required String updatedBy,
    required String loc,
    required bool archive,
    int quantity = 1,
  }) async {
    final url = Uri.parse('$apiUrl/locator/set_localisation');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'upc': upc,
          'name': name,
          'updated_by': updatedBy,
          'loc': loc,
          'archive': archive,
          'quantity': quantity,
        }),
      );

      Map<String, dynamic> res = {"status": response.statusCode};

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle successful response if needed
        print(response.body);
      } else {
        _handleError(Exception('Failed to set localisation'),
            'Failed to set localisation');

        // Try to decode the response body
        try {
          res["error"] = jsonDecode(response.body)['detail'];
        } catch (e) {
          res["error"] = 'Unknown error';
        }
      }

      return res;
    } catch (e) {
      _handleError(e, 'Error setting localisation');
      return {"status": 503, "error": e.toString()};
    }
  }

  // Error handler for logging errors
  void _handleError(Object error, String message) {
    if (kDebugMode) {
      print('$message: $error');
    }
  }
}
