import 'package:geolocator/geolocator.dart';

class GpsService {
  // 1 metre hassasiyetle konum akışı
  Stream<Position> get positionStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, 
    ),
  );

  // İzin durumunu kontrol eden ana fonksiyon
  Future<LocationPermission> checkCurrentPermission() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return LocationPermission.denied; // GPS Kapalıysa
    return await Geolocator.checkPermission();
  }

  // İlk aşama: Standart izin isteme
  Future<LocationPermission> requestInitialPermission() async {
    return await Geolocator.requestPermission();
  }

  // Ayarları açma fonksiyonu
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}