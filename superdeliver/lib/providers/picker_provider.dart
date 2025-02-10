import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:superdeliver/stores/store.dart';
import 'package:superdeliver/widget/alerts.dart';

class PickerProvider with ChangeNotifier {
  String apiUrl = '';
  String? currentStoreId;
  String? highlightedItemId;
  int? currentLevel;
  Map<String, List<Map<String, dynamic>>> ordersByOrderNumber = {};
  Timer? _refreshTimer; // Timer to handle periodic refresh
  Timer? _refreshTimer2; // Timer to handle periodic refresh
  Map<String, List<Map<String, dynamic>>> groupedItems = {};
  // Constructor that initializes the API URL and starts the initialization process
  PickerProvider(String apiUrlParam) {
    apiUrl = apiUrlParam;
  }

  // API call to fetch all localisations
  // Fetch and group items by order_number
  Future<void> fetchAllLocalisations(String storeId) async {
    currentStoreId = await retrieveStoreId();

    if (currentStoreId == null || currentStoreId!.isEmpty) {
      _handleError(Exception('No Store ID'), 'Store ID is null or empty');
      return;
    }

    final url = Uri.parse('$apiUrl/picker/get_all_localisation');
    final headers = {'Content-Type': 'application/json'};
    final body = json.encode({'store': currentStoreId});

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Map<String, List<Map<String, dynamic>>> freshOrders = {};

        for (var item in data) {
          String orderNumber = item['order_number'];

          if (data
              .where((element) =>
                  element['order_number'] == orderNumber &&
                  element['is_archived'] != true &&
                  element['is_missing'] != true)
              .isEmpty) {
            continue;
          }

          // Add the item to the fresh orders map
          freshOrders.putIfAbsent(orderNumber, () => []).add(item);
        }

        // Replace the current orders by the fresh orders
        ordersByOrderNumber.clear(); // Clear existing orders
        ordersByOrderNumber.addAll(freshOrders); // Replace with new data

        safeNotifyListeners(); // Notify listeners to update UI
      } else if (response.statusCode == 404) {
        ordersByOrderNumber.clear();
        safeNotifyListeners();
      } else {
        _handleError(Exception('Failed request'), 'Failed to fetch orders');
      }
    } catch (e) {
      _handleError(e, 'Error fetching orders');
    }
  }

  // Method to fetch picking orders by level
  Future<void> fetchPickingOrdersByLevel(int level) async {
    currentLevel = level;
    currentStoreId = await retrieveStoreId();

    const secureStorage = FlutterSecureStorage();
    final userId = await secureStorage.read(key: 'userId');

    if (currentStoreId == null || currentStoreId!.isEmpty) {
      _handleError(Exception('No Store ID'), 'Store ID is null or empty');
      return;
    }

    final url = Uri.parse('$apiUrl/picker/get_picking_orders/$userId');
    final headers = {'Content-Type': 'application/json'};
    final body = json.encode({
      'store': currentStoreId,
      'level': level == -1 ? "-1" : level.toString()
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        ordersByOrderNumber.clear();

        for (var item in data) {
          String orderNumber = item['order_number'];

          // Skip adding the order if all items have is_missing = true
          if (data
              .where((element) =>
                  element['order_number'] == orderNumber &&
                  element['is_missing'] != true)
              .isEmpty) {
            continue;
          }

          // Add the item if the order should be rendered
          ordersByOrderNumber.putIfAbsent(orderNumber, () => []).add(item);
        }

        safeNotifyListeners();
      } else if (response.statusCode == 404) {
        ordersByOrderNumber.clear();
        safeNotifyListeners();
      } else {
        _handleError(Exception('Failed request'), 'Failed to fetch orders');
      }
    } catch (e) {
      _handleError(e, 'Error fetching orders');
    }
  }

  // Safe notifyListeners method to ensure that the provider is still mounted
  void safeNotifyListeners() {
    notifyListeners();
  }

  // Method to start the periodic refresh
  void startPeriodicRefresh(int level) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchPickingOrdersByLevel(level);
    });
  }

  // Stop the periodic refresh
  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // Periodic refresh function for another timer
  void startPeriodicRefresh2(String storeId) {
    _refreshTimer2?.cancel();
    _refreshTimer2 = Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchAllLocalisations(storeId);
    });
  }

  // Cancel the second periodic refresh
  void stopPeriodicRefresh2() {
    _refreshTimer2?.cancel();
    _refreshTimer2 = null;
  }

  // Dispose method to clean up timers and mark provider as unmounted
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer2?.cancel();
    super.dispose();
  }

  Future<void> toggleItemReserved(
    BuildContext context,
    String orderNumber,
    Map<String, dynamic> item,
    int userId, {
    required String selectedLocation,
  }) async {
    try {
      final response =
          await http.post(Uri.parse('$apiUrl/picker/set_to_reserved'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'data': {
                  'id': item['id'],
                  'order_number': orderNumber,
                  'loc': selectedLocation,
                  'upc': item['upc'],
                },
                'user_id': userId,
              }));

      if (response.statusCode == 200) {
        highlightedItemId = item['id'].toString();
        safeNotifyListeners();
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['debug_info'] ?? errorData['detail'] ?? 'Unknown error';
        alert(context, errorMessage, SnackBarType.alert);
      }
    } catch (e) {
      alert(context, 'Error: ${e.toString()}', SnackBarType.alert);
    }
  }

  Future<void> updateItemStatus(
      int itemId, String endpoint, Map<String, dynamic> updatedFields) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/picker/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': itemId}),
      );

      if (response.statusCode == 200) {
        print('Item $itemId successfully updated');
      } else {
        print('Item $itemId Errur');
      }
    } catch (e) {
      print('Error updating item $itemId: $e');
    }
  }

  Future<void> setItemUnreserved(int itemId) async {
    await updateItemStatus(
        itemId, 'unreserved', {'is_reserved': false, 'reserved_by': null});
  }

  Future<void> setItemMissing(int itemId) async {
    await updateItemStatus(itemId, 'is_missing', {'is_missing': true});
  }

  Future<bool> findAndArchiveItemByUPC(BuildContext context, String upc,
      String orderNumber, String pickedBy) async {
    try {
      // Retrieve the storeId from secure storage
      const secureStorage = FlutterSecureStorage();
      String? storeId = await secureStorage.read(key: 'storeId');

      if (storeId == null) {
        alert(context, "Store ID not found. Please log in again.",
            SnackBarType.error);
        return false;
      }

      // Call the find_item_by_upc API
      final response = await http.post(
        Uri.parse('$apiUrl/picker/find_item_by_upc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'upc': upc, 'store': int.parse(storeId)}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> item = json.decode(response.body);
        final String itemOrderNumber = item['order_number'];
        final List<Map<String, dynamic>> items =
            ordersByOrderNumber[itemOrderNumber] ?? [];

        // Format storeId to match loc's expected leading digits
        String storePrefix =
            storeId.padLeft(2, '0'); // Ensures it has two digits (e.g., 01, 02)

        // Validate that the loc field starts with the correct store prefix
        String loc = item['loc'] ?? '';
        if (!loc.startsWith(storePrefix)) {
          alert(context, "L'article n'appartient pas à ce magasin.",
              SnackBarType.error);
          return false;
        }

        // Proceed to archive the item
        final success = await archiveItemByUPC(upc, itemOrderNumber, pickedBy,
            item: item, items: items);
        return success;
      } else {
        alert(context, "Article non trouvé par CPU", SnackBarType.error);
        return false;
      }
    } catch (e) {
      alert(context, "Erreur de recherche et d'archivage de l'élément: $e",
          SnackBarType.error);
      return false;
    }
  }

  Future<bool> archiveItemByUPC(String upc, String orderNumber, String pickedBy,
      {required Map<String, dynamic> item,
      required List<Map<String, dynamic>> items}) async {
    try {
      if (items.isEmpty) {
        return false;
      }

      Map<String, dynamic>? itemToArchive;

      for (var item in items) {
        final upcField = item['upc'];
        List<String> upcList = [];

        // Parse the upcField appropriately
        if (upcField is String) {
          if (upcField.startsWith('[') && upcField.endsWith(']')) {
            // Replace single quotes with double quotes for valid JSON parsing
            String jsonString = upcField.replaceAll("'", '"');
            try {
              upcList = List<String>.from(json.decode(jsonString));
            } catch (e) {
              continue; // Skip this item if parsing fails
            }
          } else {
            upcList = [upcField];
          }
        } else if (upcField is List) {
          upcList = upcField.map((e) => e.toString()).toList();
        } else {
          continue;
        }

        // Check if the scanned UPC exists in the upcList
        if (upcList.contains(upc)) {
          itemToArchive = item;
          break; // Exit loop once matching item is found
        }
      }

      // Check if a matching item was found
      if (itemToArchive == null) {
        return false;
      }

      // Prepare the request body for archiving
      final requestBody = jsonEncode({
        'id': itemToArchive['id'],
        'upc': upc,
        'order_number': orderNumber,
        'picked_by': pickedBy,
      });

      // Send the POST request to archive the item
      final response = await http.post(
        Uri.parse('$apiUrl/picker/pick_item_by_upc'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      // Check the response status
      if (response.statusCode == 200) {
        // Successful API call, now update local state based on the backend's logic
        itemToArchive['units'] = itemToArchive['units'] != null
            ? (itemToArchive['units'] as int) - 1
            : 0;

        // If the item is now archived, update its status
        if (itemToArchive['units'] <= 0) {
          items.removeWhere((i) => i['id'] == itemToArchive!['id']);
        }

        if (items.isEmpty) {
          ordersByOrderNumber.remove(orderNumber);
        }

        safeNotifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> byPassScanItem(
    BuildContext context,
    String item,
    String orderNumber,
    String pickedBy,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/picker/by_pass_item_scan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'item': item,
          'order_number': orderNumber,
          'picked_by': pickedBy,
        }),
      );

      if (response.statusCode == 200) {
        final List<Map<String, dynamic>>? items =
            ordersByOrderNumber[orderNumber];

        if (items != null) {
          // Remove the bypassed item from the local list
          items.removeWhere((i) => i['item'] == item);

          // If all items in the order are processed, remove the order
          if (items.isEmpty) {
            ordersByOrderNumber.remove(orderNumber);
          }

          safeNotifyListeners();
        }

        return true;
      } else {
        alert(context, "Article non trouvé par CPU", SnackBarType.error);
        return false;
      }
    } catch (e) {
      print('Error in byPassScanItem: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> returnItems = [];

  Future<void> fetchReturnItems() async {
    currentStoreId = await retrieveStoreId();

    if (currentStoreId == null || currentStoreId!.isEmpty) {
      _handleError(Exception('No Store ID'), 'Store ID is null or empty');
      return;
    }

    final url = Uri.parse('$apiUrl/v2/get_returns');
    final headers = {'Content-Type': 'application/json'};
    final body = json.encode({'store': currentStoreId});

    try {
      // Clear old items before fetching
      returnItems.clear();
      notifyListeners();

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        returnItems = List<Map<String, dynamic>>.from(data);
        notifyListeners(); // Notify UI about the updated state
      } else if (response.statusCode == 404) {
        // Handle "no items" case: clear the list and notify
        returnItems.clear();
        notifyListeners();
      } else {
        // Handle unexpected status codes
        _handleError(
            Exception('Failed request with status: ${response.statusCode}'),
            'Failed to fetch return items');
      }
    } catch (e) {
      _handleError(e, 'Error fetching return items');
    }
  }

  Future<Map<String, dynamic>> archiveReturnItem({
    required String upc,
    required String loc, // <-- Accept loc as well
  }) async {
    currentStoreId = await retrieveStoreId();
    if (currentStoreId == null || currentStoreId!.isEmpty) {
      throw Exception('Store ID is null or empty');
    }

    final url = Uri.parse('$apiUrl/v2/archive_returns_item');
    final headers = {'Content-Type': 'application/json'};

    // Include store, upc, and loc in the request body
    final body = json.encode({
      'store': currentStoreId,
      'loc': loc,
      'upc': upc,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Handle success
        final remainingUnits = responseData['remaining_units'] as int;
        final isArchived = remainingUnits == 0;

        // Find and update the item in the local list
        final itemIndex = returnItems.indexWhere((item) => item['upc'] == upc);
        if (itemIndex != -1) {
          if (isArchived) {
            // Remove the item if it's archived (remaining_units == 0)
            returnItems.removeAt(itemIndex);
          } else {
            // Update the units
            returnItems[itemIndex]['units'] = remainingUnits;
          }
          safeNotifyListeners();
        }

        return responseData;
      } else if (response.statusCode == 404) {
        throw Exception('Item not found');
      } else {
        throw Exception('Failed to archive item: ${responseData['detail']}');
      }
    } catch (e) {
      _handleError(e, 'Error archiving return item');
      rethrow;
    }
  }

  void decrementItemUnits(String upc) {
    final itemIndex = returnItems
        .cast<Map<String, dynamic>>()
        .indexWhere((element) => element['upc'].toString() == upc);

    if (itemIndex != -1) {
      final item = returnItems[itemIndex];
      final currentUnits = int.parse(item['units'].toString());

      if (currentUnits > 0) {
        // Create a new map with updated units
        final updatedItem = Map<String, dynamic>.from(item);
        updatedItem['units'] = (currentUnits - 1).toString();

        // Update the item in the list
        returnItems[itemIndex] = updatedItem;

        // Notify listeners is called within the provider class
        notifyListeners();
      }
    }
  }

  void updateReturnItem(int index, Map<String, dynamic> updatedItem) {
    if (index >= 0 && index < returnItems.length) {
      returnItems[index] = updatedItem;
      notifyListeners();
    }
  }

  // Method to start periodic refresh for returns
  void startPeriodicReturnRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      fetchReturnItems();
    });
  }

  // Error handler for logging errors
  void _handleError(Object error, String message) {
    if (kDebugMode) {
      print('$message: $error');
    }
  }
}
