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
  void _startStubbornCheck() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      LocationPermission perm = await Geolocator.checkPermission();
      print("LOG: Mevcut Durum Sorgulanıyor: $perm");

      if (perm == LocationPermission.always) {
        if (mounted) {
          setState(() => _isAlwaysGranted = true);
        }
        timer.cancel(); // İzin alındı, artık rahat bırak sistemi
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StalkGuard GPS')),
      body: Center(
        child: _isAlwaysGranted 
          ? StreamBuilder<Position>(
              stream: Geolocator.getPositionStream(
                locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1)
              ),
              builder: (context, snap) {
                if (snap.hasData) {
                  return Text(
                    "Lat: ${snap.data!.latitude}\nLng: ${snap.data!.longitude}",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  );
                }
                return const CircularProgressIndicator();
              },
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orange),
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "AYARLARDAN 'HER ZAMAN' SEÇMEN LAZIM.\nSeçtiğin an bu ekran kendiliğinden değişecek bro.",
                    textAlign: TextAlign.center,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Geolocator.openAppSettings(),
                  child: const Text("AYARLARI AÇ"),
                ),
              ],
            ),
      ),
    );
  }
}