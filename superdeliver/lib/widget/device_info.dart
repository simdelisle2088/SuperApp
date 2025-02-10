import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoService {
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    Map<String, dynamic> deviceData = {};

    try {
      if (Platform.isAndroid) {
        // Get Android-specific device information
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceData = {
          // Using the correct property names for version 8.2.2
          'deviceId': androidInfo.id, // Unique device ID
          'manufacturer': androidInfo.manufacturer, // Device manufacturer
          'model': androidInfo.model, // Device model
          'brand': androidInfo.brand, // Device brand
          'deviceType': 'Android',
          // Additional reliable device identifiers
          'fingerprint': androidInfo.fingerprint, // Build fingerprint
          'serialNumber': androidInfo.serialNumber, // Hardware serial number
          'device': androidInfo.device, // Device name
          'display': androidInfo.display, // Build display ID
          'product': androidInfo.product, // Product name
          'bootloader': androidInfo.bootloader, // Bootloader version
          'isPhysicalDevice':
              androidInfo.isPhysicalDevice, // True if not an emulator
        };
      } else if (Platform.isIOS) {
        // Get iOS-specific device information
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceData = {
          'deviceId':
              iosInfo.identifierForVendor ?? 'unknown', // Unique device ID
          'name': iosInfo.name, // Device name
          'model': iosInfo.model, // Device model
          'systemVersion': iosInfo.systemVersion, // iOS version
          'deviceType': 'iOS',
          // Additional iOS-specific identifiers
          'localizedModel': iosInfo.localizedModel,
          'systemName': iosInfo.systemName,
          'isPhysicalDevice':
              iosInfo.isPhysicalDevice, // True if not a simulator
        };
      }

      // Add general platform information
      deviceData.addAll({
        'platform': Platform.operatingSystem,
        'platformVersion': Platform.operatingSystemVersion,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Device info error: $e');
      deviceData = {
        'error': e.toString(),
        'platform': Platform.operatingSystem,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }

    return deviceData;
  }
}
