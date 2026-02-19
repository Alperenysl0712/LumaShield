import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DpiService {
  Process? _tempProcess;
  Function(String)? onLogReceived;

  bool get isRunning => _tempProcess != null;

  /// ENG: Option 1: Temporary Mode - TR: Opsiyon 1: Geçici Mod
  Future<void> startTemporary() async {
    try {
      // ENG: Clean up existing zombie processes to prevent port conflicts
      // TR: Port çakışmasını önlemek için varsa eski zombi süreçleri temizle
      _log("🧹 Port kontrol ediliyor...");
      await Process.run('killall', ['LumaDPI_Temp']);
      await Process.run('killall', ['LumaDPI']);

      // ENG: Wait for the OS to release port 8080
      // TR: Sistemin portu (8080) tamamen serbest bırakması için bekle
      await Future.delayed(const Duration(milliseconds: 300));

      final executablePath = await _prepareBinary("LumaDPI_Temp");

      _log("🚀 Gecici Motor Baslatiliyor...");
      _tempProcess = await Process.start(executablePath, []);

      // ENG: Listen to stdout and stderr streams
      // TR: Akışları (stdout/stderr) dinle ve logla
      _tempProcess!.stdout.transform(utf8.decoder).listen((data) => _log(data.trim()));
      _tempProcess!.stderr.transform(utf8.decoder).listen((data) {
        if (data.contains("busy")) {
          _log("⚠️ Port hala mesgul, tekrar deneniyor...");
          stopTemporary();
        } else {
          _log("HATA: $data");
        }
      });

      _tempProcess!.exitCode.then((code) {
        _log("ℹ️ Motor durdu (Kod: $code)");
        _tempProcess = null;
      });

    } catch (e) {
      _log("❌ Motor baslatilamadi: $e");
    }
  }

  Future<void> stopTemporary() async {
    if (_tempProcess != null) {
      _tempProcess!.kill();
      _tempProcess = null;
    }
    // ENG: Clean up system proxy settings after stopping
    // TR: Durdurduktan sonra sistem proxy ayarlarını temizle
    await _cleanupProxy();
    await Process.run('killall', ['LumaDPI_Temp']);
    _log("🛑 Gecici Motor ve Proxy Durduruldu.");
  }

  /// ENG: Option 2: Permanent Service (LaunchAgent) - TR: Opsiyon 2: Kalıcı Servis
  Future<void> installPermanent() async {
    try {
      _log("⚙️ Kalici servis kuruluyor...");
      final appSupportDir = await getApplicationSupportDirectory();
      if (!await appSupportDir.exists()) await appSupportDir.create(recursive: true);

      final permExecPath = '${appSupportDir.path}/LumaDPI';
      final byteData = await rootBundle.load('assets/bin/LumaDPI');
      final file = File(permExecPath);
      if (await file.exists()) await file.delete();
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Process.run('chmod', ['+x', permExecPath]);

      // ENG: Create and load macOS LaunchAgent for persistence
      // TR: Kalıcılık için macOS LaunchAgent (plist) oluştur ve yükle
      final home = Platform.environment['HOME'];
      final plistPath = '$home/Library/LaunchAgents/com.luma.shield.plist';
      final plistContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.luma.shield</string>
    <key>ProgramArguments</key>
    <array>
        <string>$permExecPath</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>''';

      await File(plistPath).writeAsString(plistContent);
      await Process.run('launchctl', ['unload', plistPath]);
      await Process.run('launchctl', ['load', plistPath]);

      _log("✅ Servis gomuldu. PC acildiginda otomatik calisacak.");
    } catch (e) {
      _log("❌ Kalici kurulum hatasi: $e");
    }
  }

  Future<void> removePermanent() async {
    try {
      final home = Platform.environment['HOME'];
      final plistPath = '$home/Library/LaunchAgents/com.luma.shield.plist';

      // ENG: Unload the service and delete the plist file
      // TR: Servisi devreden çıkar ve plist dosyasını sil
      await Process.run('launchctl', ['unload', plistPath]);
      final file = File(plistPath);
      if (await file.exists()) await file.delete();

      await _cleanupProxy();
      _log("🗑️ Tum servisler ve kalici ayarlar silindi.");
    } catch (e) {
      _log("❌ Silme hatasi: $e");
    }
  }

  Future<void> _cleanupProxy() async {
    // ENG: Reset macOS Wi-Fi proxy settings to OFF
    // TR: macOS Wi-Fi proxy ayarlarını KAPALI konumuna getir
    await Process.run('networksetup', ['-setwebproxystate', 'Wi-Fi', 'off']);
    await Process.run('networksetup', ['-setsecurewebproxystate', 'Wi-Fi', 'off']);
  }

  Future<String> _prepareBinary(String name) async {
    // ENG: Extract binary from assets to temporary directory and set permissions
    // TR: Binary dosyasını asset'ten geçici dizine çıkar ve izinleri ayarla
    final byteData = await rootBundle.load('assets/bin/LumaDPI');
    final tempDir = await getTemporaryDirectory();
    if (!await tempDir.exists()) await tempDir.create(recursive: true);

    final executablePath = '${tempDir.path}/$name';
    final file = File(executablePath);

    if (await file.exists()) await file.delete();
    await file.writeAsBytes(byteData.buffer.asUint8List());
    await Process.run('chmod', ['+x', executablePath]);

    return executablePath;
  }

  void _log(String msg) {
    if (onLogReceived != null) onLogReceived!(msg);
  }
}