import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'services/broadcast_service.dart';
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.greenAccent,
          brightness: Brightness.dark,
        ),
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

class _RadarScreenState extends State<RadarScreen>
    with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();
  final BroadcastService _broadcastService = BroadcastService();

  UserModel? _currentUser;
  List<UserModel> _nearbyUsers = [];
  double _radarRadius = 100.0;
  bool _isLoading = true;
  String? _userName;
  bool _isScanning = false;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<UserModel>>? _nearbyUsersSubscription;
  late AnimationController _radarAnimationController;
  late AnimationController _pulseAnimationController;

  @override
  void initState() {
    super.initState();
    _radarAnimationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkUserName();
    await _startLocationTracking();
    await _startBroadcasting();
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
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Ingresa tu nombre',
          style: TextStyle(color: Colors.greenAccent),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tu nombre',
            hintStyle: const TextStyle(color: Colors.white54),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Colors.greenAccent.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.greenAccent, width: 2),
            ),
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
            child: const Text(
              'Guardar',
              style: TextStyle(color: Colors.greenAccent),
            ),
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
    _broadcastService.broadcastUser(user);
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

  Future<void> _startBroadcasting() async {
    if (_currentUser == null) return;

    setState(() => _isScanning = true);

    await _broadcastService.startAdvertising(_userName ?? 'Usuario');
    await _broadcastService.startDiscovery();

    _nearbyUsersSubscription = _broadcastService.nearbyUsersStream.listen((
      users,
    ) {
      if (_currentUser == null) return;

      setState(() {
        _nearbyUsers = users.where((user) {
          final distance = _currentUser!.distanceTo(
            user.latitude,
            user.longitude,
          );
          return distance <= _radarRadius && user.id != _currentUser!.id;
        }).toList();
      });
    });
  }

  Future<void> _toggleScanning() async {
    if (_isScanning) {
      await _broadcastService.stop();
      setState(() {
        _isScanning = false;
        _nearbyUsers.clear();
      });
    } else {
      await _startBroadcasting();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Radar - ${_userName ?? "Sin nombre"}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.greenAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
            onPressed: _toggleScanning,
            tooltip: _isScanning ? 'Detener escaneo' : 'Iniciar escaneo',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _showNameDialog,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.grey[900]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar, color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    const Text(
                      'Radio de detección:',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Expanded(
                      child: Slider(
                        value: _radarRadius,
                        min: 50,
                        max: 500,
                        divisions: 9,
                        activeColor: Colors.greenAccent,
                        inactiveColor: Colors.grey[800],
                        label: '${_radarRadius.round()}m',
                        onChanged: (value) {
                          setState(() => _radarRadius = value);
                          _updateNearbyUsers();
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.greenAccent, width: 1),
                      ),
                      child: Text(
                        '${_radarRadius.round()}m',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isScanning ? Icons.wifi_tethering : Icons.wifi_off,
                      color: _isScanning ? Colors.greenAccent : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isScanning ? 'Escaneando...' : 'Escaneo detenido',
                      style: TextStyle(
                        color: _isScanning ? Colors.greenAccent : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _currentUser != null
                ? RadarWidget(
                    currentUser: _currentUser!,
                    nearbyUsers: _nearbyUsers,
                    radarRadius: _radarRadius,
                    radarAnimation: _radarAnimationController,
                    pulseAnimation: _pulseAnimationController,
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.greenAccent),
                        SizedBox(height: 16),
                        Text(
                          'Esperando ubicación...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[900]!, Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.people,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Dispositivos detectados: ${_nearbyUsers.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: _nearbyUsers.isEmpty
                      ? Center(
                          child: Text(
                            _isScanning
                                ? 'No hay dispositivos cercanos'
                                : 'Presiona play para escanear',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _nearbyUsers.length,
                          itemBuilder: (context, index) {
                            final user = _nearbyUsers[index];
                            final distance = _currentUser!.distanceTo(
                              user.latitude,
                              user.longitude,
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.greenAccent.withValues(alpha: 0.1),
                                    Colors.transparent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.greenAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withValues(
                                      alpha: 0.2,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                                title: Text(
                                  user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  'Última actualización: ${_formatTime(user.lastUpdate)}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getDistanceColor(distance),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${distance.round()}m',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'hace ${diff.inSeconds}s';
    } else if (diff.inMinutes < 60) {
      return 'hace ${diff.inMinutes}min';
    } else {
      return 'hace ${diff.inHours}h';
    }
  }

  Color _getDistanceColor(double distance) {
    if (distance < 50) {
      return Colors.red.withValues(alpha: 0.8);
    } else if (distance < 150) {
      return Colors.orange.withValues(alpha: 0.8);
    } else {
      return Colors.green.withValues(alpha: 0.8);
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _nearbyUsersSubscription?.cancel();
    _locationService.dispose();
    _broadcastService.stop();
    _radarAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }
}

class RadarWidget extends StatelessWidget {
  final UserModel currentUser;
  final List<UserModel> nearbyUsers;
  final double radarRadius;
  final AnimationController radarAnimation;
  final AnimationController pulseAnimation;

  const RadarWidget({
    super.key,
    required this.currentUser,
    required this.nearbyUsers,
    required this.radarRadius,
    required this.radarAnimation,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([radarAnimation, pulseAnimation]),
      builder: (context, child) {
        return CustomPaint(
          painter: RadarPainter(
            currentUser: currentUser,
            nearbyUsers: nearbyUsers,
            radarRadius: radarRadius,
            sweepAngle: radarAnimation.value * 2 * pi,
            pulseValue: pulseAnimation.value,
          ),
          child: Container(),
        );
      },
    );
  }
}

class RadarPainter extends CustomPainter {
  final UserModel currentUser;
  final List<UserModel> nearbyUsers;
  final double radarRadius;
  final double sweepAngle;
  final double pulseValue;

  RadarPainter({
    required this.currentUser,
    required this.nearbyUsers,
    required this.radarRadius,
    required this.sweepAngle,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 - 20;

    // Fondo oscuro
    final backgroundPaint = Paint()..color = Colors.black;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // Círculos del radar con gradiente
    for (int i = 1; i <= 4; i++) {
      final radius = maxRadius * i / 4;

      final circlePaint = Paint()
        ..color = Colors.greenAccent.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, circlePaint);

      // Etiquetas de distancia
      final distance = (radarRadius * i / 4).round();
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${distance}m',
          style: const TextStyle(
            color: Colors.white30,
            fontSize: 10,
            fontWeight: FontWeight.w300,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx + radius + 4, center.dy - 5));
    }

    // Líneas de cuadrante
    final linePaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.1)
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

    // Barrido del radar (efecto de escaneo)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.greenAccent.withValues(alpha: 0.0),
          Colors.greenAccent.withValues(alpha: 0.3),
          Colors.greenAccent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Línea de barrido
    final sweepLinePaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final sweepEnd = Offset(
      center.dx + maxRadius * cos(sweepAngle),
      center.dy + maxRadius * sin(sweepAngle),
    );
    canvas.drawLine(center, sweepEnd, sweepLinePaint);

    // Efecto de pulso en el usuario actual
    final pulseRadius = 15 + (pulseValue * 10);
    final pulsePaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3 * (1 - pulseValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Usuario actual (punto azul brillante en el centro)
    final currentUserGradient = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.blue.withValues(alpha: 0.8),
          Colors.blue.withValues(alpha: 0.4),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 12));
    canvas.drawCircle(center, 12, currentUserGradient);

    final currentUserPaint = Paint()..color = Colors.blue;
    canvas.drawCircle(center, 8, currentUserPaint);

    // Borde blanco para el usuario actual
    final currentUserBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 8, currentUserBorderPaint);

    // Usuarios cercanos con efectos
    for (var user in nearbyUsers) {
      final distance = currentUser.distanceTo(user.latitude, user.longitude);

      if (distance <= radarRadius) {
        // Calcular posición relativa
        final latDiff = user.latitude - currentUser.latitude;
        final lonDiff = user.longitude - currentUser.longitude;

        final x =
            center.dx +
            (lonDiff *
                111000 *
                cos(currentUser.latitude * pi / 180) /
                radarRadius *
                maxRadius);
        final y = center.dy - (latDiff * 111000 / radarRadius * maxRadius);

        final userPos = Offset(x, y);

        // Gradiente de resplandor
        final glowPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.greenAccent.withValues(alpha: 0.6),
              Colors.greenAccent.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: userPos, radius: 16));
        canvas.drawCircle(userPos, 16, glowPaint);

        // Círculo pulsante alrededor del usuario
        final userPulseRadius = 10 + (pulseValue * 6);
        final userPulsePaint = Paint()
          ..color = Colors.greenAccent.withValues(alpha: 0.4 * (1 - pulseValue))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(userPos, userPulseRadius, userPulsePaint);

        // Usuario detectado
        final userPaint = Paint()..color = Colors.greenAccent;
        canvas.drawCircle(userPos, 7, userPaint);

        // Borde
        final userBorderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(userPos, 7, userBorderPaint);

        // Nombre del usuario con fondo
        final textPainter = TextPainter(
          text: TextSpan(
            text: user.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        final textOffset = Offset(x - textPainter.width / 2, y + 12);

        // Fondo del texto
        final textBgPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.7);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              textOffset.dx - 4,
              textOffset.dy - 2,
              textPainter.width + 8,
              textPainter.height + 4,
            ),
            const Radius.circular(4),
          ),
          textBgPaint,
        );

        textPainter.paint(canvas, textOffset);

        // Línea de conexión al usuario
        final connectionPaint = Paint()
          ..color = Colors.greenAccent.withValues(alpha: 0.3)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        canvas.drawLine(center, userPos, connectionPaint);
      }
    }

    // Leyenda mejorada
    _drawLegend(canvas, size);
  }

  void _drawLegend(Canvas canvas, Size size) {
    const legendY = 20.0;
    const legendX = 20.0;

    // Fondo de la leyenda
    final legendBgPaint = Paint()..color = Colors.black.withValues(alpha: 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(legendX - 8, legendY - 8, 150, 70),
        const Radius.circular(8),
      ),
      legendBgPaint,
    );

    // Usuario actual
    final currentUserPaint = Paint()..color = Colors.blue;
    canvas.drawCircle(const Offset(legendX, legendY), 6, currentUserPaint);

    final currentUserText = TextPainter(
      text: const TextSpan(
        text: 'Tu ubicación',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    currentUserText.layout();
    currentUserText.paint(canvas, const Offset(legendX + 15, legendY - 6));

    // Usuarios cercanos
    final nearbyUserPaint = Paint()..color = Colors.greenAccent;
    canvas.drawCircle(const Offset(legendX, legendY + 25), 6, nearbyUserPaint);

    final nearbyUserText = TextPainter(
      text: const TextSpan(
        text: 'Dispositivos',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    nearbyUserText.layout();
    nearbyUserText.paint(canvas, const Offset(legendX + 15, legendY + 19));

    // Contador de dispositivos
    final countText = TextPainter(
      text: TextSpan(
        text: 'Total: ${nearbyUsers.length}',
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    countText.layout();
    countText.paint(canvas, const Offset(legendX + 15, legendY + 44));
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) => true;
}
