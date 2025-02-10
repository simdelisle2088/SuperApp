// ignore_for_file: file_names, non_constant_identifier_names
import 'dart:convert';

class Order {
  late final String tracking_number;
  late final String order_number;
  final int store;
  final String customer;
  final String client_name;
  final String phone_number;
  final String address;
  final int driver_id;
  List<Item> orderInfo;
  bool is_arrived;
  bool is_delivered;
  final double latitude;
  final double longitude;
  final int order_index;
  final String route;
  bool route_started;
  final String? received_by;
  final int? job;

  Order({
    required this.tracking_number,
    required this.order_number,
    required this.store,
    required this.customer,
    required this.client_name,
    required this.phone_number,
    required this.address,
    required this.driver_id,
    required this.orderInfo,
    required this.is_arrived,
    required this.is_delivered,
    required this.longitude,
    required this.latitude,
    required this.order_index,
    required this.route,
    required this.route_started,
    required this.received_by,
    required this.job,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var orderInfoData = json['order_info'];
    List<Item> parsedOrderInfo = [];

    // Parse order_info as before
    if (orderInfoData != null) {
      if (orderInfoData is String) {
        orderInfoData = jsonDecode(orderInfoData);
      }
      if (orderInfoData is List) {
        parsedOrderInfo =
            orderInfoData.map<Item>((json) => Item.fromJson(json)).toList();
      }
    }

    // Helper function to parse numeric values that might come as strings
    int parseIntValue(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // Helper function to parse double values that might come as strings
    double parseDoubleValue(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Helper function to parse boolean values that might come in different formats
    bool parseBoolValue(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value.toLowerCase() == 'true' || value == '1';
      return false;
    }

    return Order(
      tracking_number: json['tracking_number']?.toString() ?? '',
      order_number: json['order_number']?.toString() ?? '',
      store: parseIntValue(json['store']),
      customer: json['customer']?.toString() ?? 'Unknown',
      client_name: json['client_name']?.toString() ?? 'Unknown',
      phone_number: json['phone_number']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      driver_id: parseIntValue(json['driver_id']),
      orderInfo: parsedOrderInfo,
      is_arrived: parseBoolValue(json['is_arrived']) ||
          parseBoolValue(json['route_started']),
      is_delivered: parseBoolValue(json['is_delivered']) ||
          parseBoolValue(json['route_started']),
      latitude: parseDoubleValue(json['latitude']),
      longitude: parseDoubleValue(json['longitude']),
      order_index: parseIntValue(json['order_index']),
      route: json['route']?.toString() ?? '0-0',
      route_started: parseBoolValue(json['route_started']),
      received_by: json['received_by']?.toString(),
      job: parseIntValue(json['job']),
    );
  }
}

class ReturnItem {
  final String store;
  final String item;
  final int units;
  final String createdAt;
  final String updatedAt;
  final String loc;
  final dynamic upc; // Could be String or List<String>

  ReturnItem.fromJson(Map<String, dynamic> json)
      : store = json['store'].toString(),
        item = json['item'],
        units = json['units'],
        createdAt = json['created_at'],
        updatedAt = json['updated_at'],
        loc = json['loc'],
        upc = json['upc'];
}

class Item {
  final String part_number;
  final String description;
  final int units;
  int num_scanned;
  int confirmed_scanned;
  String order_number;

  Item({
    required this.part_number,
    required this.description,
    required this.units,
    required this.num_scanned,
    required this.confirmed_scanned,
    required this.order_number,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, String fieldName) {
      if (value is double) {
        print(
            'Warning: Field "$fieldName" expected an int but received a double. Converting $value to int.');
        return value.toInt();
      } else if (value is int) {
        return value;
      } else {
        print(
            'Warning: Field "$fieldName" has an unexpected type. Defaulting to 0.');
        return 0;
      }
    }

    return Item(
      part_number: json['item'] ?? 'Unknown',
      description: json['description'] ?? 'No description',
      units: parseInt(json['units'], 'units'),
      num_scanned: parseInt(json['num_scanned'], 'num_scanned'),
      confirmed_scanned:
          parseInt(json['confirmed_scanned'], 'confirmed_scanned'),
      order_number: json['order_number'] ?? 'Unknown',
    );
  }
}
