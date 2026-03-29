import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

void main() => runApp(const MaterialApp(home: BgApp(), debugShowCheckedModeBanner: false));

class BgApp extends StatefulWidget {
  const BgApp({super.key});
  @override
  State<BgApp> createState() => _BgAppState();
}

class _BgAppState extends State<BgApp> {
  bool _isAlwaysGranted = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Uygulama açılır açılmaz inatçı takibi başlat
    _startStubbornCheck();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Bellek sızıntısını önle
    super.dispose();
  }

  // İnatçı Takip: İzin 'Always' olana kadar her saniye sorgular
bool _isGpsEnabled = false; // Yeni değişken

void _startStubbornCheck() {
  _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
    // Mevcut durumları ham veriden çek
    LocationPermission perm = await Geolocator.checkPermission();
    bool gpsStatus = await Geolocator.isLocationServiceEnabled();

    // Sadece durum değiştiyse setState atalım ki uygulama nefes alsın
    if (mounted && (_isAlwaysGranted != (perm == LocationPermission.always) || _isGpsEnabled != gpsStatus)) {
      setState(() {
        _isAlwaysGranted = (perm == LocationPermission.always);
        _isGpsEnabled = gpsStatus;
      });
      print("LOG: Durum Güncellendi -> İzin: $_isAlwaysGranted, GPS: $_isGpsEnabled");
    }
  });
}
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('StalkGuard GPS')),
    body: Center(
      child: _buildLogicGate(),
    ),
  );
}

Widget _buildLogicGate() {
  // 1. ENGEL: İzin Yoksa
  if (!_isAlwaysGranted) {
    return _errorView(
      icon: Icons.security,
      msg: "ARKA PLAN İZNİ EKSİK\nAyarlardan 'Her Zaman'ı seç bro.",
      btnText: "İZİNLERE GİT",
      onBtnPressed: () => Geolocator.openAppSettings(),
    );
  }

  // 2. ENGEL: Donanım (GPS) Kapalıysa
  if (!_isGpsEnabled) {
    return _errorView(
      icon: Icons.location_disabled,
      msg: "GPS DONANIMI KAPALI\nYukarıdan veya ayarlardan GPS'i aç.",
      btnText: "GPS AYARLARINI AÇ",
      onBtnPressed: () => Geolocator.openLocationSettings(),
    );
  }

  // 3. YOL AÇIK: Her şey OK ise koordinat akışı
  return StreamBuilder<Position>(
    stream: Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1)
    ),
    builder: (context, snap) {
      if (snap.hasError) return const Text("GPS Hatası! Sinyal bekleniyor...");
      if (snap.hasData) {
        return Text(
          "Lat: ${snap.data!.latitude}\nLng: ${snap.data!.longitude}",
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        );
      }
      return const CircularProgressIndicator();
    },
  );
}

// Ortak Uyarı Tasarımı
Widget _errorView({required IconData icon, required String msg, required String btnText, required VoidCallback onBtnPressed}) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 80, color: Colors.redAccent),
      const SizedBox(height: 20),
      Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: onBtnPressed, child: Text(btnText)),
    ],
  );
}
}