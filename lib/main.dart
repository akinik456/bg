import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'gps_service.dart';

void main() => runApp(const MaterialApp(home: BgApp(), debugShowCheckedModeBanner: false));

class BgApp extends StatefulWidget {
  const BgApp({super.key});
  @override
  State<BgApp> createState() => _BgAppState();
}

class _BgAppState extends State<BgApp> with WidgetsBindingObserver {
  final GpsService _gps = GpsService();
  String _uiMsg = "Kontrol ediliyor...";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Ayarlardan dönüşü yakalamak için
    _initLogic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print("LOG: [Main] Ayarlardan dönüldü, kontrol tetikleniyor.");
      _initLogic();
    }
  }

  // Ana Kontrol Mekanizması
  Future<void> _initLogic() async {
    LocationPermission perm = await _gps.checkCurrentPermission();
    print("LOG: [Main] Mevcut İzin: $perm");

    // 1. Hiç izin yoksa iste
    if (perm == LocationPermission.denied) {
      perm = await _gps.requestInitialPermission();
      if (perm == LocationPermission.denied) {
        setState(() => _uiMsg = "Konum izni olmadan devam edemeyiz bro.");
        return;
      }
    }

    // 2. "While in use" var ama "Always" yoksa Diyalog çıkar
    if (perm == LocationPermission.whileInUse) {
      print("LOG: [Main] WhileInUse tamam, Always eksik. Diyalog açılıyor.");
      _showAlwaysDialog();
      return;
    }

    // 3. Her şey tamamsa
    if (perm == LocationPermission.always) {
      setState(() => _uiMsg = "OK");
    }
  }

  // Kullanıcıyı bilgilendiren o meşhur pencere
  void _showAlwaysDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Boşluğa basınca kapanmasın
      builder: (context) => AlertDialog(
        title: const Text("Arka Plan İzni Gerekli"),
        content: const Text(
          "Uygulamanın ekran kapalıyken de çalışabilmesi için ayarlardan 'Her Zaman İzin Ver' seçeneğini işaretlemen gerekiyor bro."
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Diyaloğu kapat
              await _gps.openSettings(); // Ayarları aç
            },
            child: const Text("AYARLARA GİT"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StalkGuard GPS')),
      body: Center(
        child: _uiMsg == "OK"
            ? StreamBuilder<Position>(
                stream: _gps.positionStream,
                builder: (context, snap) {
                  if (snap.hasData) {
                    return Text(
                      "Lat: ${snap.data!.latitude}\nLng: ${snap.data!.longitude}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    );
                  }
                  return const Text("GPS Verisi Bekleniyor...");
                },
              )
            : Text(_uiMsg, textAlign: TextAlign.center),
      ),
    );
  }
}