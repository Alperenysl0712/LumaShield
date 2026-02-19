import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/dpi_service.dart';

void main() {
  runApp(const LumaShieldApp());
}

class LumaShieldApp extends StatelessWidget {
  const LumaShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // ENG: Dark theme setup with futuristic font - TR: Fütüristik font ile karanlık tema kurulumu
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme),
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  final DpiService _dpiService = DpiService();
  final List<String> _logs = [];

  bool _isTempRunning = false;
  final ScrollController _scrollController = ScrollController();

  // ENG: Animation for breathing background effect - TR: Nefes alan arka plan efekti için animasyon
  late AnimationController _bgController;
  late Animation<Alignment> _bgAnimation;

  @override
  void initState() {
    super.initState();

    // ENG: Initialize background movement (Nebula effect) - TR: Arka plan hareketini başlat (Nebula efekti)
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _bgAnimation = AlignmentTween(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));

    // ENG: Log listener with auto-scroll logic - TR: Otomatik kaydırma mantığı ile log dinleyicisi
    _dpiService.onLogReceived = (message) {
      if (!mounted) return;
      setState(() {
        _logs.add(message);
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      });
    };
  }

  @override
  void dispose() {
    // ENG: Ensure engine stops and controllers are disposed - TR: Motorun durduğundan ve controller'ların temizlendiğinden emin ol
    _dpiService.stopTemporary();
    _bgController.dispose();
    super.dispose();
  }

  // --- ACTIONS / AKSİYONLAR ---

  // ENG: Toggle logic for the temporary engine - TR: Geçici motor için aç/kapat mantığı
  void _toggleTempEngine() async {
    if (_isTempRunning) {
      await _dpiService.stopTemporary();
      setState(() {
        _isTempRunning = false;
      });
    } else {
      await _dpiService.startTemporary();
      // ENG: Confirm engine status after a short delay - TR: Kısa bir süre sonra motor durumunu teyit et
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isTempRunning = _dpiService.isRunning;
          });
        }
      });
    }
  }

  void _installService() async => await _dpiService.installPermanent();
  void _removeService() async => await _dpiService.removePermanent();

  @override
  Widget build(BuildContext context) {
    // ENG: Dynamic UI colors based on engine state - TR: Motor durumuna göre dinamik UI renkleri
    Color mainColor = _isTempRunning ? const Color(0xFF00FF94) : const Color(0xFFFF2A4D);
    Color bgColor = _isTempRunning ? const Color(0xFF05140A) : const Color(0xFF140505);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ENG: LAYER 1: Animated Ambient Light - TR: 1. KATMAN: Hareketli Ortam Işığı
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: _bgAnimation.value,
                    radius: 1.2,
                    colors: [
                      mainColor.withOpacity(0.3),
                      bgColor,
                    ],
                  ),
                ),
              );
            },
          ),

          // ENG: LAYER 2: Glassmorphism Blur Effect - TR: 2. KATMAN: Buzlu Cam Efekti
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.transparent),
          ),

          // ENG: LAYER 3: Main UI Content - TR: 3. KATMAN: Ana UI İçeriği
          Row(
            children: [
              // --- LEFT PANEL: CONTROLS / SOL PANEL: KONTROLLER ---
              Container(
                width: 280,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LOGO BLOCK
                    Row(
                      children: [
                        Icon(Icons.shield, color: mainColor, size: 28),
                        const SizedBox(width: 12),
                        Text("LUMA", style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text("SHIELD", style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold, color: mainColor)),
                      ],
                    ),

                    const SizedBox(height: 50),

                    // STATUS INDICATOR / DURUM GÖSTERGESİ
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: mainColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: mainColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isTempRunning ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: mainColor,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isTempRunning ? "SİSTEM GÜVENLİ" : "KORUMA KAPALI",
                                style: TextStyle(color: mainColor, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                _isTempRunning ? "Tünel Aktif" : "Risk Altında",
                                style: TextStyle(color: mainColor.withOpacity(0.7), fontSize: 11),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                    Text("KONTROL MERKEZİ", style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    // BUTTONS / BUTONLAR
                    _CyberButton(
                      label: _isTempRunning ? "KORUMAYI DURDUR" : "GEÇİCİ BAŞLAT",
                      icon: Icons.power_settings_new,
                      color: mainColor,
                      isActive: true,
                      onTap: _toggleTempEngine,
                    ),
                    const SizedBox(height: 15),
                    _CyberButton(
                      label: "KALICI KURULUM",
                      icon: Icons.all_inclusive,
                      color: Colors.blueAccent,
                      isActive: false,
                      onTap: _installService,
                    ),
                    const SizedBox(height: 15),
                    _CyberButton(
                      label: "SERVİSİ KALDIR",
                      icon: Icons.delete_outline,
                      color: Colors.grey,
                      isActive: false,
                      onTap: _removeService,
                    ),
                  ],
                ),
              ),

              // --- RIGHT PANEL: TERMINAL / SAĞ PANEL: TERMİNAL ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("CANLI TRAFİK AKIŞI", style: TextStyle(color: Colors.white38, letterSpacing: 1)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                            child: Text("v1.0 STABLE", style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white70)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // TERMINAL WINDOW / TERMİNAL PENCERESİ
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF080808).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              children: [
                                // TERMINAL HEADER / TERMİNAL BAŞLIĞI
                                Container(
                                  width: double.infinity,
                                  height: 30,
                                  color: Colors.white.withOpacity(0.05),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      _windowDot(Colors.red),
                                      const SizedBox(width: 6),
                                      _windowDot(Colors.amber),
                                      const SizedBox(width: 6),
                                      _windowDot(Colors.green),
                                      const SizedBox(width: 10),
                                      Text("root@luma_engine", style: GoogleFonts.firaCode(fontSize: 11, color: Colors.white30)),
                                    ],
                                  ),
                                ),

                                // LOG LIST / LOG LİSTESİ
                                Expanded(
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(15),
                                    itemCount: _logs.length,
                                    itemBuilder: (context, index) {
                                      final log = _logs[index];
                                      // ENG: Conditional coloring for log entries - TR: Log girişleri için koşullu renklendirme
                                      Color logColor = const Color(0xFFCCCCCC);
                                      if (log.contains("HATA")) logColor = const Color(0xFFFF4444);
                                      if (log.contains("Bypass")) logColor = const Color(0xFF00FF94);
                                      if (log.contains("Aktif")) logColor = Colors.cyanAccent;

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Text(
                                          "> $log",
                                          style: GoogleFonts.firaCode(fontSize: 12, color: logColor, height: 1.3),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _windowDot(Color color) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// CUSTOM BUTTON WIDGET / ÖZEL BUTON WIDGET'I
class _CyberButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _CyberButton({required this.label, required this.icon, required this.color, required this.isActive, required this.onTap});

  @override
  State<_CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<_CyberButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // ENG: Calculate glow intensity - TR: Parlama yoğunluğunu hesapla
    bool glow = widget.isActive && (widget.color != Colors.grey);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(glow || _isHovered ? 0.2 : 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: widget.color.withOpacity(glow || _isHovered ? 1.0 : 0.3),
                width: 1.5
            ),
            boxShadow: (glow || _isHovered) ? [
              BoxShadow(color: widget.color.withOpacity(0.3), blurRadius: 15, spreadRadius: 1)
            ] : [],
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.color, size: 22),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}