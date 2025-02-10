import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const int cookieLifespanHours = 12;

const String locatorCookieKey = 'locator_cookie';

const String driverCookieKey = 'driver_cookie';

const String pickerCookieKey = 'picker_cookie';

const String xferCookieKey = 'picker_cookie';

Future<void> storeCookie(String token, String cookieKey) async {
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final DateTime expiryTime =
      DateTime.now().add(const Duration(hours: cookieLifespanHours));
  final Map<String, dynamic> cookieData = {
    'token': token,
    'expiryTime': expiryTime.toIso8601String(),
  };
  await secureStorage.write(key: cookieKey, value: jsonEncode(cookieData));
}

Future<Map<String, dynamic>?> retrieveCookie(String cookieKey) async {
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final String? cookieString = await secureStorage.read(key: cookieKey);
  if (cookieString == null) return null;
  final Map<String, dynamic> cookieData = jsonDecode(cookieString);
  final DateTime expiryTime = DateTime.parse(cookieData['expiryTime']);
  if (DateTime.now().isAfter(expiryTime)) {
    await secureStorage.delete(key: cookieKey);
    return null;
  }
  return cookieData;
}

Future<Map<String, dynamic>?> retrievePickerCookie(String cookieKey) async {
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();

  // Retrieve the cookie string
  final String? cookieString = await secureStorage.read(key: cookieKey);
  if (cookieString == null) return null;

  // Decode the cookie string
  final Map<String, dynamic> cookieData = jsonDecode(cookieString);

  // Retrieve the expiry time and check if the cookie has expired
  final DateTime expiryTime = DateTime.parse(cookieData['expiryTime']);
  if (DateTime.now().isAfter(expiryTime)) {
    await secureStorage.delete(key: cookieKey);
    return null;
  }

  // Retrieve userId and username from their respective storage keys
  final String? userId = await secureStorage.read(key: 'userId');
  final String? username = await secureStorage.read(key: 'username');

  // Add userId and username to the cookieData map
  if (userId != null) {
    cookieData['userId'] = userId;
  }
  if (username != null) {
    cookieData['username'] = username;
  }

  return cookieData;
}

/// Retrieves the stored signature name.
///
/// @return The stored signature name, or an empty string if not found
///
/// Example:
/// ```dart
/// final signatureName = await getSignatureName();
/// print(signatureName);
/// ```
Future<String> getSignatureName() async {
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  return await secureStorage.read(key: 'signatureName') ?? '';
}

/// Stores a token securely.
///
/// @param token The token to store
///
/// Example:
/// ```dart
/// await storeTokenSecurely('my_token');
/// ```
Future<void> storeTokenSecurely(String token) async {
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  await secureStorage.write(key: 'userToken', value: token);
}

/// Retrieves the stored token securely.
///
/// @return The stored token, or an empty string if not found
///
/// Example:
/// ```dart
/// final token = await retrieveTokenSecurely();
/// print(token);
/// ```
Future<String> retrieveTokenSecurely() async {
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  return await secureStorage.read(key: 'userToken') ?? '';
}

/// Logs out the user, deleting stored tokens and cookies.
///
/// @param context The BuildContext to navigate from
///
/// Example:
/// ```dart
/// await logout(context);
/// ```
Future<void> logout(BuildContext context) async {
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();

  // Delete the user token
  await secureStorage.delete(key: 'userToken');

  // Delete the locator-specific cookie
  await secureStorage.delete(key: locatorCookieKey);

  // Navigate to the home screen and remove all previous routes
  Navigator.of(context)
      .pushNamedAndRemoveUntil('/home', (Route<dynamic> route) => false);
}

/// Retrieves the stored SDK keys.
///
/// @return A map containing the SDK key ID and key, or empty strings if not found
///
/// Example:
/// ```dart
/// final sdkKeys = await retrieveSdkKeys();
/// print(sdkKeys);
/// ```
Future<Map<String, dynamic>> retrieveSdkKeys() async {
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  String? sdkKeyId = await secureStorage.read(key: 'sdk_key_id');
  String? sdkKey = await secureStorage.read(key: 'sdk_key');

  return {
    "sdk_key_id": sdkKeyId ?? '',
    "sdk_key": sdkKey ?? '',
  };
}

Future<String> retrieveDriverId() async {
  // Replace this with your actual logic to retrieve the driver ID
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  return await secureStorage.read(key: 'driverId') ?? '';
}

Future<String> retrieveStoreId() async {
  // Replace this with your actual logic to retrieve the driver ID
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  return await secureStorage.read(key: 'storeId') ?? '';
}

Future<String> retrieveUserId() async {
  // Replace this with your actual logic to retrieve the driver ID
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  return await secureStorage.read(key: 'userId') ?? '';
}

Future<String> retrieveUsername() async {
  // Replace this with your actual logic to retrieve the driver ID
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  return await secureStorage.read(key: 'username') ?? '';
}

Future<void> locatorLogout(BuildContext context) async {
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();

  // Delete the user token
  await secureStorage.delete(key: 'userToken');

  // Delete the locator-specific cookie
  await secureStorage.delete(key: locatorCookieKey);

  // Navigate to the home screen and remove all previous routes
  Navigator.of(context)
      .pushNamedAndRemoveUntil('/home', (Route<dynamic> route) => false);
}
