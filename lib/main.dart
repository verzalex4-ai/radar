import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'models/user_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radar de Proximidad',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const RadarScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();

  UserModel? _currentUser;
  List<UserModel> _nearbyUsers = [];
  double _radarRadius = 100.0; // metros
  bool _isLoading = true;
  String? _userName;

  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkUserName();
    await _startLocationTracking();
    _simulateNearbyUsers(); // Para pruebas
    setState(() => _isLoading = false);
  }

  Future<void> _checkUserName() async {
    final savedName = await _storageService.getUserName();

    if (savedName == null && mounted) {
      await _showNameDialog();
    } else {
      setState(() => _userName = savedName);
    }
  }

  Future<void> _showNameDialog() async {
    final TextEditingController nameController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Ingresa tu nombre'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Tu nombre',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() => _userName = nameController.text);
                _storageService.saveUserName(nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _startLocationTracking() async {
    final position = await _locationService.getCurrentPosition();

    if (position != null) {
      _updateCurrentUser(position);

      _positionSubscription = _locationService.positionStream.listen((
        position,
      ) {
        _updateCurrentUser(position);
      });

      _locationService.startLocationUpdates();
    }
  }

  void _updateCurrentUser(Position position) {
    final user = UserModel(
      id: 'current_user',
      name: _userName ?? 'Yo',
      latitude: position.latitude,
      longitude: position.longitude,
      lastUpdate: DateTime.now(),
    );

    setState(() => _currentUser = user);
    _storageService.saveCurrentUser(user);
    _updateNearbyUsers();
  }

  void _updateNearbyUsers() {
    if (_currentUser == null) return;

    setState(() {
      _nearbyUsers = _nearbyUsers.where((user) {
        final distance = _currentUser!.distanceTo(
          user.latitude,
          user.longitude,
        );
        return distance <= _radarRadius;
      }).toList();
    });
  }

  // Simulación de usuarios cercanos (para pruebas)
  void _simulateNearbyUsers() {
    if (_currentUser == null) return;

    final random = Random();
    final simulatedUsers = <UserModel>[];

    for (int i = 0; i < 5; i++) {
      // Generar posición aleatoria dentro del radio
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * _radarRadius * 1.5;

      final latOffset = (distance * cos(angle)) / 111000;
      final lonOffset =
          (distance * sin(angle)) /
          (111000 * cos(_currentUser!.latitude * pi / 180));

      simulatedUsers.add(
        UserModel(
          id: 'user_$i',
          name: 'Usuario ${i + 1}',
          latitude: _currentUser!.latitude + latOffset,
          longitude: _currentUser!.longitude + lonOffset,
          lastUpdate: DateTime.now(),
        ),
      );
    }

    setState(() => _nearbyUsers = simulatedUsers);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Radar - ${_userName ?? "Sin nombre"}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _simulateNearbyUsers,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _showNameDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text('Radio: '),
                Expanded(
                  child: Slider(
                    value: _radarRadius,
                    min: 50,
                    max: 500,
                    divisions: 9,
                    label: '${_radarRadius.round()}m',
                    onChanged: (value) {
                      setState(() => _radarRadius = value);
                      _updateNearbyUsers();
                    },
                  ),
                ),
                Text('${_radarRadius.round()}m'),
              ],
            ),
          ),
          Expanded(
            child: _currentUser != null
                ? RadarWidget(
                    currentUser: _currentUser!,
                    nearbyUsers: _nearbyUsers,
                    radarRadius: _radarRadius,
                  )
                : const Center(child: Text('Esperando ubicación...')),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1), // ← CAMBIO AQUÍ
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Usuarios detectados: ${_nearbyUsers.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    itemCount: _nearbyUsers.length,
                    itemBuilder: (context, index) {
                      final user = _nearbyUsers[index];
                      final distance = _currentUser!.distanceTo(
                        user.latitude,
                        user.longitude,
                      );

                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(user.name),
                        trailing: Text('${distance.round()}m'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}

class RadarWidget extends StatelessWidget {
  final UserModel currentUser;
  final List<UserModel> nearbyUsers;
  final double radarRadius;

  const RadarWidget({
    super.key,
    required this.currentUser,
    required this.nearbyUsers,
    required this.radarRadius,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RadarPainter(
        currentUser: currentUser,
        nearbyUsers: nearbyUsers,
        radarRadius: radarRadius,
      ),
      child: Container(),
    );
  }
}

class RadarPainter extends CustomPainter {
  final UserModel currentUser;
  final List<UserModel> nearbyUsers;
  final double radarRadius;

  RadarPainter({
    required this.currentUser,
    required this.nearbyUsers,
    required this.radarRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 - 20;

    // Fondo
    final backgroundPaint = Paint()..color = Colors.grey[900]!;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // Círculos del radar
    for (int i = 1; i <= 4; i++) {
      final circlePaint = Paint()
        ..color = Colors.green.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawCircle(center, maxRadius * i / 4, circlePaint);
    }

    // Líneas cruzadas
    final linePaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      linePaint,
    );

    // Usuario actual (punto azul en el centro)
    final currentUserPaint = Paint()..color = Colors.blue;
    canvas.drawCircle(center, 8, currentUserPaint);

    // Borde blanco para el usuario actual
    final currentUserBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 8, currentUserBorderPaint);

    // Usuarios cercanos
    for (var user in nearbyUsers) {
      final distance = currentUser.distanceTo(user.latitude, user.longitude);

      if (distance <= radarRadius) {
        // Calcular posición relativa
        final latDiff = user.latitude - currentUser.latitude;
        final lonDiff = user.longitude - currentUser.longitude;

        // Convertir a coordenadas del radar
        final x =
            center.dx +
            (lonDiff *
                111000 *
                cos(currentUser.latitude * pi / 180) /
                radarRadius *
                maxRadius);
        final y = center.dy - (latDiff * 111000 / radarRadius * maxRadius);

        // Dibujar usuario
        final userPaint = Paint()..color = Colors.orange;
        canvas.drawCircle(Offset(x, y), 6, userPaint);

        // Borde
        final userBorderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset(x, y), 6, userBorderPaint);

        // Nombre del usuario
        final textPainter = TextPainter(
          text: TextSpan(
            text: user.name,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, y + 10));
      }
    }

    // Leyenda
    _drawLegend(canvas, size);
  }

  void _drawLegend(Canvas canvas, Size size) {
    const legendY = 20.0;
    const legendX = 20.0;

    // Usuario actual
    final currentUserPaint = Paint()..color = Colors.blue;
    canvas.drawCircle(const Offset(legendX, legendY), 6, currentUserPaint);

    final currentUserText = TextPainter(
      text: const TextSpan(
        text: 'Tu ubicación',
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    currentUserText.layout();
    currentUserText.paint(canvas, const Offset(legendX + 15, legendY - 6));

    // Usuarios cercanos
    final nearbyUserPaint = Paint()..color = Colors.orange;
    canvas.drawCircle(const Offset(legendX, legendY + 25), 6, nearbyUserPaint);

    final nearbyUserText = TextPainter(
      text: const TextSpan(
        text: 'Usuarios cercanos',
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    nearbyUserText.layout();
    nearbyUserText.paint(canvas, const Offset(legendX + 15, legendY + 19));
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) => true;
}
