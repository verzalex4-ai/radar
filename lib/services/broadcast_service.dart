import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/user_model.dart';

class BroadcastService {
  final Nearby _nearby = Nearby();
  final StreamController<List<UserModel>> _nearbyUsersController =
      StreamController<List<UserModel>>.broadcast();

  final Map<String, UserModel> _discoveredUsers = {};
  final List<String> _connectedDevices = [];

  String? _currentUserName;
  UserModel? _currentUser;

  Stream<List<UserModel>> get nearbyUsersStream =>
      _nearbyUsersController.stream;

  // Iniciar advertising (anunciar presencia)
  Future<void> startAdvertising(String userName) async {
    _currentUserName = userName;

    try {
      await _nearby.startAdvertising(
        userName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: 'com.example.rada_prueba',
      );
    } catch (e) {
      // Error en advertising: $e
    }
  }

  // Iniciar discovery (buscar dispositivos)
  Future<void> startDiscovery() async {
    try {
      await _nearby.startDiscovery(
        _currentUserName ?? 'Usuario',
        Strategy.P2P_CLUSTER,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: 'com.example.rada_prueba',
      );
    } catch (e) {
      // Error en discovery: $e
    }
  }

  // Cuando se encuentra un dispositivo
  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) {
    // Solicitar conexión automáticamente
    _nearby.requestConnection(
      _currentUserName ?? 'Usuario',
      endpointId,
      onConnectionInitiated: _onConnectionInit,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
  }

  // Cuando se pierde un dispositivo
  void _onEndpointLost(String? endpointId) {
    if (endpointId != null) {
      _discoveredUsers.remove(endpointId);
      _connectedDevices.remove(endpointId);
      _updateNearbyUsers();
    }
  }

  // Cuando se inicia una conexión
  void _onConnectionInit(String endpointId, ConnectionInfo info) {
    // Aceptar conexión automáticamente
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpointId, payload) {
        _onPayloadReceived(endpointId, payload);
      },
    );
  }

  // Resultado de la conexión
  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedDevices.add(endpointId);

      // Enviar información del usuario actual
      if (_currentUser != null) {
        _sendUserData(endpointId, _currentUser!);
      }
    }
  }

  // Cuando se desconecta un dispositivo
  void _onDisconnected(String endpointId) {
    _discoveredUsers.remove(endpointId);
    _connectedDevices.remove(endpointId);
    _updateNearbyUsers();
  }

  // Recibir datos de otros usuarios
  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      try {
        final String data = String.fromCharCodes(payload.bytes!);
        final Map<String, dynamic> userData = jsonDecode(data);

        final user = UserModel.fromJson(userData);
        _discoveredUsers[endpointId] = user;
        _updateNearbyUsers();
      } catch (e) {
        // Error al procesar datos: $e
      }
    }
  }

  // Enviar datos del usuario
  void _sendUserData(String endpointId, UserModel user) {
    final String data = jsonEncode(user.toJson());
    final Uint8List bytes = Uint8List.fromList(data.codeUnits);

    _nearby.sendBytesPayload(endpointId, bytes);
  }

  // Broadcast de la ubicación actual
  void broadcastUser(UserModel user) {
    _currentUser = user;

    // Enviar a todos los dispositivos conectados
    for (String endpointId in _connectedDevices) {
      _sendUserData(endpointId, user);
    }
  }

  // Actualizar lista de usuarios cercanos
  void _updateNearbyUsers() {
    final users = _discoveredUsers.values.toList();
    _nearbyUsersController.add(users);
  }

  // Detener servicios
  Future<void> stop() async {
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _nearby.stopAllEndpoints();

    _discoveredUsers.clear();
    _connectedDevices.clear();
    _updateNearbyUsers();
  }

  void dispose() {
    stop();
    _nearbyUsersController.close();
  }
}
