import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/alert_controller.dart';

/// Pantalla Principal del Usuario (Víctima)
/// Muestra el botón SOS y el estado de la alerta
class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AlertController controller = Get.put(AlertController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mujer Segura'),
        centerTitle: true,
        backgroundColor: const Color(0xFF6A1B9A), // Morado
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
      body: SafeArea(
        child: Obx(() {
          bool isAlertActive = controller.isAlertActive.value;

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo o imagen
                  Image.asset(
                    'assets/logos/emergencyAppLogo.png',
                    height: 120,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.shield,
                        size: 120,
                        color: Color(0xFF6A1B9A),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Título
                  Text(
                    isAlertActive ? '⚠️ ALERTA ACTIVA' : 'Estás Segura',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isAlertActive ? Colors.red : Colors.green,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Descripción
                  Text(
                    isAlertActive
                        ? 'Tu ubicación ha sido enviada al centro de monitoreo.\nAyuda en camino.'
                        : 'Presiona el botón de emergencia si necesitas ayuda.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Botón SOS o Cancelar
                  if (!isAlertActive)
                    _buildSOSButton(controller)
                  else
                    _buildCancelButton(controller),

                  const SizedBox(height: 40),

                  // Información adicional
                  if (isAlertActive)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ubicación compartida',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (controller.currentPosition.value != null)
                            Text(
                              'Lat: ${controller.currentPosition.value!.latitude.toStringAsFixed(6)}\n'
                              'Long: ${controller.currentPosition.value!.longitude.toStringAsFixed(6)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // Botones secundarios
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSecondaryButton(
                        icon: Icons.contacts,
                        label: 'Contactos',
                        onPressed: () {
                          // Navegar a contactos de emergencia
                          // Get.to(() => EmergencyContactsScreen());
                        },
                      ),
                      _buildSecondaryButton(
                        icon: Icons.history,
                        label: 'Historial',
                        onPressed: () {
                          // Navegar a historial
                          // Get.to(() => AlertHistoryScreen());
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Botón SOS (Rojo)
  Widget _buildSOSButton(AlertController controller) {
    return GestureDetector(
      onTap: () async {
        // Confirmación antes de enviar
        bool? confirm = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('¿Enviar Alerta de Emergencia?'),
            content: const Text(
              'Se enviará tu ubicación actual al centro de monitoreo.\n\n'
              '¿Estás segura de que necesitas ayuda?',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Sí, Enviar Alerta'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await controller.sendEmergencyAlert();
        }
      },
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red,
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning,
                size: 60,
                color: Colors.white,
              ),
              SizedBox(height: 8),
              Text(
                'SOS',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'EMERGENCIA',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón Cancelar (Verde)
  Widget _buildCancelButton(AlertController controller) {
    return ElevatedButton.icon(
      onPressed: () async {
        // Confirmación antes de cancelar
        bool? confirm = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('¿Cancelar Alerta?'),
            content: const Text(
              '¿Estás segura de que quieres cancelar la alerta de emergencia?',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Sí, Cancelar'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await controller.cancelAlert();
        }
      },
      icon: const Icon(Icons.check_circle, size: 28),
      label: const Text(
        'CANCELAR ALERTA',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  /// Botón secundario
  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
