import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:superdeliver/models/order_details.dart';
import 'package:superdeliver/stores/store.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:superdeliver/widget/alerts.dart';

class OrderProvider with ChangeNotifier {
  List<Order> orders = [];
  String apiUrl = '';
  bool isInitialized = false;
  late String currentDriverId;
  late String currentStoreId;
  late String currentRoute = '0-0';
  late GeoCoordinates _storeCoordinates;
  Map<String, GeoCoordinates> storeCoordinatesMap = {};

  String get driverId => currentDriverId;
  String get storeId => currentStoreId;
  GeoCoordinates get storeCoordinates => _storeCoordinates;

  int getOrderCount() => orders.length;

  OrderProvider(String apiUrlParam, BuildContext context) {
    apiUrl = apiUrlParam;
    initialize(context);
  }

  Future<void> initialize(BuildContext context) async {
    try {
      currentDriverId = await retrieveDriverId();
      currentStoreId = await retrieveStoreId();
      await Future.wait([
        fetchCurrentRoute(context),
        fetchStoreCoordinates(context),
      ]);
      isInitialized = true;
      notifyListeners();
    } catch (e) {
      _handleError(e, 'Error during Initialization');
    }
  }

  void setRouteStarted(bool value, BuildContext context) async {
    for (var order in orders) {
      order.route_started = value;
      // Update the route_started field in the database
      await updateRouteStartedInDB(order.route, value, context);
    }
    notifyListeners();
  }

  Future<GeoCoordinates> fetchOrGenerateCoordinates(
      BuildContext context, String orderNumber, int? job) async {
    final url = Uri.parse('$apiUrl/v2/get_long_lat_or_create');
    final headers = {'Content-Type': 'application/json'};

    // Ensure job is always defined, defaulting to 0 if null
    final body = json.encode({
      'order_number': orderNumber,
      'job': job ?? 0 // Default to 0 if job is null
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latitude = data['latitude'] as double;
        final longitude = data['longitude'] as double;
        return GeoCoordinates(latitude, longitude);
      } else {
        final errorDetail = json.decode(response.body)['detail'];
        throw Exception('Failed to fetch coordinates: $errorDetail');
      }
    } catch (e) {
      print('Error fetching coordinates: $e'); // Add logging
      throw Exception('Error fetching coordinates: $e');
    }
  }

