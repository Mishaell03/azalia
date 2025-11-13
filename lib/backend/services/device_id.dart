import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<String> getDeviceId() async {
    try {
      final deviceInfo = await _deviceInfo.deviceInfo;
      
      if (deviceInfo is AndroidDeviceInfo) {
        return deviceInfo.id; // Android ID
      } else if (deviceInfo is IosDeviceInfo) {
        return deviceInfo.identifierForVendor ?? 'unknown_ios_device';
      } else {
        return 'unknown_device';
      }
    } catch (e) {
      print('Ошибка получения device_id: $e');
      return 'error_device';
    }
  }

  static Future<String> generateTelegramLink() async {
    final deviceId = await getDeviceId();
    
    final cleanDeviceId = deviceId.replaceAll('.', '_');
    
    print('Device ID: $deviceId');
    print('Cleaned Device ID: $cleanDeviceId');
    
    return 'https://t.me/for_the_future_bot?start=$cleanDeviceId';
  }

  static Future<bool> launchTelegram() async {
    try {
      final url = await generateTelegramLink();
      print('Opening Telegram URL: $url');
      
      final uri = Uri.parse(url);
      final result = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (result) {
        print('Telegram opened successfully');
      } else {
        print('Failed to open Telegram');
      }
      
      return result;
    } catch (e) {
      print('Error opening Telegram: $e');
      return false;
    }
  }
}