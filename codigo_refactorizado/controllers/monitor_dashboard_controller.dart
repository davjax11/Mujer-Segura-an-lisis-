import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';

/// Controlador del Dashboard del Monitorista (C5)
/// Responsabilidades:
/// - Escuchar alertas pendientes en tiempo real
/// - Escuchar policías disponibles en tiempo real
/// - Asignar alertas a policías
/// - Generar reportes y estadísticas
class MonitorDashboardController extends GetxController {
  static MonitorDashboardController get instance => Get.find();

  // Referencias a Firebase
  final _db = FirebaseDatabase.instance.ref();

  // Listas observables
  final emergencyQueue = <Map<String, dynamic>>[].obs;
  final availableUnits = <Map<String, dynamic>>[].obs;

  // Alerta seleccionada para asignar
  final selectedAlert = Rx<Map<String, dynamic>?>(null);

  // Estadísticas del día
  final todayAlertsCount = 0.obs;
  final todayResolvedCount = 0.obs;
  final averageResponseTime = 0.0.obs;

  /// Escuchar cola de emergencias en tiempo real
  void listenEmergencyQueue() {
    _db.child('emergency_queue').onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> data = event.snapshot.value as Map;
        
        emergencyQueue.clear();
        data.forEach((key, value) {
          Map<String, dynamic> alert = Map<String, dynamic>.from(value);
          alert['id'] = key; // Agregar el UID como ID
          emergencyQueue.add(alert);
        });

        // Ordenar por timestamp (más reciente primero)
        emergencyQueue.sort((a, b) {
          DateTime timeA = DateTime.parse(a['timestamp']);
          DateTime timeB = DateTime.parse(b['timestamp']);
          return timeB.compareTo(timeA);
        });

        print("📋 Alertas en cola: ${emergencyQueue.length}");
      } else {
        emergencyQueue.clear();
        print("✅ No hay alertas pendientes");
      }
    });
  }

  /// Escuchar unidades disponibles en tiempo real
  void listenAvailableUnits() {
    _db.child('available_units').onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> data = event.snapshot.value as Map;
        
        availableUnits.clear();
        data.forEach((key, value) {
          Map<String, dynamic> unit = Map<String, dynamic>.from(value);
          unit['id'] = key; // Agregar el UID como ID
          
          // Solo agregar si está disponible (no ocupado)
          if (unit['status'] == 'available') {
            availableUnits.add(unit);
          }
        });

        print("👮 Unidades disponibles: ${availableUnits.length}");
      } else {
        availableUnits.clear();
        print("⚠️ No hay unidades disponibles");
      }
    });
  }

  /// Asignar alerta a un policía
  /// @param alertData: Datos de la alerta desde emergency_queue
  /// @param policeId: UID del policía al que se asigna
  Future<void> assignAlertToPolice(
    Map<String, dynamic> alertData,
    String policeId,
    String policeName,
  ) async {
    try {
      String victimId = alertData['victim_id'];

      // 1. Crear la asignación en la carpeta personal del policía
      Map<String, dynamic> assignment = {
        ...alertData,
        "assigned_at": DateTime.now().toIso8601String(),
        "assigned_by": "monitor", // Puede ser el UID del monitorista
        "status": "ASSIGNED",
      };

      await _db.child('assignments/$policeId').set(assignment);
      print("✅ Asignación creada para policía: $policeId");

      // 2. Actualizar el estado del policía a "busy"
      await _db.child('available_units/$policeId/status').set('busy');
      print("✅ Policía marcado como ocupado");

      // 3. Registrar en el historial
      String logId = "${victimId}_${DateTime.now().millisecondsSinceEpoch}";
      await _db.child('history_logs/$logId').set({
        ...alertData,
        "assigned_to": policeId,
        "assigned_to_name": policeName,
        "action": "DISPATCHED",
        "assigned_at": DateTime.now().toIso8601String(),
      });
      print("✅ Registro creado en historial");

      // 4. Eliminar de la cola de emergencias (ya fue atendida)
      await _db.child('emergency_queue/$victimId').remove();
      print("✅ Alerta eliminada de la cola");

      // 5. Limpiar selección
      selectedAlert.value = null;

      Get.snackbar(
        "✅ Asignación Exitosa",
        "Alerta asignada a $policeName",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.primaryColor,
        colorText: Get.theme.colorScheme.onPrimary,
      );

    } catch (e) {
      print("❌ Error al asignar alerta: $e");
      Get.snackbar(
        "Error",
        "No se pudo asignar la alerta al policía",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Seleccionar una alerta para asignar
  void selectAlert(Map<String, dynamic> alert) {
    selectedAlert.value = alert;
    print("📌 Alerta seleccionada: ${alert['victim_name']}");
  }

  /// Deseleccionar alerta
  void deselectAlert() {
    selectedAlert.value = null;
  }

  /// Generar estadísticas del día actual
  Future<void> generateTodayStatistics() async {
    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      String startTimestamp = startOfDay.toIso8601String();

      // Consultar historial del día
      final snapshot = await _db
          .child('history_logs')
          .orderByChild('timestamp')
          .startAt(startTimestamp)
          .get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> logs = snapshot.value as Map;
        
        int totalAlerts = 0;
        int resolvedAlerts = 0;
        List<int> responseTimes = [];

        logs.forEach((key, value) {
          Map log = value as Map;
          totalAlerts++;

          // Contar alertas resueltas
          if (log['action'] == 'RESOLVED') {
            resolvedAlerts++;

            // Calcular tiempo de respuesta
            if (log['assigned_at'] != null && log['resolved_at'] != null) {
              DateTime assignedTime = DateTime.parse(log['assigned_at']);
              DateTime resolvedTime = DateTime.parse(log['resolved_at']);
              int responseMinutes = resolvedTime.difference(assignedTime).inMinutes;
              responseTimes.add(responseMinutes);
            }
          }
        });

        // Actualizar estadísticas
        todayAlertsCount.value = totalAlerts;
        todayResolvedCount.value = resolvedAlerts;

        if (responseTimes.isNotEmpty) {
          averageResponseTime.value = responseTimes.reduce((a, b) => a + b) / responseTimes.length;
        } else {
          averageResponseTime.value = 0.0;
        }

        print("📊 Estadísticas del día:");
        print("   Total de alertas: $totalAlerts");
        print("   Alertas resueltas: $resolvedAlerts");
        print("   Tiempo promedio de respuesta: ${averageResponseTime.value.toStringAsFixed(1)} min");

      } else {
        // No hay registros hoy
        todayAlertsCount.value = 0;
        todayResolvedCount.value = 0;
        averageResponseTime.value = 0.0;
      }

    } catch (e) {
      print("❌ Error al generar estadísticas: $e");
    }
  }

  /// Obtener historial de alertas (últimas N)
  Future<List<Map<String, dynamic>>> getRecentHistory({int limit = 50}) async {
    try {
      final snapshot = await _db
          .child('history_logs')
          .orderByChild('timestamp')
          .limitToLast(limit)
          .get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> logs = snapshot.value as Map;
        List<Map<String, dynamic>> history = [];

        logs.forEach((key, value) {
          Map<String, dynamic> log = Map<String, dynamic>.from(value);
          log['id'] = key;
          history.add(log);
        });

        // Ordenar por timestamp (más reciente primero)
        history.sort((a, b) {
          DateTime timeA = DateTime.parse(a['timestamp']);
          DateTime timeB = DateTime.parse(b['timestamp']);
          return timeB.compareTo(timeA);
        });

        return history;
      }

      return [];

    } catch (e) {
      print("❌ Error al obtener historial: $e");
      return [];
    }
  }

  /// Cancelar una alerta desde el dashboard (por error o duplicado)
  Future<void> cancelAlert(String victimId, String reason) async {
    try {
      // 1. Registrar en el historial como cancelada
      String logId = "${victimId}_${DateTime.now().millisecondsSinceEpoch}";
      await _db.child('history_logs/$logId').set({
        "victim_id": victimId,
        "action": "CANCELLED",
        "cancelled_by": "monitor",
        "reason": reason,
        "timestamp": DateTime.now().toIso8601String(),
      });

      // 2. Eliminar de la cola
      await _db.child('emergency_queue/$victimId').remove();

      Get.snackbar(
        "Alerta Cancelada",
        "La alerta ha sido retirada de la cola",
        snackPosition: SnackPosition.BOTTOM,
      );

      print("✅ Alerta cancelada por el monitorista");

    } catch (e) {
      print("❌ Error al cancelar alerta: $e");
    }
  }

  @override
  void onInit() {
    super.onInit();
    // Iniciar escucha en tiempo real
    listenEmergencyQueue();
    listenAvailableUnits();
    generateTodayStatistics();
  }

  @override
  void onClose() {
    // Limpiar recursos si es necesario
    super.onClose();
  }
}
