import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/police_dashboard_controller.dart';

/// Dashboard del Policía
/// Muestra el estado de disponibilidad y la asignación actual
class PoliceDashboardScreen extends StatelessWidget {
  const PoliceDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final PoliceDashboardController controller =
        Get.put(PoliceDashboardController());

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Patrulla en Servicio'),
        backgroundColor: const Color(0xFF1976D2), // Azul
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Navegar a perfil
              // Get.to(() => ProfileScreen());
            },
          ),
        ],
      ),
      body: Obx(() {
        bool hasAssignment = controller.currentAssignment.value != null;

        return hasAssignment
            ? _buildMissionView(controller)
            : _buildIdleView(controller);
      }),
    );
  }

  /// Vista cuando NO hay asignación (Disponible/Libre)
  Widget _buildIdleView(PoliceDashboardController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono de estado
            Obx(() {
              bool isAvailable = controller.isAvailable.value;
              return Icon(
                Icons.local_police,
                size: 120,
                color: isAvailable ? Colors.green : Colors.grey,
              );
            }),

            const SizedBox(height: 24),

            // Título
            Obx(() {
              bool isAvailable = controller.isAvailable.value;
              return Text(
                isAvailable ? 'Unidad Disponible' : 'Unidad No Disponible',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isAvailable ? Colors.green : Colors.grey,
                ),
              );
            }),

            const SizedBox(height: 16),

            // Descripción
            Obx(() {
              bool isAvailable = controller.isAvailable.value;
              return Text(
                isAvailable
                    ? 'Esperando asignación del centro de comando...'
                    : 'Activa el switch para recibir asignaciones',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              );
            }),

            const SizedBox(height: 60),

            // Switch de disponibilidad
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Estado de Disponibilidad',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(() => Switch(
                        value: controller.isAvailable.value,
                        onChanged: (value) => controller.toggleAvailability(value),
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.grey,
                      )),
                  const SizedBox(height: 8),
                  Obx(() {
                    bool isAvailable = controller.isAvailable.value;
                    return Text(
                      isAvailable ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? Colors.green : Colors.grey,
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Información adicional
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Al activar el switch, tu ubicación se compartirá con el centro de comando.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Vista cuando HAY asignación (Misión Activa)
  Widget _buildMissionView(PoliceDashboardController controller) {
    Map<String, dynamic> mission = controller.currentAssignment.value!;

    String victimName = mission['victim_name'] ?? 'Usuario';
    String victimPhone = mission['victim_phone'] ?? '';
    double lat = mission['latitude'] ?? 0.0;
    double long = mission['longitude'] ?? 0.0;
    String status = mission['status'] ?? 'ASSIGNED';

    // Calcular distancia
    double? distance = controller.calculateDistanceToVictim();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de emergencia
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.red,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Text(
                  '¡EMERGENCIA ASIGNADA!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Mapa estático
          _buildStaticMap(lat, long),

          // Información de la víctima
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.red, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        victimName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Teléfono
                if (victimPhone.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.green, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          victimPhone,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _callNumber(victimPhone),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Llamar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Ubicación
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lat: ${lat.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Long: ${long.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openInGoogleMaps(lat, long),
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Navegar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Distancia
                if (distance != null)
                  Row(
                    children: [
                      const Icon(Icons.straighten, color: Colors.orange, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Distancia: ${distance.toStringAsFixed(2)} km',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Botones de estado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Botón "EN CAMINO"
                if (status == 'ASSIGNED')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          controller.updateMissionStatus('EN_ROUTE'),
                      icon: const Icon(Icons.directions_car, size: 24),
                      label: const Text(
                        'EN CAMINO',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Botón "LLEGUÉ"
                if (status == 'EN_ROUTE')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          controller.updateMissionStatus('ARRIVED'),
                      icon: const Icon(Icons.location_on, size: 24),
                      label: const Text(
                        'LLEGUÉ AL LUGAR',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Botón "MISIÓN COMPLETADA"
                if (status == 'ARRIVED' || status == 'EN_ROUTE')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Confirmación
                        bool? confirm = await Get.dialog<bool>(
                          AlertDialog(
                            title: const Text('¿Completar Misión?'),
                            content: const Text(
                              '¿Confirmas que la emergencia ha sido resuelta?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () => Get.back(result: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text('Sí, Completar'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await controller.completeMission();
                        }
                      },
                      icon: const Icon(Icons.check_circle, size: 24),
                      label: const Text(
                        'MISIÓN COMPLETADA',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mapa estático de Google Maps
  Widget _buildStaticMap(double lat, double long) {
    // IMPORTANTE: Reemplaza con tu API Key de Google Maps
    String apiKey = "TU_API_KEY_AQUI";
    String staticMapUrl =
        "https://maps.googleapis.com/maps/api/staticmap?center=$lat,$long&zoom=15&size=600x300&maptype=roadmap&markers=color:red%7C$lat,$long&key=$apiKey";

    return Container(
      height: 250,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          staticMapUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade300,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 60, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Mapa no disponible',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
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
}
