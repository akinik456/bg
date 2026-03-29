import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'gps_service.dart';

class LocationView extends StatefulWidget {
  const LocationView({super.key});

  @override
  State<LocationView> createState() => _LocationViewState();
}

class _LocationViewState extends State<LocationView> {
  final GpsService _gpsService = GpsService();
  String _status = "Başlatılıyor...";

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() async {
    String result = await _gpsService.checkAndRequestPermissions();
    setState(() {
      _status = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BG Tracker')),
      body: Center(
        child: _status == "OK" 
          ? StreamBuilder<Position>(
              stream: _gpsService.positionStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    "Lat: ${snapshot.data!.latitude}\nLng: ${snapshot.data!.longitude}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                  );
                }
                return const CircularProgressIndicator();
              },
            )
          : Text(_status, style: const TextStyle(color: Colors.red, fontSize: 20)),
      ),
    );
  }
}