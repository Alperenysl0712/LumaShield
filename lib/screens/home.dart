import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../services/dpi_service.dart';
import '../services/network_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final DpiService _dpiService = DpiService();
  final List<String> _logs = ["> Luma Engine v2.0 Başlatılıyor...", "> Sistem hazır."];
  int _selectedWindowSize = 7;
  String _currentLogFilter = 'ALL';

  int _currentTab = 0;
  List<String> _whitelist = [];
  final TextEditingController _whitelistController = TextEditingController();

  final List<FlSpot> _downloadSpots = [];
  final List<FlSpot> _uploadSpots = [];
  double _timeCounter = 0;

  bool _isTempRunning = false;
  double _totalDownloadedKB = 0;
  double _totalUploadedKB = 0;
  Timer? _sessionTimer;
  int _sessionSeconds = 0;

  final ScrollController _scrollController = ScrollController();

  late AnimationController _bgController;
  late Animation<Alignment> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _downloadSpots.add(const FlSpot(0, 0));
    _uploadSpots.add(const FlSpot(0, 0));

    WidgetsBinding.instance.addObserver(this);
    _loadWhitelist();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _bgAnimation = AlignmentTween(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));

    _dpiService.onLogReceived = (message) {
      _addLog(message);
    };

    _dpiService.onMetricsReceived = (up, down) {
      if (!mounted) return;
      setState(() {
        _timeCounter++;
        _totalUploadedKB += up;
        _totalDownloadedKB += down;

        _uploadSpots.add(FlSpot(_timeCounter, up));
        _downloadSpots.add(FlSpot(_timeCounter, down));

        if (_uploadSpots.length > 40) {
          _uploadSpots.removeAt(0);
          _downloadSpots.removeAt(0);
        }
      });
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _whitelistController.dispose();
    _dpiService.stopTemporary();
    _bgController.dispose();
    super.dispose();
  }

  Future<File> _getWhitelistFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/whitelist.txt');
  }

  Future<void> _loadWhitelist() async {
    try {
      final file = await _getWhitelistFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          setState(() {
            _whitelist = content.split('\n').where((s) => s.trim().isNotEmpty).toList();
          });
          _addLog("> İstisna listesi yüklendi (${_whitelist.length} kayıt).");
        }
      }
    } catch (e) {
      _addLog("HATA: Liste yüklenemedi: $e");
    }
  }

  Future<void> _saveWhitelist() async {
    try {
      final file = await _getWhitelistFile();
      await file.writeAsString(_whitelist.join('\n'));
    } catch (e) {
      _addLog("HATA: Liste kaydedilemedi: $e");
    }
  }

  void _addDomainToWhitelist() {
    final domain = _whitelistController.text.trim().toLowerCase();
    if (domain.isNotEmpty && !_whitelist.contains(domain)) {
      setState(() {
        _whitelist.add(domain);
        _whitelistController.clear();
      });
      _saveWhitelist();
      _addLog("> Whitelist'e eklendi: $domain");
    }
  }

  void _removeDomainFromWhitelist(String domain) {
    setState(() {
      _whitelist.remove(domain);
    });
    _saveWhitelist();
    _addLog("> Whitelist'ten silindi: $domain");
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _logs.add(message);
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
          );
        }
      });
    });
  }

  List<String> get _filteredLogs {
    if (_currentLogFilter == 'BYPASS') {
      return _logs.where((log) => log.contains("Bypass") || log.contains("SİSTEM")).toList();
    } else if (_currentLogFilter == 'ERROR') {
      return _logs.where((log) => log.contains("HATA") || log.contains("ERROR") || log.contains("CRITICAL")).toList();
    }
    return _logs;
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
      _logs.add("> Log ekranı temizlendi.");
    });
  }

  void _toggleTempEngine() async {
    if (_isTempRunning) {
      await _dpiService.stopTemporary();
      _sessionTimer?.cancel();
      setState(() => _isTempRunning = false);
      _addLog("SİSTEM: Geçici koruma durduruldu.");
    } else {
      _addLog("SİSTEM: Motor $_selectedWindowSize byte parçalama stratejisiyle başlatılıyor...");
      setState(() {
        _sessionSeconds = 0;
        _totalDownloadedKB = 0;
        _totalUploadedKB = 0;
      });
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() => _sessionSeconds++);
      });

      await _dpiService.startTemporary(windowSize: _selectedWindowSize, whiteList: _whitelist);
      _addLog("SİSTEM: Ağ tüneli kuruluyor, lütfen bekleyin...");

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isTempRunning = _dpiService.isRunning);
      });
    }
  }

  void _resetNetworkSettings() async {
    _addLog("SİSTEM: Ağ ayarları sıfırlanıyor...");
    String result = await NetworkService.resetNetwork();
    _addLog(result);
  }

  String _formatBytes(double kbValue) {
    if (kbValue >= 1024) return "${(kbValue / 1024).toStringAsFixed(1)} MB/s";
    return "${kbValue.toStringAsFixed(0)} KB/s";
  }

  String get _formattedSessionTime {
    int h = _sessionSeconds ~/ 3600;
    int m = (_sessionSeconds % 3600) ~/ 60;
    int s = _sessionSeconds % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  String _formatTotalData(double kbValue) {
    if (kbValue > 1024 * 1024) return "${(kbValue / (1024 * 1024)).toStringAsFixed(2)} GB";
    if (kbValue > 1024) return "${(kbValue / 1024).toStringAsFixed(2)} MB";
    return "${kbValue.toStringAsFixed(1)} KB";
  }

  @override
  Widget build(BuildContext context) {
    Color mainColor = _isTempRunning ? const Color(0xFF00FF94) : const Color(0xFFFF2A4D);
    Color bgColor = _isTempRunning ? const Color(0xFF020A05) : const Color(0xFF0A0202);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: _bgAnimation.value,
                    radius: 2.0,
                    colors: [mainColor.withOpacity(0.15), bgColor],
                  ),
                ),
              );
            },
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),
          Row(
            children: [
              Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  border: Border(right: BorderSide(color: mainColor.withOpacity(0.15), width: 1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: mainColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.shield_moon_outlined, color: mainColor, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text("LUMA", style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text("SHIELD", style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold, color: mainColor)),
                                ],
                              ),
                              Text("ADVANCED DPI BYPASS", style: GoogleFonts.rajdhani(fontSize: 10, color: Colors.white38, letterSpacing: 2, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 35),
                    _MenuButton(title: "DASHBOARD", icon: Icons.dashboard_outlined, isSelected: _currentTab == 0, activeColor: mainColor, onTap: () => setState(() => _currentTab = 0)),
                    const SizedBox(height: 8),
                    _MenuButton(title: "İSTİSNA LİSTESİ", icon: Icons.rule_folder_outlined, isSelected: _currentTab == 1, activeColor: mainColor, onTap: () => setState(() => _currentTab = 1)),
                    const SizedBox(height: 25),
                    _buildStatusIndicator(mainColor),
                    const SizedBox(height: 25),
                    Text("ATLATMA STRATEJİSİ", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildStrategySelector(mainColor),
                    const SizedBox(height: 25),
                    Text("KONTROL MERKEZİ", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _CyberButton(label: _isTempRunning ? "KORUMAYI DURDUR" : "GEÇİCİ BAŞLAT", icon: Icons.power_settings_new, color: mainColor, isActive: true, onTap: _toggleTempEngine),
                          const SizedBox(height: 10),
                          _CyberButton(label: "KILL SWITCH (SIFIRLA)", icon: Icons.warning_rounded, color: const Color(0xFFFF2A4D), isActive: true, onTap: () { _addLog("CRITICAL: Kill Switch tetiklendi!"); _resetNetworkSettings(); }),
                          const SizedBox(height: 10),
                          _CyberButton(label: "KALICI KURULUM", icon: Icons.system_update_alt, color: Colors.blueAccent, isActive: true, onTap: () => _dpiService.installPermanent()),
                          const SizedBox(height: 10),
                          _CyberButton(label: "SERVİSİ KALDIR", icon: Icons.delete_outline, color: Colors.grey, isActive: true, onTap: () => _dpiService.removePermanent()),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: _currentTab == 0 ? _buildDashboardContent(mainColor) : _buildWhitelistContent(mainColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD İÇERİĞİ
  // ---------------------------------------------------------------------------
  Widget _buildDashboardContent(Color mainColor) {
    return Column(
      children: [
        _buildHeader(mainColor),
        const SizedBox(height: 24),
        Row(
          children: [
            _buildStatCard("AKTİF SÜRE", _formattedSessionTime, Icons.timer_outlined, Colors.amberAccent),
            const SizedBox(width: 16),
            _buildStatCard("GİZLENEN (İNDİRME)", _formatTotalData(_totalDownloadedKB), Icons.download, const Color(0xFF00FF94)),
            const SizedBox(width: 16),
            _buildStatCard("GİZLENEN (YÜKLEME)", _formatTotalData(_totalUploadedKB), Icons.upload, const Color(0xFFFF2A4D)),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(flex: 3, child: _buildTerminal(mainColor)),
        const SizedBox(height: 24),
        Expanded(flex: 2, child: _buildGraph(mainColor)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(value, style: GoogleFonts.firaCode(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTerminal(Color mainColor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF030303).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5, blurStyle: BlurStyle.inner)],
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _windowDot(const Color(0xFFFF5F56)), const SizedBox(width: 8),
                    _windowDot(const Color(0xFFFFBD2E)), const SizedBox(width: 8),
                    _windowDot(const Color(0xFF27C93F)),
                  ],
                ),
                Flexible(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildLogFilterChip("TÜMÜ", "ALL", Colors.white54),
                      const SizedBox(width: 4),
                      _buildLogFilterChip("BYPASS", "BYPASS", const Color(0xFF00FF94)),
                      const SizedBox(width: 4),
                      _buildLogFilterChip("HATALAR", "ERROR", const Color(0xFFFF4444)),
                      IconButton(icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white38, size: 16), onPressed: _clearLogs),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _filteredLogs.length + 1,
              itemBuilder: (context, index) {
                if (index == _filteredLogs.length) {
                  return const Padding(padding: EdgeInsets.only(top: 8), child: _BlinkingCursor());
                }

                final log = _filteredLogs[index];
                Color logColor = const Color(0xFFCCCCCC);
                if (log.contains("HATA") || log.contains("ERROR")) logColor = const Color(0xFFFF4444);
                if (log.contains("Bypass") || log.contains("SİSTEM")) logColor = mainColor;

                String cleanLog = log.startsWith(">") ? log.replaceFirst("> ", "").replaceFirst(">", "") : log;

                return _AnimatedLogItem(key: ValueKey(log + index.toString()), logText: cleanLog, color: logColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogFilterChip(String label, String filterKey, Color activeColor) {
    bool isSelected = _currentLogFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _currentLogFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: GoogleFonts.firaCode(fontSize: 9, color: isSelected ? activeColor : Colors.white24)),
      ),
    );
  }

  Widget _buildGraph(Color mainColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _speedLabel("DOWNLOAD HIZI", _downloadSpots, const Color(0xFF00FF94), Icons.arrow_downward),
              const SizedBox(width: 16),
              _speedLabel("UPLOAD HIZI", _uploadSpots, const Color(0xFFFF2A4D), Icons.arrow_upward),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _downloadSpots.isEmpty
                ? Center(child: Text("AĞ TRAFİĞİ BEKLENİYOR...", style: GoogleFonts.rajdhani(color: Colors.white24, letterSpacing: 2)))
                : LineChart(
              LineChartData(
                clipData: const FlClipData.all(),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: _timeCounter > 40 ? _timeCounter - 40 : 0,
                maxX: _timeCounter,
                maxY: (_downloadSpots.isEmpty) ? 100 : ([..._downloadSpots, ..._uploadSpots].map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2),
                lineBarsData: [
                  _lineData(_downloadSpots, const Color(0xFF00FF94)),
                  _lineData(_uploadSpots, const Color(0xFFFF2A4D)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _lineData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots, isCurved: true, color: color, barWidth: 2, dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
    );
  }

  Widget _speedLabel(String label, List<FlSpot> spots, Color color, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(spots.isEmpty ? "0 KB/s" : _formatBytes(spots.last.y), style: GoogleFonts.firaCode(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // YENİ VE GELİŞMİŞ WHITELIST İÇERİĞİ (PREMIUM TASARIM)
  // ---------------------------------------------------------------------------
  Widget _buildWhitelistContent(Color mainColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- BAŞLIK VE BADGE ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                "İSTİSNA (WHITELIST) YÖNETİMİ",
                style: TextStyle(color: Colors.white.withOpacity(0.8), letterSpacing: 1.5, fontSize: 16, fontWeight: FontWeight.bold)
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: mainColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: mainColor.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: mainColor, size: 14),
                  const SizedBox(width: 6),
                  Text("${_whitelist.length} GÜVENLİ DOMAİN", style: GoogleFonts.firaCode(fontSize: 11, color: mainColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // --- BİLGİLENDİRME BANNER'I ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueAccent.withOpacity(0.8), size: 24),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "Buraya eklediğiniz alan adları DPI motoru tarafından parçalanmaz. Bağlantı doğrudan, müdahalesiz sağlanır.\nBankacılık, e-Devlet ve resmi kurum sitelerini eklemeniz önerilir. (Örn: garanti.com.tr)",
                  style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // --- SİBER GİRİŞ ALANI (INPUT & BUTTON) ---
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
                ),
                child: TextField(
                  controller: _whitelistController,
                  style: GoogleFonts.firaCode(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Güvenli domain adresini girin...",
                    hintStyle: GoogleFonts.firaCode(color: Colors.white24),
                    prefixIcon: Icon(Icons.add_link, color: mainColor.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onSubmitted: (_) => _addDomainToWhitelist(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: _addDomainToWhitelist,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [mainColor.withOpacity(0.2), mainColor.withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: mainColor.withOpacity(0.5)),
                  boxShadow: [BoxShadow(color: mainColor.withOpacity(0.2), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_moderator, color: mainColor, size: 20),
                    const SizedBox(width: 8),
                    Text("LİSTEYE EKLE", style: GoogleFonts.rajdhani(color: mainColor, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                  ],
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 32),

        // --- GÜVENLİ DOMAIN LİSTESİ ---
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: _whitelist.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security_update_warning_outlined, size: 48, color: Colors.white10),
                  const SizedBox(height: 16),
                  Text("İstisna listesi tamamen boş.", style: GoogleFonts.firaCode(color: Colors.white38, fontSize: 12)),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(12),
              physics: const BouncingScrollPhysics(),
              itemCount: _whitelist.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.verified_user, color: Colors.blueAccent, size: 18),
                    ),
                    title: Text(_whitelist[index], style: GoogleFonts.firaCode(color: Colors.white70, fontSize: 14)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                      hoverColor: Colors.redAccent.withOpacity(0.1),
                      color: Colors.redAccent,
                      onPressed: () => _removeDomainFromWhitelist(_whitelist[index]),
                      tooltip: "Güvenli Listeden Çıkar",
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // YARDIMCI BİLEŞENLER
  // ---------------------------------------------------------------------------
  Widget _buildStrategySelector(Color mainColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          _strategyOption("ULTRA", 1, Icons.bolt, mainColor),
          _strategyOption("TINY", 2, Icons.compress, mainColor),
          _strategyOption("BAL", 3, Icons.balance, mainColor),
          _strategyOption("NORM", 5, Icons.grid_view, mainColor),
          _strategyOption("OPT", 7, Icons.star_rounded, mainColor),
          _strategyOption("FAST", 10, Icons.speed, mainColor),
        ],
      ),
    );
  }

  Widget _strategyOption(String label, int value, IconData icon, Color mainColor) {
    bool isSelected = _selectedWindowSize == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedWindowSize = value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? mainColor : Colors.white24),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: GoogleFonts.rajdhani(fontSize: 8, color: isSelected ? mainColor : Colors.white24)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color mainColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("SİSTEM KONTROL PANELİ", style: TextStyle(color: Colors.white.withOpacity(0.7), letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: mainColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: mainColor.withOpacity(0.3))),
          child: Text("v2.0 STABLE", style: GoogleFonts.firaCode(fontSize: 10, color: mainColor)),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(Color mainColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: mainColor.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: mainColor.withOpacity(0.2))),
      child: Row(
        children: [
          Icon(_isTempRunning ? Icons.security : Icons.gpp_bad_outlined, color: mainColor, size: 24),
          const SizedBox(width: 12),
          Text(_isTempRunning ? "SİSTEM GÜVENLİ" : "KORUMA KAPALI", style: TextStyle(color: mainColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _windowDot(Color color) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// ---------------------------------------------------------------------------
// ANİMASYONLU WIDGET'LAR
// ---------------------------------------------------------------------------
class _AnimatedLogItem extends StatelessWidget {
  final String logText;
  final Color color;

  const _AnimatedLogItem({super.key, required this.logText, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(15 * (1 - value), 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(">", style: GoogleFonts.firaCode(color: color.withOpacity(0.5), fontSize: 11)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      logText,
                      style: GoogleFonts.firaCode(
                        fontSize: 11,
                        color: color,
                        height: 1.5,
                        shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  __BlinkingCursorState createState() => __BlinkingCursorState();
}

class __BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Row(
        children: [
          Text(">", style: GoogleFonts.firaCode(color: Colors.white24, fontSize: 11)),
          const SizedBox(width: 8),
          Container(width: 8, height: 12, color: Colors.white54),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  const _MenuButton({required this.title, required this.icon, required this.isSelected, required this.onTap, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: isSelected ? activeColor.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.white38, size: 20),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.rajdhani(color: isSelected ? activeColor : Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _CyberButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _CyberButton({required this.label, required this.icon, required this.color, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}