import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

/// Controlador del Dashboard del Policía
/// Responsabilidades:
/// - Escuchar asignaciones en tiempo real
/// - Actualizar disponibilidad (switch ON/OFF)
/// - Actualizar ubicación en tiempo real
/// - Completar misiones
class PoliceDashboardController extends GetxController {
  static PoliceDashboardController get instance => Get.find();

  // Referencias a Firebase
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  // Estado observable
  final isAvailable = false.obs;
  final currentAssignment = Rx<Map<String, dynamic>?>(null);
  final myPosition = Rx<Position?>(null);

  // Timer para actualizar ubicación
  Timer? _locationUpdateTimer;

  String get myUid => _auth.currentUser?.uid ?? "";

  /// Escuchar asignaciones en tiempo real
  /// Solo escucha la carpeta personal del policía
  void listenMyAssignment() {
    if (myUid.isEmpty) {
      print("❌ No hay usuario autenticado");
      return;
    }

    _db.child('assignments/$myUid').onValue.listen((event) {
      if (event.snapshot.value != null) {
        // Hay una asignación activa
        Map<dynamic, dynamic> data = event.snapshot.value as Map;
        currentAssignment.value = Map<String, dynamic>.from(data);
        
        print("🚨 Nueva asignación recibida:");
        print("   Víctima: ${currentAssignment.value!['victim_name']}");
        print("   Ubicación: ${currentAssignment.value!['latitude']}, ${currentAssignment.value!['longitude']}");

        // Reproducir sonido de alerta (opcional)
        // AudioPlayer().play('assets/sounds/alert.mp3');

      } else {
        // No hay asignación activa
        currentAssignment.value = null;
        print("✅ Sin asignaciones activas");
      }
    });
  }

  /// Activar/Desactivar disponibilidad (Switch ON/OFF)
  Future<void> toggleAvailability(bool value) async {
    if (myUid.isEmpty) return;

    try {
      isAvailable.value = value;

      if (value) {
        // Activar: Agregar a available_units
        await _activateUnit();
      } else {
        // Desactivar: Eliminar de available_units
        await _deactivateUnit();
      }

    } catch (e) {
      print("❌ Error al cambiar disponibilidad: $e");
      // Revertir el cambio
      isAvailable.value = !value;
    }
  }

