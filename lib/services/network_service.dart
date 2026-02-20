import 'dart:io';

class NetworkService {
  // ENG: Resets macOS Wi-Fi proxy settings - TR: macOS Wi-Fi proxy ayarlarını sıfırlar
  static Future<String> resetNetwork() async {
    try {
      // HTTP ve HTTPS proxy'lerini kapat
      await Process.run('networksetup', ['-setwebproxystate', 'Wi-Fi', 'off']);
      await Process.run('networksetup', ['-setsecurewebproxystate', 'Wi-Fi', 'off']);

      return "SİSTEM: Ağ proxy ayarları başarıyla sıfırlandı ve normale döndü.";
    } catch (e) {
      return "HATA: Ağ ayarları sıfırlanırken bir sorun oluştu: $e";
    }
  }
}