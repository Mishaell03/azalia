import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<String> getDeviceId() async {
    try {
      final deviceInfo = await _deviceInfo.deviceInfo;
      
      if (deviceInfo is AndroidDeviceInfo) {
        return deviceInfo.id;
      } else if (deviceInfo is IosDeviceInfo) {
        return deviceInfo.identifierForVendor ?? 'unknown_ios_device';
      } else {
        return 'unknown_device';
      }
    } catch (e) {
      return 'error_device';
    }
  }

  static Future<String> generateTelegramLink() async {
    final deviceId = await getDeviceId();
    final cleanDeviceId = deviceId.replaceAll('.', '_');
    return 'https://t.me/for_the_future_bot?start=$cleanDeviceId';
  }

  static Future<bool> launchTelegram() async {
    try {
      final url = await generateTelegramLink();
      final uri = Uri.parse(url);
      final result = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return result;
    } catch (e) {
      return false;
    }
  }
}