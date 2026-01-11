import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_model.dart';

class BroadcastService {
  final Nearby _nearby = Nearby();
  final StreamController<List<UserModel>> _nearbyUsersController =
      StreamController<List<UserModel>>.broadcast();

  final Map<String, UserModel> _discoveredUsers = {};
  final List<String> _connectedDevices = [];

  String? _currentUserName;
  UserModel? _currentUser;
  bool _isRunning = false;

  Stream<List<UserModel>> get nearbyUsersStream =>
      _nearbyUsersController.stream;

  // Verificar y solicitar permisos necesarios
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.nearbyWifiDevices,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      print('❌ Algunos permisos fueron denegados:');
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          print('  - ${permission.toString()}: $status');
        }
      });
    }

    return allGranted;
  }

  // Iniciar advertising y discovery
  Future<bool> start(String userName) async {
    if (_isRunning) {
      print('⚠️ El servicio ya está ejecutándose');
      return true;
    }

    _currentUserName = userName;

    // Verificar permisos
    bool hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      print('❌ Permisos insuficientes para iniciar el servicio');
      return false;
    }

    try {
      // Iniciar advertising
      bool advertisingStarted = await startAdvertising(userName);
      if (!advertisingStarted) {
        print('❌ Error al iniciar advertising');
        return false;
      }

      // Iniciar discovery
      bool discoveryStarted = await startDiscovery();
      if (!discoveryStarted) {
        print('❌ Error al iniciar discovery');
        await _nearby.stopAdvertising();
        return false;
      }

      _isRunning = true;
      print('✅ Servicio iniciado correctamente');
      return true;
    } catch (e) {
      print('❌ Error al iniciar el servicio: $e');
      return false;
    }
  }

  // Iniciar advertising (anunciar presencia)
  Future<bool> startAdvertising(String userName) async {
    try {
      bool result = await _nearby.startAdvertising(
        userName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: 'com.example.rada_prueba',
      );

      if (result) {
        print('✅ Advertising iniciado: $userName');
      } else {
        print('❌ No se pudo iniciar advertising');
      }

      return result;
    } catch (e) {
      print('❌ Error en startAdvertising: $e');
      return false;
    }
  }

  // Iniciar discovery (buscar dispositivos)
  Future<bool> startDiscovery() async {
    try {
      bool result = await _nearby.startDiscovery(
        _currentUserName ?? 'Usuario',
        Strategy.P2P_CLUSTER,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: 'com.example.rada_prueba',
      );

      if (result) {
        print('✅ Discovery iniciado');
      } else {
        print('❌ No se pudo iniciar discovery');
      }

      return result;
    } catch (e) {
      print('❌ Error en startDiscovery: $e');
      return false;
    }
  }

  // Cuando se encuentra un dispositivo
  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) {
    print('📡 Dispositivo encontrado: $endpointName ($endpointId)');

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
      print('📵 Dispositivo perdido: $endpointId');
      _discoveredUsers.remove(endpointId);
      _connectedDevices.remove(endpointId);
      _updateNearbyUsers();
    }
  }

  // Cuando se inicia una conexión
  void _onConnectionInit(String endpointId, ConnectionInfo info) {
    print('🔗 Conexión iniciada con: $endpointId');

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
      print('✅ Conectado a: $endpointId');
      _connectedDevices.add(endpointId);

      // Enviar información del usuario actual
      if (_currentUser != null) {
        _sendUserData(endpointId, _currentUser!);
      }
    } else {
      print('❌ Error al conectar con: $endpointId');
    }
  }

  // Cuando se desconecta un dispositivo
  void _onDisconnected(String endpointId) {
    print('🔌 Desconectado de: $endpointId');
    _discoveredUsers.remove(endpointId);
    _connectedDevices.remove(endpointId);
    _updateNearbyUsers();
  }

  // Recibir datos de otros usuarios
  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      try {
        final String data = String.fromCharCodes(payload.bytes!);
        final Map<String, dynamic> userData = jsonDecode(data);

        final user = UserModel.fromJson(userData);
        _discoveredUsers[endpointId] = user;
        _updateNearbyUsers();

        print('📥 Datos recibidos de: ${user.name}');
      } catch (e) {
        print('❌ Error al procesar datos: $e');
      }
    }
  }

  // Enviar datos del usuario
  void _sendUserData(String endpointId, UserModel user) {
    try {
      final String data = jsonEncode(user.toJson());
      final Uint8List bytes = Uint8List.fromList(data.codeUnits);

      _nearby.sendBytesPayload(endpointId, bytes);
      print('📤 Datos enviados a: $endpointId');
    } catch (e) {
      print('❌ Error al enviar datos: $e');
    }
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
    if (!_isRunning) {
      return;
    }

    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();

      _discoveredUsers.clear();
      _connectedDevices.clear();
      _updateNearbyUsers();

      _isRunning = false;
      print('🛑 Servicio detenido');
    } catch (e) {
      print('❌ Error al detener servicio: $e');
    }
  }

  void dispose() {
    stop();
    _nearbyUsersController.close();
  }
}