  Future<void> updateRouteStartedInDB(
      String route, bool routeStarted, BuildContext context) async {
    final token = await retrieveTokenSecurely();
    final url = Uri.parse('$apiUrl/driver_order/update_route_started');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Deliver-Auth': token,
        },
        body: json.encode({
          'route': route,
          'route_started': routeStarted,
        }),
      );

      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return;
      }
      if (response.statusCode != 200) {
        throw Exception('Failed to update route_started in the database');
      }
    } catch (e) {
      _handleError(e, 'Error updating route_started in the database');
    }
  }

  Future<String> fetchCurrentRoute(BuildContext context) async {
    final url = Uri.parse(
        '$apiUrl/driver_order/get_routes_order?driver_id=$currentDriverId');
    final token = await retrieveTokenSecurely();

    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'X-Deliver-Auth': token,
      });

      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return '0-0';
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        currentRoute = data['route'];
      }
    } catch (e) {
      _handleError(e, 'Error fetching current route');
    }
    return ''; // Return empty string to end the completion
  }

  Future<void> fetchStoreCoordinates(BuildContext context) async {
    final url = Uri.parse('$apiUrl/store_coordinates');
    try {
      final response = await http.get(url);
      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return;
      }
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final coordinates = data['coordinates'] as Map<String, dynamic>;

        storeCoordinatesMap = coordinates.map((key, value) {
          final parts = value.split(',');
          return MapEntry(
            key,
            GeoCoordinates(double.parse(parts[0]), double.parse(parts[1])),
          );
        });

        _storeCoordinates = storeCoordinatesMap[currentStoreId] ??
            (throw Exception('Store ID not found'));
      } else {
        throw Exception('Failed to fetch store coordinates');
      }
    } catch (e) {
      _handleError(e, 'Error fetching store coordinates');
    }
  }

  Future<String> fetchLatestRouteName(
      BuildContext context, bool useDriver) async {
    final url = Uri.parse(
        '$apiUrl/driver_order/get_latest_route${useDriver ? '?driver_id=$currentDriverId' : ''}');
    final token = await retrieveTokenSecurely();

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Deliver-Auth': token,
        },
        body: jsonEncode({'driver_id': currentDriverId}),
      );

      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return currentRoute;
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['latest_route'].toString();
      } else {
        throw Exception('Failed to fetch latest route number');
      }
    } catch (e) {
      _handleError(e, 'Error fetching latest route number');
      return currentRoute;
    }
  }

  Future<bool> startRoute(BuildContext context) async {
    final url = Uri.parse('$apiUrl/driver_order/start_route');
    final token = await retrieveTokenSecurely();

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Deliver-Auth': token,
        },
        body: json.encode({'route': currentRoute}),
      );

      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return false;
      }

      if (response.statusCode == 200) {
        orders.forEach((order) => order.route_started = true);
        notifyListeners();
        return true;
      } else {
        _handleError(response.body, 'Failed to start route');
        return false;
      }
    } catch (e) {
      _handleError(e, 'Error starting route');
      return false;
    }
  }

  Future<void> reorderOrders(
      BuildContext context, int oldIndex, int newIndex, String driverId) async {
    final order = orders.removeAt(oldIndex);
    orders.insert(newIndex, order);
    notifyListeners();

    final reorderedOrders = orders
        .asMap()
        .entries
        .map((entry) => {
              'order_number': entry.value.order_number,
              'new_index': entry.key + 1,
            })
        .toList();

    final url = Uri.parse('$apiUrl/driver_order/reorder_driver_orders');
    final token = await retrieveTokenSecurely();

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Deliver-Auth': token,
          'X-Driver-Id': driverId,
        },
        body: json.encode(reorderedOrders),
      );
      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return;
      }
      if (response.statusCode != 200) {
        throw Exception('Failed to reorder orders: ${response.body}');
      }
    } catch (e) {
      _handleError(e, 'Error reordering orders');
    }
  }

  void redirectToScanIfNoOrders(BuildContext context) async {
    if (!isInitialized) {
      await fillOrderAndRedirectWhenArrived(context);
      isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> initializeOrders(BuildContext context) async {
    final response = await fetchDriverOrders(context);
    if (response.statusCode == 200) {
      orders = await processOrders(response, context);
      notifyListeners(); // Update the UI after fetching orders
    } else {
      showErrorSnackBar(context, response);
    }
  }

  Order getCurrentOrderCopy(BuildContext context) {
    if (orders.isEmpty) {
      redirectToScanIfNoOrders(context);
      return _getEmptyOrder();
    }
    return orders.first;
  }

  Order getOrderCopyByOrderNumber(String orderNumber) {
    return orders.firstWhere(
      (order) => order.order_number == orderNumber,
      orElse: () => _getEmptyOrder(),
    );
  }

  Item getItemCopyByPartNumber(String orderNumber, String partNumber) {
    return getOrderCopyByOrderNumber(orderNumber)
        .orderInfo
        .firstWhere((item) => item.part_number == partNumber);
  }

  Order getOrderCopyAt(int index) => orders[index];

  bool getItemScanState(String orderNumber, String partNumber) {
    return getItemCopyByPartNumber(orderNumber, partNumber).num_scanned >=
        getItemCopyByPartNumber(orderNumber, partNumber).units;
  }

  bool getItemConfirmationState(String orderNumber, String partNumber) {
    return getItemCopyByPartNumber(orderNumber, partNumber).confirmed_scanned >=
        getItemCopyByPartNumber(orderNumber, partNumber).units;
  }

  bool areAllOrdersComplete() {
    return orders.every((order) => isOrderComplete(order.order_number));
  }

  bool isOrderComplete(String orderNumber) {
    return orders.any((order) =>
        order.order_number == orderNumber &&
        order.orderInfo.every((item) => item.num_scanned >= item.units));
  }

  bool isOrderConfirmed(BuildContext context) {
    return orders.any((order) =>
        order.order_number == getCurrentOrderCopy(context).order_number &&
        order.orderInfo.every((item) => item.confirmed_scanned >= item.units));
  }

  String getCurrentOrderFormattedAddressCopy(BuildContext context) {
    String address = getCurrentOrderCopy(context).address;
    List<String> parts = address.split(',');
    return parts.length >= 3
        ? parts.sublist(0, parts.length - 2).join(',')
        : address;
  }

  Future<void> showSnackBar(BuildContext context, String message) async {
    if (context.mounted) {
      final mediaQueryData = MediaQuery.maybeOf(context);
      double bottomMargin = 50.0;

      if (mediaQueryData != null) {
        bottomMargin = mediaQueryData.size.height / 2 - 24;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: bottomMargin, left: 12, right: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      );
    }
  }

  Future<void> fillOrderAndRedirectWhenArrived(BuildContext context) async {
    try {
      final response = await fetchDriverOrders(context);

      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return;
      }

      if (response.statusCode == 200) {
        orders = await processOrders(response, context);
        if (orders.isNotEmpty) currentRoute = orders.first.route;
        notifyListeners();
        _handleRedirection(context);
      } else {
        showErrorSnackBar(context, response);
      }
    } catch (e) {
      handleError(e, 'Error fetching orders', context);
    }
  }

  Future<http.Response> fetchDriverOrders(BuildContext context) async {
    final token = await retrieveTokenSecurely();
    final url = Uri.parse('$apiUrl/driver_order/get_driver_orders');
    final response = await http.get(url, headers: {'X-Deliver-Auth': token});

    if (response.statusCode == 401) {
      _handleUnauthorized(context);
    }

    return response;
  }

  Future<List<Order>> processOrders(
      http.Response response, BuildContext context) async {
    try {
      final data = json.decode(utf8.decode(response.bodyBytes));
      print(data);
      return (data as List).map((json) => Order.fromJson(json)).toList();
    } catch (e) {
      print('Error parsing data: $e'); // Debugging
      await showSnackBar(context, 'Error parsing order data');
      throw e;
    }
  }

  void showErrorSnackBar(BuildContext context, http.Response response) {
    final errorMsg = 'Error: ${response.statusCode} ${response.reasonPhrase}';
    showSnackBar(context, errorMsg);
  }

  void handleError(Object e, String message, BuildContext context) async {
    _handleError(e, message);
    await showSnackBar(context, message);
  }

  Future<void> addOrderBasedOnBarcode(
      BuildContext context, String barcode) async {
    final token = await retrieveTokenSecurely();
    final url = Uri.parse('$apiUrl/driver_order/set_driver_order');
    String latestRouteName = await fetchLatestRouteName(context, true);
    String currentRouteNumber = await fetchCurrentRoute(context);
    currentRouteNumber = currentRoute.split('-').last;

    if (currentRouteNumber == latestRouteName) {
      final newRouteNumber = latestRouteName.split('-').last;
      currentRoute = '$currentDriverId-${int.parse(newRouteNumber) + 1}';
    }

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Deliver-Auth': token,
      },
      body: json.encode({'invoice_code': barcode, 'route': currentRoute}),
    );

    if (response.statusCode == 401) {
      _handleUnauthorized(context);
      return;
    }

    if (response.statusCode == 200) {
      await fillOrderAndRedirectWhenArrived(context);
      notifyListeners();
    } else {
      final responseBody = json.decode(utf8.decode(response.bodyBytes));
      return alert(context, responseBody['detail'], SnackBarType.alert);
    }
  }

  void showPopUpDialog(BuildContext context, String message) {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK',
                    style: TextStyle(color: Colors.black, fontSize: 16)),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> returnOrder(
      BuildContext context, String orderNumber, int storeId) async {
    await _modifyOrderStatus(context, orderNumber, storeId,
        'retour_driver_orders', 'Error removing order');
  }

  Future<void> cancelOrder(
      BuildContext context, String orderNumber, int storeId) async {
    await _modifyOrderStatus(context, orderNumber, storeId,
        'cancel_driver_orders', 'Error canceling order');
  }

  Future<void> removeOrder(
      BuildContext context, String orderNumber, int storeId) async {
    await _modifyOrderStatus(context, orderNumber, storeId,
        'remove_active_driver_order', 'Error removing order');
  }

  Future<void> _modifyOrderStatus(BuildContext context, String orderNumber,
      int storeId, String endpoint, String errorMessage) async {
    try {
      final token = await retrieveTokenSecurely();
      final url = Uri.parse('$apiUrl/driver_order/$endpoint');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Deliver-Auth': token,
        },
        body: json.encode({'orderNumber': orderNumber, 'store': storeId}),
      );

      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return;
      }

      if (response.statusCode == 200) {
        await fillOrderAndRedirectWhenArrived(context);
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        showPopUpDialog(context, responseData['detail']);
      } else {
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        return alert(context, responseBody['detail'], SnackBarType.alert);
      }
    } catch (e) {
      await showSnackBar(context, errorMessage);
    }
  }

  Future<void> updateParts(BuildContext context, String orderNumber, int store,
      String barcode) async {
    try {
      final token = await retrieveTokenSecurely();
      final url = Uri.parse('$apiUrl/driver_order/scan_part');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Deliver-Auth': token,
        },
        body: json.encode({
          'orderNumber': orderNumber,
          'store': store,
          'partCode': barcode,
        }),
      );

      final res = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return;
      }

      if (response.statusCode == 200) {
        int numScanned = res["num_scanned"];
        String partNumber = res["item"];

        int orderIndex =
            orders.indexWhere((order) => order.order_number == orderNumber);
        if (orderIndex == -1) return;

        int itemIndex = orders[orderIndex]
            .orderInfo
            .indexWhere((item) => item.part_number == partNumber);
        if (itemIndex == -1) return;

        orders[orderIndex].orderInfo[itemIndex].num_scanned = numScanned;
        if (isOrderComplete(orderNumber)) {
          Navigator.pushReplacementNamed(context, '/orderList');
        }
        notifyListeners();
      } else {
        await showSnackBar(context, res["detail"]);
      }
    } catch (e) {
      await showSnackBar(
          context, "Un problème s'est produite lors de la mise à jour.");
    }
  }

  void updateBatchPart(BuildContext context, String partNumber, int store,
      String orderNumber) async {
    try {
      // Retrieve token
      final token = await retrieveTokenSecurely();

      // Prepare URL and make HTTP POST request
      final url = Uri.parse('$apiUrl/driver_order/batch_scan');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Deliver-Auth': token,
        },
        body: json.encode({
          "partNumber": partNumber,
          "orderNumber": orderNumber,
          "store": store,
        }),
      );

      // Decode response body
      final res = json.decode(utf8.decode(response.bodyBytes));

      // Handle unauthorized response
      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return;
      }

      // Handle successful response
      if (response.statusCode == 200) {
        // Check if num_scanned is present and can be parsed as a valid number
        if (res.containsKey('num_scanned')) {
          // Handle both int and float
          int numScanned = (res['num_scanned'] is double)
              ? (res['num_scanned'] as double).toInt()
              : res['num_scanned'];

          // Find the relevant order and part by orderNumber and partNumber
          int orderIndex =
              orders.indexWhere((order) => order.order_number == orderNumber);
          if (orderIndex == -1) {
            showPopUpDialog(context, 'Order not found.');
            return;
          }

          int itemIndex = orders[orderIndex]
              .orderInfo
              .indexWhere((item) => item.part_number == partNumber);
          if (itemIndex == -1) {
            showPopUpDialog(context, 'Part not found in the order.');
            return;
          }

          // Update scanned and confirmed counts
          orders[orderIndex].orderInfo[itemIndex].num_scanned = numScanned;
          orders[orderIndex].orderInfo[itemIndex].confirmed_scanned =
              numScanned;

          // Notify listeners and navigate if necessary
          if (getItemScanState(orderNumber, partNumber)) {
            notifyListeners();
            if (isOrderComplete(orderNumber)) {
              Navigator.pushReplacementNamed(context, '/orderList');
            }
          }
        } else {
          showPopUpDialog(context, 'Invalid scan data received.');
        }
      } else {
        // Handle non-200 responses
        return alert(context, res['detail'], SnackBarType.alert);
      }
    } catch (e) {
      // Handle any exceptions and show error dialog
      showPopUpDialog(
          context, 'Erreur lors de la mise à jour de la partie du lot: $e');
    }
  }

  Future<void> markAsArrived(BuildContext context) async {
    try {
      final token = await retrieveTokenSecurely();
      final url = Uri.parse('$apiUrl/driver_order/set_to_arrived');
      final orderNumber = getCurrentOrderCopy(context).order_number;
      final storeId = getCurrentOrderCopy(context).store;
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Deliver-Auth': token,
        },
        body: jsonEncode({
          'orderNumber': orderNumber,
          'store': storeId,
        }),
      );

      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return;
      }

      if (response.statusCode == 200) {
        orders.first.is_arrived = true;
        if (orders.isNotEmpty) {
          final currentRouteNumber = orders.first.route;
          // Assign all orders with the currentRouteNumber
          for (var order in orders) {
            if (order.route == currentRouteNumber) {
              if (order.route_started != true) {
                order.route_started = true;
              }
            }
          }
        }
        notifyListeners();
        Navigator.pushReplacementNamed(context, '/confirmation');
      } else {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        return alert(context, responseData['detail'], SnackBarType.alert);
      }
    } catch (e) {
      await showSnackBar(
          context, 'Erreur lors du marquage de la commande comme arrivée');
    }
  }

  Future<void> confirmParts(BuildContext context, String barcode) async {
    try {
      final token = await retrieveTokenSecurely();
      final url = Uri.parse('$apiUrl/driver_order/scan_part_confirmed');
      final orderNumber = getCurrentOrderCopy(context).order_number;
      final store = getCurrentOrderCopy(context).store;
      final encodedBody = utf8.encode(json.encode({
        'orderNumber': orderNumber,
        'store': store,
        'partCode': barcode,
      }));

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Deliver-Auth': token,
        },
        body: encodedBody,
      );

      final res = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return;
      }

      if (response.statusCode == 200) {
        int confirmedScan = res["confirmed_scanned"];
        String partNumber = res["item"];

        int orderIndex =
            orders.indexWhere((order) => order.order_number == orderNumber);
        if (orderIndex == -1) return;

        int itemIndex = orders[orderIndex]
            .orderInfo
            .indexWhere((item) => item.part_number == partNumber);
        if (itemIndex == -1) return;

        orders[orderIndex].orderInfo[itemIndex].confirmed_scanned =
            confirmedScan;
        notifyListeners();
      } else {
        await showSnackBar(context, res['detail']);
      }
    } catch (e) {
      await showSnackBar(
          context, "Une erreur s'est produite lors de la confirmation.");
    }
  }

  Future<void> byPassScan(BuildContext context, String orderNumber, int store,
      String partNumber) async {
    try {
      final token = await retrieveTokenSecurely();
      final url = Uri.parse('$apiUrl/driver_order/skip_part_at_delivery');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Deliver-Auth': token,
        },
        body: json.encode({
          "partNumber": partNumber,
          "orderNumber": orderNumber,
          "store": store,
        }),
      );

      final res = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return;
      }

      if (response.statusCode == 200) {
        int confirmedScanned = res["confirmed_scanned"];
        int orderIndex =
            orders.indexWhere((order) => order.order_number == orderNumber);
        if (orderIndex == -1) return;

        int itemIndex = orders[orderIndex]
            .orderInfo
            .indexWhere((item) => item.part_number == partNumber);
        if (itemIndex == -1) return;

        orders[orderIndex].orderInfo[itemIndex].confirmed_scanned =
            confirmedScanned;
        notifyListeners();
      } else {
        return alert(context, res['detail'], SnackBarType.alert);
      }
    } catch (e) {
      await showSnackBar(context, "Erreur lors du contournement de l'analyse");
    }
  }

  Future<void> updateReceivedBy(
      BuildContext context, String orderNumber, String receivedByName) async {
    final token = await retrieveTokenSecurely();
    final response = await http.post(
      Uri.parse('$apiUrl/driver_order/received_by'),
      headers: {
        'Content-Type': 'application/json',
        'X-Deliver-Auth': token,
      },
      body: jsonEncode({
        'order_number': orderNumber,
        'received_by': receivedByName,
      }),
    );

    if (response.statusCode == 401) {
      _handleUnauthorized(context);
      return;
    }

    if (response.statusCode == 200) {
      notifyListeners();
    } else {
      throw Exception('Failed to update received by');
    }
  }

  Future<bool> updateOrderDeliveryStatus(BuildContext context) async {
    try {
      final token = await retrieveTokenSecurely();
      final url = Uri.parse('$apiUrl/driver_order/set_to_delivered');
      final orderNumber = getCurrentOrderCopy(context).order_number;
      final store = getCurrentOrderCopy(context).store;
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Deliver-Auth': token,
        },
        body: jsonEncode({
          'orderNumber': orderNumber,
          'store': store,
        }),
      );

      if (response.statusCode == 401) {
        _handleUnauthorized(context);
        return false;
      }

      if (response.statusCode == 200) {
        await fillOrderAndRedirectWhenArrived(context);
        return true;
      } else {
        final responseBody = json.decode(utf8.decode(response.bodyBytes));
        alert(context, responseBody['detail'], SnackBarType.alert);
        return false;
      }
    } catch (e) {
      await showSnackBar(context, "Une erreur inattendue.");
      return false;
    }
  }

  void _handleRedirection(BuildContext context) async {
    if (orders.isEmpty) {
      await clearAppCache();
      Navigator.pushReplacementNamed(context, '/scan');
    } else if (getCurrentOrderCopy(context).is_arrived) {
      Navigator.pushReplacementNamed(context, '/confirmation');
    } else {
      Navigator.pushReplacementNamed(context, '/orderList');
    }
  }

  void _handleError(Object error, String message) {
    if (kDebugMode) {
      print('$message: $error');
    }
  }

  Order _getEmptyOrder() {
    return Order(
      tracking_number: '',
      order_number: '',
      store: 0,
      customer: '',
      client_name: '',
      phone_number: '',
      address: '',
      driver_id: 0,
      orderInfo: [],
      is_arrived: false,
      is_delivered: false,
      longitude: 0,
      latitude: 0,
      order_index: 0,
      route: '0-0',
      route_started: true,
      received_by: '',
      job: 0,
    );
  }
}

void showLogoutConfirmationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('êtes-vous sûr de vouloir déconnecter?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Annuler'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Déconnexion'),
            onPressed: () {
              Navigator.of(context).pop();
              logout(context);
            },
          ),
        ],
      );
    },
  );
}

void _handleUnauthorized(BuildContext context) {
  // Clear any relevant state or cache if necessary
  clearAppCache();
  // Redirect the user to the home screen or login screen
  Navigator.pushReplacementNamed(context, '/home');
}

Future<void> clearAppCache() async {
  try {
    // Clear the default cache manager's cache
    await DefaultCacheManager().emptyCache();

    // Clear the temporary directory
    final tempDir = await getTemporaryDirectory();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }

    // Clear the application documents directory
    final appDocDir = await getApplicationDocumentsDirectory();
    if (appDocDir.existsSync()) {
      appDocDir.deleteSync(recursive: true);
    }

    // Clear the application cache directory
    final appCacheDir = await getApplicationCacheDirectory();
    if (appCacheDir.existsSync()) {
      appCacheDir.deleteSync(recursive: true);
    }

    if (kDebugMode) {
      print('All application cache cleared successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Failed to clear application cache: $e');
    }
  }
}
