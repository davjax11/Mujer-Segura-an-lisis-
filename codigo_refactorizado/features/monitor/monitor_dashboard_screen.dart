import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/monitor_dashboard_controller.dart';

/// Dashboard del Monitorista (C5)
/// Muestra alertas pendientes y unidades disponibles
/// Permite asignar alertas a policías
class MonitorDashboardScreen extends StatelessWidget {
  const MonitorDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final MonitorDashboardController controller =
        Get.put(MonitorDashboardController());

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Centro de Comando C5'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => _showStatisticsDialog(context, controller),
            tooltip: 'Ver Reportes',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.generateTodayStatistics(),
            tooltip: 'Actualizar Estadísticas',
          ),
        ],
      ),
      body: Row(
        children: [
          // COLUMNA IZQUIERDA: Alertas Pendientes
          Expanded(
            flex: 2,
            child: _buildEmergencyQueuePanel(controller),
          ),

          // Divisor vertical
          const VerticalDivider(width: 1, thickness: 1),

          // COLUMNA DERECHA: Unidades Disponibles
          Expanded(
            flex: 1,
            child: _buildAvailableUnitsPanel(controller),
          ),
        ],
      ),
    );
  }

  /// Panel de Alertas Pendientes
  Widget _buildEmergencyQueuePanel(MonitorDashboardController controller) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Alertas Pendientes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Obx(() => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${controller.emergencyQueue.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )),
              ],
            ),
          ),

          // Lista de alertas
          Expanded(
            child: Obx(() {
              if (controller.emergencyQueue.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 80, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'Sin emergencias activas',
                        style: TextStyle(fontSize: 18, color: Colors.black54),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.emergencyQueue.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> alert = controller.emergencyQueue[index];
                  bool isSelected =
                      controller.selectedAlert.value?['id'] == alert['id'];

                  return _buildAlertCard(alert, isSelected, controller);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de Alerta
  Widget _buildAlertCard(
    Map<String, dynamic> alert,
    bool isSelected,
    MonitorDashboardController controller,
  ) {
    String victimName = alert['victim_name'] ?? 'Usuario';
    String victimPhone = alert['victim_phone'] ?? '';
    double lat = alert['latitude'] ?? 0.0;
    double long = alert['longitude'] ?? 0.0;
    String timestamp = alert['timestamp'] ?? '';

    // Calcular tiempo transcurrido
    DateTime alertTime = DateTime.parse(timestamp);
    Duration elapsed = DateTime.now().difference(alertTime);
    String elapsedText = elapsed.inMinutes < 1
        ? 'Hace ${elapsed.inSeconds}s'
        : 'Hace ${elapsed.inMinutes}m';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Colors.red.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.red : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => controller.selectAlert(alert),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre y tiempo
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      victimName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      elapsedText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Teléfono
              if (victimPhone.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text(victimPhone,
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),

              const SizedBox(height: 8),

              // Coordenadas
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lat: ${lat.toStringAsFixed(6)}, Long: ${long.toStringAsFixed(6)}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openInGoogleMaps(lat, long),
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Ver Mapa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _callNumber(victimPhone),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Llamar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Panel de Unidades Disponibles
  Widget _buildAvailableUnitsPanel(MonitorDashboardController controller) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.local_police, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Unidades Disponibles',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Obx(() => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${controller.availableUnits.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )),
              ],
            ),
          ),

          // Lista de unidades
          Expanded(
            child: Obx(() {
              if (controller.availableUnits.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning, size: 80, color: Colors.orange),
                      SizedBox(height: 16),
                      Text(
                        'No hay unidades disponibles',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.availableUnits.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> unit =
                      controller.availableUnits[index];
                  return _buildUnitCard(unit, controller);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de Unidad Policial
  Widget _buildUnitCard(
    Map<String, dynamic> unit,
    MonitorDashboardController controller,
  ) {
    String unitName = unit['name'] ?? 'Oficial';
    String unitId = unit['id'] ?? '';
    String status = unit['status'] ?? 'available';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre y estado
            Row(
              children: [
                Icon(
                  Icons.local_police,
                  color: status == 'available' ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unitName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'available'
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status == 'available' ? 'Disponible' : 'Ocupado',
                    style: TextStyle(
                      fontSize: 12,
                      color: status == 'available' ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Botón de asignar
            Obx(() {
              bool hasSelection = controller.selectedAlert.value != null;
              bool isAvailable = status == 'available';

              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: hasSelection && isAvailable
                      ? () {
                          controller.assignAlertToPolice(
                            controller.selectedAlert.value!,
                            unitId,
                            unitName,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.assignment, size: 18),
                  label: Text(
                    hasSelection
                        ? 'ASIGNAR ALERTA'
                        : 'Selecciona una alerta',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Abrir ubicación en Google Maps
  Future<void> _openInGoogleMaps(double lat, double long) async {
    final String url =
        'https://www.google.com/maps/search/?api=1&query=$lat,$long';
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar('Error', 'No se pudo abrir Google Maps');
    }
  }

  /// Llamar a un número de teléfono
  Future<void> _callNumber(String phone) async {
    if (phone.isEmpty) {
      Get.snackbar('Error', 'No hay número de teléfono disponible');
      return;
    }

    final Uri uri = Uri.parse('tel:$phone');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Get.snackbar('Error', 'No se pudo realizar la llamada');
    }
  }

  /// Mostrar diálogo de estadísticas
  void _showStatisticsDialog(
    BuildContext context,
    MonitorDashboardController controller,
  ) {
    controller.generateTodayStatistics();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estadísticas del Día'),
        content: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow(
                  'Total de alertas:',
                  '${controller.todayAlertsCount.value}',
                  Icons.warning,
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  'Alertas resueltas:',
                  '${controller.todayResolvedCount.value}',
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  'Tiempo promedio:',
                  '${controller.averageResponseTime.value.toStringAsFixed(1)} min',
                  Icons.timer,
                  Colors.blue,
                ),
              ],
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Fila de estadística
  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
