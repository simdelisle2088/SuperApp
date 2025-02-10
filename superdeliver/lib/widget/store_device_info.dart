// lib/services/device_storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceStorageService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Keys for storing device information
  static const String _deviceIdKey = 'deviceId';
  static const String _deviceTypeKey = 'deviceType';
  static const String _lastLoginTimeKey = 'lastLoginTime';
  static const String _deviceFingerprintKey = 'deviceFingerprint';
  static const String _deviceModelKey = 'deviceModel';
  static const String _deviceManufacturerKey = 'deviceManufacturer';

  // Store complete device information
  static Future<void> storeDeviceInfo(Map<String, dynamic> deviceInfo) async {
    try {
      // Store each piece of device information separately for easier access
      await _secureStorage.write(
          key: _deviceIdKey,
          value:
              deviceInfo['deviceId'] ?? deviceInfo['fingerprint'] ?? 'unknown');

      await _secureStorage.write(
          key: _deviceTypeKey,
          value: deviceInfo['deviceType'] ?? Platform.operatingSystem);

      await _secureStorage.write(
          key: _deviceModelKey, value: deviceInfo['model'] ?? 'unknown');

      await _secureStorage.write(
          key: _deviceManufacturerKey,
          value: deviceInfo['manufacturer'] ?? 'unknown');

      await _secureStorage.write(
          key: _deviceFingerprintKey,
          value: deviceInfo['fingerprint'] ?? 'unknown');

      // Store login timestamp
      await _secureStorage.write(
          key: _lastLoginTimeKey, value: DateTime.now().toIso8601String());

      // Store the complete device info as JSON for future reference
      await _secureStorage.write(
          key: 'completeDeviceInfo', value: jsonEncode(deviceInfo));
    } catch (e) {
      print('Error storing device info: $e');
      // You might want to handle this error more gracefully
      rethrow;
    }
  }

  // Get stored device information
  static Future<Map<String, String>> getStoredDeviceInfo() async {
    try {
      return {
        'deviceId': await _secureStorage.read(key: _deviceIdKey) ?? 'unknown',
        'deviceType':
            await _secureStorage.read(key: _deviceTypeKey) ?? 'unknown',
        'model': await _secureStorage.read(key: _deviceModelKey) ?? 'unknown',
        'manufacturer':
            await _secureStorage.read(key: _deviceManufacturerKey) ?? 'unknown',
        'fingerprint':
            await _secureStorage.read(key: _deviceFingerprintKey) ?? 'unknown',
        'lastLoginTime':
            await _secureStorage.read(key: _lastLoginTimeKey) ?? 'unknown',
      };
    } catch (e) {
      print('Error retrieving device info: $e');
      return {};
    }
  }

  // Clear all device information (useful for logout)
  static Future<void> clearDeviceInfo() async {
    try {
      await _secureStorage.delete(key: _deviceIdKey);
      await _secureStorage.delete(key: _deviceTypeKey);
      await _secureStorage.delete(key: _deviceModelKey);
      await _secureStorage.delete(key: _deviceManufacturerKey);
      await _secureStorage.delete(key: _deviceFingerprintKey);
      await _secureStorage.delete(key: _lastLoginTimeKey);
      await _secureStorage.delete(key: 'completeDeviceInfo');
    } catch (e) {
      print('Error clearing device info: $e');
      rethrow;
    }
  }
}