  /// Activar unidad (agregar a available_units)
  Future<void> _activateUnit() async {
    try {
      // Obtener ubicación actual
      Position? position = await _getCurrentPosition();
      
      if (position == null) {
        Get.snackbar(
          "Error",
          "No se pudo obtener tu ubicación. Activa el GPS.",
          snackPosition: SnackPosition.BOTTOM,
        );
        isAvailable.value = false;
        return;
      }

      // Obtener datos del usuario
      final snapshot = await _db.child('users/$myUid').get();
      String userName = "Oficial";

      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        userName = data['fullName'] ?? data['UserName'] ?? "Oficial";
      }

      // Agregar a available_units
      await _db.child('available_units/$myUid').set({
        "name": userName,
        "latitude": position.latitude,
        "longitude": position.longitude,
        "status": "available",
        "last_update": DateTime.now().toIso8601String(),
      });

      // Iniciar actualización automática de ubicación
      _startLocationUpdates();

      Get.snackbar(
        "✅ Disponible",
        "Ahora estás disponible para recibir asignaciones",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.primaryColor,
        colorText: Get.theme.colorScheme.onPrimary,
      );

      print("✅ Unidad activada");

    } catch (e) {
      print("❌ Error al activar unidad: $e");
      isAvailable.value = false;
    }
  }

  /// Desactivar unidad (eliminar de available_units)
  Future<void> _deactivateUnit() async {
    try {
      // Eliminar de available_units
      await _db.child('available_units/$myUid').remove();

      // Detener actualización de ubicación
      _stopLocationUpdates();

      Get.snackbar(
        "No Disponible",
        "Ya no recibirás nuevas asignaciones",
        snackPosition: SnackPosition.BOTTOM,
      );

      print("✅ Unidad desactivada");

    } catch (e) {
      print("❌ Error al desactivar unidad: $e");
    }
  }

  /// Iniciar actualización automática de ubicación (cada 30 segundos)
  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (isAvailable.value) {
        await _updateMyLocation();
      } else {
        timer.cancel();
      }
    });

    print("📍 Actualización automática de ubicación iniciada");
  }

  /// Detener actualización automática de ubicación
  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    print("📍 Actualización automática de ubicación detenida");
  }

  /// Actualizar mi ubicación en Firebase
  Future<void> _updateMyLocation() async {
    try {
      Position? position = await _getCurrentPosition();
      
      if (position != null) {
        await _db.child('available_units/$myUid').update({
          "latitude": position.latitude,
          "longitude": position.longitude,
          "last_update": DateTime.now().toIso8601String(),
        });

        myPosition.value = position;
        print("📍 Ubicación actualizada: ${position.latitude}, ${position.longitude}");
      }

    } catch (e) {
      print("❌ Error al actualizar ubicación: $e");
    }
  }

  /// Obtener ubicación actual
  Future<Position?> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;

    } catch (e) {
      print("❌ Error al obtener ubicación: $e");
      return null;
    }
  }

  /// Actualizar estado de la misión
  /// Estados: ASSIGNED → EN_ROUTE → ARRIVED → RESOLVED
  Future<void> updateMissionStatus(String status) async {
    if (currentAssignment.value == null) return;

    try {
      await _db.child('assignments/$myUid/status').set(status);
      
      // Actualizar localmente
      currentAssignment.value!['status'] = status;
      currentAssignment.refresh();

      String message = "";
      switch (status) {
        case "EN_ROUTE":
          message = "En camino al lugar de la emergencia";
          break;
        case "ARRIVED":
          message = "Has llegado al lugar";
          break;
        case "RESOLVED":
          message = "Misión completada";
          break;
      }

      Get.snackbar(
        "Estado Actualizado",
        message,
        snackPosition: SnackPosition.BOTTOM,
      );

      print("✅ Estado de misión actualizado: $status");

    } catch (e) {
      print("❌ Error al actualizar estado: $e");
    }
  }

  /// Completar misión
  /// Mueve la asignación al historial y libera al policía
  Future<void> completeMission() async {
    if (currentAssignment.value == null) return;

    try {
      Map<String, dynamic> assignment = currentAssignment.value!;

      // 1. Registrar en el historial como resuelta
      String logId = "${assignment['victim_id']}_${DateTime.now().millisecondsSinceEpoch}";
      await _db.child('history_logs/$logId').set({
        ...assignment,
        "action": "RESOLVED",
        "resolved_at": DateTime.now().toIso8601String(),
        "resolved_by": myUid,
      });

      print("✅ Misión registrada en historial");

      // 2. Eliminar la asignación (me libera para la siguiente)
      await _db.child('assignments/$myUid').remove();
      print("✅ Asignación eliminada");

      // 3. Actualizar mi estado a disponible
      if (isAvailable.value) {
        await _db.child('available_units/$myUid/status').set('available');
        print("✅ Estado actualizado a disponible");
      }

      // 4. Limpiar estado local
      currentAssignment.value = null;

      Get.snackbar(
        "✅ Misión Completada",
        "La emergencia ha sido resuelta exitosamente",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.primaryColor,
        colorText: Get.theme.colorScheme.onPrimary,
        duration: const Duration(seconds: 5),
      );

    } catch (e) {
      print("❌ Error al completar misión: $e");
      Get.snackbar(
        "Error",
        "No se pudo completar la misión",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Calcular distancia entre mi ubicación y la víctima
  double? calculateDistanceToVictim() {
    if (currentAssignment.value == null || myPosition.value == null) {
      return null;
    }

    double victimLat = currentAssignment.value!['latitude'];
    double victimLong = currentAssignment.value!['longitude'];

    double distance = Geolocator.distanceBetween(
      myPosition.value!.latitude,
      myPosition.value!.longitude,
      victimLat,
      victimLong,
    );

    // Convertir de metros a kilómetros
    return distance / 1000;
  }

  /// Verificar estado al iniciar (por si se cerró la app con una asignación activa)
  Future<void> checkInitialState() async {
    if (myUid.isEmpty) return;

    try {
      // Verificar si hay una asignación activa
      final assignmentSnapshot = await _db.child('assignments/$myUid').get();
      if (assignmentSnapshot.exists) {
        Map<dynamic, dynamic> data = assignmentSnapshot.value as Map;
        currentAssignment.value = Map<String, dynamic>.from(data);
        print("📋 Asignación activa detectada al iniciar");
      }

      // Verificar si estaba disponible
      final unitSnapshot = await _db.child('available_units/$myUid').get();
      if (unitSnapshot.exists) {
        isAvailable.value = true;
        _startLocationUpdates();
        print("✅ Unidad estaba disponible, reactivando...");
      }

    } catch (e) {
      print("❌ Error al verificar estado inicial: $e");
    }
  }

  @override
  void onInit() {
    super.onInit();
    checkInitialState();
    listenMyAssignment();
  }

  @override
  void onClose() {
    _stopLocationUpdates();
    super.onClose();
  }
}
