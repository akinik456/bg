import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// --- ARKA PLAN SERVİS YAPILANDIRMASI ---

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Android için bildirim kanalı oluşturma (Zorunlu)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'bg_service_channel', 
    'BG SERVICE', 
    description: 'Arka planda konum takibi yapar.',
    importance: Importance.low, 
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true, 
      isForegroundMode: true,
      notificationChannelId: 'bg_service_channel',
      initialNotificationTitle: 'BG SİSTEMİ',
      initialNotificationContent: 'Takip ve koruma aktif.',
      foregroundServiceNotificationId: 888,
      // Hatalı 'forceRepoer...' satırını buradan sildik
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
}

// BU FONKSİYON UYGULAMA KAPALIYKEN ÇALIŞAN "HAYALET"TİR
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
  
  // 10 saniyelik döngü içinde bildirimi güncel tut
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "BG GÜVENLİK AKTİF",
          content: "📍 Takip Devam Ediyor: ${DateTime.now().hour}:${DateTime.now().minute}",
        );
      }
    }
  
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    // 1. Konum Al
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 2. Dosyaya Yaz (Arka planda direkt path_provider kullanamayabiliriz, statik yol lazım)
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/bg_logs.txt');
      final String timestamp = DateTime.now().toString().split('.').first;
      
      String logLine = "[$timestamp] BG-BACK: ${position.latitude}, ${position.longitude}\n";
      await file.writeAsString(logLine, mode: FileMode.append);
      
      print("👻 HAYALET YAZDI: $logLine");

      // 3. Bildirimi Güncelle (Kullanıcı çalıştığını görsün)
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "BG ÇALIŞIYOR",
          content: "Son Lokasyon: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}",
        );
      }
    } catch (e) {
      print("HAYALET HATASI: $e");
    }
  });
}

// --- ANA UYGULAMA (ARAYÜZ) ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService(); // Servisi başlat
  runApp(const MaterialApp(home: BgApp(), debugShowCheckedModeBanner: false));
}

class BgApp extends StatefulWidget {
  const BgApp({super.key});
  @override
  State<BgApp> createState() => _BgAppState();
}

class _BgAppState extends State<BgApp> {
  // Önceki checklist ve UI mantığını buraya aynen koyabilirsin.
  // Ama artık veriyi StreamBuilder yerine "Karakutu Okuma" butonuyla takip edeceğiz.
  
  bool _isAlwaysGranted = false;
  bool _isGpsEnabled = false;
  bool _isBatteryDone = false;
  bool _isAutostartDone = false;

  @override
  void initState() {
    super.initState();
    _checkStatusLoop();
  }

  void _checkStatusLoop() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      LocationPermission perm = await Geolocator.checkPermission();
      bool gps = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() {
          _isAlwaysGranted = (perm == LocationPermission.always);
          _isGpsEnabled = gps;
        });
      }
    });
  }

  Future<void> _readLogs() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/bg_logs.txt');
    if (await file.exists()) {
      print("\n📂 --- BG KARAKUTU (ARKA PLAN DAHİL) --- 📂");
      print(await file.readAsString());
    } else {
      print("⚠️ Kayıt yok.");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool ready = _isAlwaysGranted && _isGpsEnabled && _isBatteryDone && _isAutostartDone;

    return Scaffold(
      appBar: AppBar(
        title: const Text("BG CONTROL"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.history), onPressed: _readLogs)],
      ),
      body: ready 
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.radar, size: 100, color: Colors.blue),
              const Text("BG ARKA PLANDA ÇALIŞIYOR", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text("Uygulamayı kapatabilirsin, hayalet işçi görevde.", textAlign: TextAlign.center),
            ],
          ))
        : _buildSetupView(), // Önceki Checklist fonksiyonunu buraya ekle
    );
  }

  // Önceki mesajdaki _buildSetupView, _checkTile ve _showManualConfirm fonksiyonlarını buraya yapıştır...
  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text("SİSTEM HAZIRLIK", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(),
          _tile("Konum: Her Zaman", _isAlwaysGranted, () => Geolocator.openAppSettings()),
          _tile("GPS Açık", _isGpsEnabled, () => Geolocator.openLocationSettings()),
          _tile("Pil: Kısıtlama Yok", _isBatteryDone, () => _confirm("Pil", "Seçtin mi?", () => setState(() => _isBatteryDone = true))),
          _tile("Autostart", _isAutostartDone, () => _confirm("Autostart", "Açtın mı?", () => setState(() => _isAutostartDone = true))),
        ],
      ),
    );
  }

  Widget _tile(String t, bool s, VoidCallback o) => ListTile(
    title: Text(t), 
    leading: Icon(s ? Icons.check : Icons.close, color: s ? Colors.green : Colors.red),
    trailing: s ? null : ElevatedButton(onPressed: o, child: const Text("GİT")),
  );

  void _confirm(String t, String m, VoidCallback c) => showDialog(
    context: context, 
    builder: (ctx) => AlertDialog(title: Text(t), content: Text(m), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HAYIR")),
      ElevatedButton(onPressed: () { c(); Navigator.pop(ctx); }, child: const Text("EVET")),
    ])
  );
}