import 'dart:convert';
import 'dart:math';

class UserModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime lastUpdate;

  UserModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.lastUpdate,
  });

  // Calcular distancia entre dos puntos (en metros)
  double distanceTo(double lat, double lon) {
    const double earthRadius = 6371000; // metros

    double dLat = _toRadians(lat - latitude);
    double dLon = _toRadians(lon - longitude);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(latitude)) *
            cos(_toRadians(lat)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'lastUpdate': lastUpdate.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      lastUpdate: DateTime.parse(json['lastUpdate']),
    );
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory UserModel.fromJsonString(String jsonString) {
    return UserModel.fromJson(jsonDecode(jsonString));
  }

  UserModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    DateTime? lastUpdate,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}
