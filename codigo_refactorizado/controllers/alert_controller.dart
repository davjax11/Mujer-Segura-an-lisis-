import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

/// Controlador de Alertas SOS
/// Responsabilidades:
/// - Enviar alertas de emergencia con ubicación GPS
/// - Cancelar alertas activas
/// - Manejar permisos de ubicación
class AlertController extends GetxController {
  static AlertController get instance => Get.find();

  // Referencias a Firebase
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  // Estado observable de la alerta
  final isAlertActive = false.obs;
  final currentPosition = Rx<Position?>(null);

  /// Función principal: Enviar Alerta SOS
  /// Se llama cuando el usuario presiona el botón rojo de emergencia
  Future<void> sendEmergencyAlert() async {
    User? currentUser = _auth.currentUser;
    
    if (currentUser == null) {
      Get.snackbar(
        "Error",
        "Debes iniciar sesión para enviar una alerta",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      // 1. Verificar permisos y obtener ubicación GPS
      bool hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        Get.snackbar(
          "Permiso Requerido",
          "Necesitamos acceso a tu ubicación para enviar la alerta",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      currentPosition.value = position;

      // 2. Obtener datos del usuario desde Firebase
      final snapshot = await _db.child('users/${currentUser.uid}').get();
      
      String userName = "Usuario";
      String userPhone = "";

      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        userName = data['fullName'] ?? data['UserName'] ?? "Usuario";
        userPhone = data['phone'] ?? data['Phone'] ?? "";
      }

      // 3. Crear el objeto de alerta (DTO - Data Transfer Object)
      Map<String, dynamic> alertData = {
        "victim_id": currentUser.uid,
        "victim_name": userName,
        "victim_phone": userPhone,
        "latitude": position.latitude,
        "longitude": position.longitude,
        "status": "PENDING", // Estados: PENDING, ASSIGNED, RESOLVED, CANCELLED
        "timestamp": DateTime.now().toIso8601String(),
        "type": "SOS",
      };

      // 4. Escribir en la cola de emergencias (para el Monitorista)
      await _db.child('emergency_queue/${currentUser.uid}').set(alertData);

      // 5. Actualizar estado local
      isAlertActive.value = true;

      Get.snackbar(
        "✅ Alerta Enviada",
        "El centro de monitoreo ha recibido tu ubicación",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.primaryColor,
        colorText: Get.theme.colorScheme.onPrimary,
        duration: const Duration(seconds: 5),
      );

      print("✅ Alerta SOS enviada exitosamente");
      print("📍 Ubicación: ${position.latitude}, ${position.longitude}");

    } catch (e) {
      print("❌ Error al enviar alerta: $e");
      Get.snackbar(
        "Error",
        "No se pudo enviar la alerta. Verifica tu conexión GPS e internet.",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Cancelar alerta activa
  /// Se llama cuando el usuario presiona el botón verde de cancelación
  Future<void> cancelAlert() async {
    User? currentUser = _auth.currentUser;
    
    if (currentUser == null) return;

    try {
      // 1. Eliminar de la cola de emergencias
      await _db.child('emergency_queue/${currentUser.uid}').remove();

      // 2. Registrar en el historial como cancelada
      String logId = "${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}";
      await _db.child('history_logs/$logId').set({
        "victim_id": currentUser.uid,
        "action": "CANCELLED",
        "timestamp": DateTime.now().toIso8601String(),
        "cancelled_by": "victim",
      });

      // 3. Actualizar estado local
      isAlertActive.value = false;
      currentPosition.value = null;

      Get.snackbar(
        "Cancelado",
        "Tu alerta ha sido retirada",
        snackPosition: SnackPosition.BOTTOM,
      );

      print("✅ Alerta cancelada por el usuario");

    } catch (e) {
      print("❌ Error al cancelar alerta: $e");
      Get.snackbar(
        "Error",
        "No se pudo cancelar la alerta",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Verificar estado de la alerta al iniciar la app
  /// Útil para saber si hay una alerta activa después de cerrar la app
  Future<void> checkAlertStatus() async {
    User? currentUser = _auth.currentUser;
    
    if (currentUser == null) return;

    try {
      final snapshot = await _db.child('emergency_queue/${currentUser.uid}').get();
      
      if (snapshot.exists) {
        isAlertActive.value = true;
        Map data = snapshot.value as Map;
        
        // Reconstruir la posición si existe
        if (data['latitude'] != null && data['longitude'] != null) {
          // Nota: No podemos reconstruir un objeto Position completo,
          // pero podemos guardar las coordenadas para mostrarlas
          print("📍 Alerta activa detectada: ${data['latitude']}, ${data['longitude']}");
        }
      } else {
        isAlertActive.value = false;
      }
    } catch (e) {
      print("❌ Error al verificar estado de alerta: $e");
    }
  }

  /// Manejar permisos de ubicación
  /// Retorna true si se tienen los permisos necesarios
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar(
        "GPS Deshabilitado",
        "Por favor activa el GPS de tu dispositivo",
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    // Verificar permisos
    permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied) {
        Get.snackbar(
          "Permiso Denegado",
          "Necesitamos acceso a tu ubicación para enviar alertas de emergencia",
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Get.snackbar(
        "Permiso Denegado Permanentemente",
        "Por favor habilita los permisos de ubicación en la configuración de tu dispositivo",
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
      return false;
    }

    return true;
  }

  /// Obtener ubicación actual (sin enviar alerta)
  /// Útil para mostrar la ubicación actual en el mapa
  Future<Position?> getCurrentPosition() async {
    try {
      bool hasPermission = await _handleLocationPermission();
      if (!hasPermission) return null;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentPosition.value = position;
      return position;

    } catch (e) {
      print("❌ Error al obtener ubicación: $e");
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Verificar si hay una alerta activa al iniciar
    checkAlertStatus();
  }
}
