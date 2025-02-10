import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class InventoryProvider with ChangeNotifier {
  final String apiUrl;

  InventoryProvider(this.apiUrl);

  bool _isLoading = false;
  String _errorMessage = '';
  List<ItemLocation> _items = [];

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<ItemLocation> get items => _items;

  Future<void> fetchItemsByLocation(String fullLocation) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final url = Uri.parse('$apiUrl/inv/items_by_location');
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({'full_location': fullLocation});

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _items = data.map((item) => ItemLocation.fromJson(item)).toList();
      } else if (response.statusCode == 404) {
        _errorMessage = 'No items found for the given location.';
        _items = [];
      } else {
        _errorMessage = 'Failed to fetch items: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Error fetching items: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearItems() {
    _items = [];
    notifyListeners();
  }
}

class ItemLocation {
  final String upc;
  final String name;
  final int count;

  ItemLocation({
    required this.upc,
    required this.name,
    required this.count,
  });

  factory ItemLocation.fromJson(Map<String, dynamic> json) {
    return ItemLocation(
      upc: json['upc'] as String,
      name: json['name'] as String,
      count: json['count'] as int,
    );
  }
}
