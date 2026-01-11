import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;

  Future<bool> requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      status = await Permission.location.request();
      return status.isGranted;
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<Position?> getCurrentPosition() async {
    bool hasPermission = await requestLocationPermission();
    if (!hasPermission) return null;

    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      // Error obteniendo ubicación: $e
      return null;
    }
  }

  void startLocationUpdates() async {
    bool hasPermission = await requestLocationPermission();
    if (!hasPermission) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualizar cada 10 metros
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _positionController.add(position);
          },
          onError: (error) {
            // Error en stream de ubicación: $error
          },
        );
  }

  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  void dispose() {
    stopLocationUpdates();
    _positionController.close();
  }
}
