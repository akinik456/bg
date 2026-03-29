import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MaterialApp(
    home: BgApp(),
    debugShowCheckedModeBanner: false,
    title: "BG",
  ));
}

class BgApp extends StatefulWidget {
  const BgApp({super.key});

  @override
  State<BgApp> createState() => _BgAppState();
}

class _BgAppState extends State<BgApp> {
  // Otomatik Kontroller
  bool _isAlwaysGranted = false;
  bool _isGpsEnabled = false;

  // Manuel (Kullanıcı Onayı) Kontroller
  bool _isBatteryDone = false;
  bool _isAutostartDone = false;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startStubbornCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // İnatçı Takip: İzin ve GPS donanımını saniyede bir sorgular
  void _startStubbornCheck() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      LocationPermission perm = await Geolocator.checkPermission();
      bool gpsStatus = await Geolocator.isLocationServiceEnabled();

      if (mounted) {
        setState(() {
          _isAlwaysGranted = (perm == LocationPermission.always);
          _isGpsEnabled = gpsStatus;
        });
      }
    });
  }

  // Karakutu Yazma
  Future<void> _recordLog(Position pos) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/bg_logs.txt');
      final String timestamp = DateTime.now().toString().split('.').first;
      final String logLine = "[$timestamp] Lat: ${pos.latitude}, Lng: ${pos.longitude}\n";

      await file.writeAsString(logLine, mode: FileMode.append);
      print("📝 BG LOG: $logLine");
    } catch (e) {
      print("❌ BG YAZMA HATASI: $e");
    }
  }

  // Karakutu Okuma (Terminale Dökme)
  Future<void> _readAllLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/bg_logs.txt');

      if (await file.exists()) {
        final String content = await file.readAsString();
        print("\n📂 --- BG KARAKUTU KAYITLARI --- 📂");
        print(content);
        print("----------------------------------\n");
      } else {
        print("⚠️ BG: Henüz kayıtlı veri yok.");
      }
    } catch (e) {
      print("❌ BG OKUMA HATASI: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool allSystemGo = _isAlwaysGranted && _isGpsEnabled && _isBatteryDone && _isAutostartDone;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('BG CONTROL CENTER'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _readAllLogs,
          ),
        ],
      ),
      body: allSystemGo ? _buildTrackingView() : _buildSetupView(),
    );
  }

  // 1. KURULUM EKRANI (Checklist)
  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.settings_suggest, size: 60, color: Colors.blueGrey),
          const SizedBox(height: 10),
          const Text("SİSTEM HAZIRLIK", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(height: 40),
          
          // Konum İzni
          _checkTile(
            title: "Konum: 'Her Zaman'",
            subtitle: "Uygulama Bilgisi -> İzinler -> Konum",
            status: _isAlwaysGranted,
            onAction: () => Geolocator.openAppSettings(),
          ),

          // GPS Donanım
          _checkTile(
            title: "GPS Donanımı (Konum Servisi)",
            subtitle: "Telefonun GPS'ini aktif et",
            status: _isGpsEnabled,
            onAction: () => Geolocator.openLocationSettings(),
          ),

          // Pil Kısıtlaması (Manuel Onay)
          _checkTile(
            title: "Pil: 'Kısıtlama Yok'",
            subtitle: "Uygulama Bilgisi -> Pil Tasarrufu",
            status: _isBatteryDone,
            onAction: () => _showManualConfirm(
              "Pil Ayarı",
              "Uygulama Bilgisi sayfasında 'Pil Tasarrufu' bölümüne girip 'Kısıtlama Yok' (No Restrictions) seçeneğini işaretlediniz mi?",
              () => setState(() => _isBatteryDone = true),
            ),
          ),

          // Autostart (Manuel Onay)
          _checkTile(
            title: "Otomatik Başlatma",
            subtitle: "Xiaomi Güvenlik veya Ayarlar -> Arama",
            status: _isAutostartDone,
            onAction: () => _showManualConfirm(
              "Autostart (Xiaomi)",
              "1. 'Güvenlik' uygulamasını aç veya ayarlarda 'Otomatik Başlatma' (Autostart) diye arat.\n2. Listeden BG'yi bul ve aç.\n\nYaptın mı bro?",
              () => setState(() => _isAutostartDone = true),
            ),
          ),
          
          const SizedBox(height: 30),
          const Text("Tüm maddeler yeşil olduğunda BG çalışmaya başlar.", 
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // 2. TAKİP EKRANI (Her Şey Tamamsa)
  Widget _buildTrackingView() {
    return StreamBuilder<Position>(
      stream: Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1),
      ),
      builder: (context, snap) {
        if (snap.hasData) {
          _recordLog(snap.data!);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.radar, size: 100, color: Colors.green),
                const SizedBox(height: 30),
                Text("Lat: ${snap.data!.latitude}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Lng: ${snap.data!.longitude}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                const Text("BG AKTİF: Veriler Karakutuya İşleniyor...", style: TextStyle(color: Colors.blueGrey)),
              ],
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  // Görsel Yardımcılar
  Widget _checkTile({required String title, required String subtitle, required bool status, required VoidCallback onAction}) {
    return Card(
      elevation: 0,
      color: status ? Colors.green.withOpacity(0.1) : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(status ? Icons.check_circle : Icons.circle_outlined, color: status ? Colors.green : Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: status ? null : ElevatedButton(onPressed: onAction, child: const Text("AYARLA")),
      ),
    );
  }

  void _showManualConfirm(String title, String msg, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HENÜZ DEĞİL")),
          ElevatedButton(onPressed: () { onConfirm(); Navigator.pop(ctx); }, child: const Text("EVET, YAPTIM")),
        ],
      ),
    );
  }
}