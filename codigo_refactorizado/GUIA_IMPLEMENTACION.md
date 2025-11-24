# Guía de Implementación - Mujer Segura Refactorizado

## 📋 Índice
1. [Cambios Principales](#cambios-principales)
2. [Estructura de Archivos](#estructura-de-archivos)
3. [Pasos de Implementación](#pasos-de-implementación)
4. [Configuración de Firebase](#configuración-de-firebase)
5. [Pruebas del Sistema](#pruebas-del-sistema)
6. [Solución de Problemas](#solución-de-problemas)

---

## 🎯 Cambios Principales

### Arquitectura Simplificada
- **Antes**: Todo mezclado en `activeResponders/`
- **Ahora**: Separación clara en 5 nodos:
  - `users/` - Registro de usuarios
  - `emergency_queue/` - Cola de alertas pendientes (solo monitorista)
  - `available_units/` - Policías disponibles
  - `assignments/` - Asignaciones activas (carpeta personal del policía)
  - `history_logs/` - Historial de alertas finalizadas

### Controladores Refactorizados
1. **AlertController** (antes `messageController`)
   - Responsabilidad única: Enviar y cancelar alertas SOS
   - Escribe en `emergency_queue/` en lugar de `activeResponders/`
   - Código limpio y bien documentado

2. **MonitorDashboardController** (NUEVO)
   - Escucha alertas pendientes en tiempo real
   - Escucha policías disponibles
   - Asigna alertas a policías
   - Genera reportes y estadísticas

3. **PoliceDashboardController** (antes parte de `responder_dashboard.dart`)
   - Escucha solo su carpeta personal `assignments/{myUID}`
   - Actualiza disponibilidad (switch ON/OFF)
   - Actualiza ubicación cada 30 segundos
   - Completa misiones y registra en historial

### Modelo de Datos Estandarizado
- **AppUser**: Modelo consistente con campos en minúsculas
- **EmergencyAlert**: Modelo para alertas de emergencia
- **PoliceUnit**: Modelo para unidades policiales
- **MissionAssignment**: Modelo para asignaciones de misión

---

## 📁 Estructura de Archivos

```
lib/
├── controllers/
│   ├── alert_controller.dart              # Controlador de alertas (usuario)
│   ├── monitor_dashboard_controller.dart  # Controlador del monitorista
│   └── police_dashboard_controller.dart   # Controlador del policía
├── models/
│   └── app_user.dart                      # Modelos de datos
├── features/
│   ├── user/
│   │   └── user_home_screen.dart          # Pantalla principal del usuario
│   ├── monitor/
│   │   └── monitor_dashboard_screen.dart  # Dashboard del monitorista (Web)
│   └── police/
│       └── police_dashboard_screen.dart   # Dashboard del policía (Móvil)
└── main.dart                              # Punto de entrada (modificar)
```

---

## 🚀 Pasos de Implementación

### Paso 1: Backup del Código Actual
```bash
# Crear una copia de seguridad
cp -r lib lib_backup_$(date +%Y%m%d)
```

### Paso 2: Copiar los Nuevos Archivos

1. **Copiar controladores**:
   ```bash
   # Crear carpeta controllers si no existe
   mkdir -p lib/controllers
   
   # Copiar los 3 controladores nuevos
   cp codigo_refactorizado/controllers/*.dart lib/controllers/
   ```

2. **Copiar modelos**:
   ```bash
   # Crear carpeta models si no existe
   mkdir -p lib/models
   
   # Copiar el modelo actualizado
   cp codigo_refactorizado/models/app_user.dart lib/models/
   ```

3. **Copiar pantallas**:
   ```bash
   # Copiar pantalla del usuario
   mkdir -p lib/features/user
   cp codigo_refactorizado/features/user/user_home_screen.dart lib/features/user/
   
   # Copiar dashboard del monitorista
   mkdir -p lib/features/monitor
   cp codigo_refactorizado/features/monitor/monitor_dashboard_screen.dart lib/features/monitor/
   
   # Copiar dashboard del policía
   mkdir -p lib/features/police
   cp codigo_refactorizado/features/police/police_dashboard_screen.dart lib/features/police/
   ```

### Paso 3: Actualizar main.dart

Modifica tu archivo `lib/main.dart` para usar las nuevas pantallas según el tipo de usuario:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'common_widgets/onboarding.dart';
import 'features/user/user_home_screen.dart';
import 'features/monitor/monitor_dashboard_screen.dart';
import 'features/police/police_dashboard_screen.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyChvFAK-BKfBxxvmNYKBPtCT9DX4WPI44Q",
        authDomain: "mujer-segura-dev-cf3e1.firebaseapp.com",
        projectId: "mujer-segura-dev-cf3e1",
        storageBucket: "mujer-segura-dev-cf3e1.firebasestorage.app",
        messagingSenderId: "522651858052",
        appId: "1:522651858052:web:58f59b532eac33c6ffbed1",
        measurementId: "G-J0M17D8GF8",
        databaseURL: "https://mujer-segura-dev-cf3e1-default-rtdb.firebaseio.com",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mujer Segura',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        primaryColor: const Color(0xFF6A1B9A),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Si no está autenticado, mostrar onboarding
        if (!snapshot.hasData) {
          return const OnBoardingScreen();
        }

        // Si está autenticado, determinar qué pantalla mostrar según el tipo de usuario
        return FutureBuilder<String>(
          future: _getUserType(snapshot.data!.uid),
          builder: (context, userTypeSnapshot) {
            if (!userTypeSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            String userType = userTypeSnapshot.data!;

            // Redirigir según el tipo de usuario
            switch (userType) {
              case 'monitor':
                return const MonitorDashboardScreen();
              case 'police':
                return const PoliceDashboardScreen();
              case 'victim':
              default:
                return const UserHomeScreen();
            }
          },
        );
      },
    );
  }

  Future<String> _getUserType(String uid) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users/$uid/userType')
          .get();

      if (snapshot.exists) {
        return snapshot.value.toString();
      }

      // Si no existe, asumir que es víctima (usuario normal)
      return 'victim';
    } catch (e) {
      print('Error al obtener tipo de usuario: $e');
      return 'victim';
    }
  }
}
```

### Paso 4: Actualizar pubspec.yaml (si es necesario)

Verifica que tengas todas las dependencias necesarias:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^4.2.1
  firebase_database: ^12.1.0
  firebase_auth: ^6.1.2
  
  # Estado y navegación
  get: ^4.6.5
  
  # Ubicación
  geolocator: ^14.0.2
  geocoding: ^4.0.0
  
  # Utilidades
  url_launcher: ^6.1.10
  shared_preferences: ^2.0.20
  
  # UI
  google_fonts: ^6.3.2
  cupertino_icons: ^1.0.2
```

**Dependencias que puedes ELIMINAR** (si no las usas):
- `background_sms` (solo si no envías SMS)
- `flutter_sms` (duplicado)
- `android_intent_plus` (si no se usa)
- `zego_uikit_prebuilt_live_streaming` (si no implementas videollamada)
- `google_maps_flutter` (si usas solo mapas estáticos)
- `sliding_switch` (reemplazado por Switch nativo)

### Paso 5: Eliminar Archivos Obsoletos

```bash
# Eliminar archivos que ya no se usan
rm lib/features/user/controllers/message_sending.dart
rm lib/features/responder/responder_dashboard.dart
rm lib/features/response_screen/emergencies_screen.dart
rm lib/features/list_of_responders/select_responder.dart
rm lib/User.dart  # Reemplazado por models/app_user.dart
```

---

## 🔥 Configuración de Firebase

### Paso 1: Actualizar Reglas de Seguridad

1. Ve a la consola de Firebase: https://console.firebase.google.com
2. Selecciona tu proyecto: `mujer-segura-dev-cf3e1`
3. Ve a **Realtime Database** → **Reglas**
4. Copia y pega las reglas del archivo `firebase_security_rules.json`
5. Clic en **Publicar**

### Paso 2: Migrar Datos Existentes (Opcional)

Si ya tienes usuarios en `Users/` (con mayúscula), debes migrarlos a `users/` (minúscula):

**Opción A: Manualmente desde la consola de Firebase**
1. Ve a **Realtime Database** → **Datos**
2. Exporta el nodo `Users/` (clic derecho → Exportar JSON)
3. Crea un nuevo nodo `users/` (minúscula)
4. Importa los datos en el nuevo nodo
5. Actualiza los campos:
   - `UserName` → `fullName`
   - `Phone` → `phone`
   - `UserType` → `userType`

**Opción B: Script de migración (Cloud Functions)**
```javascript
// Ejecutar desde Firebase Functions o Cloud Shell
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.database();

async function migrateUsers() {
  const oldUsersRef = db.ref('Users');
  const newUsersRef = db.ref('users');
  
  const snapshot = await oldUsersRef.once('value');
  const users = snapshot.val();
  
  for (const [uid, userData] of Object.entries(users)) {
    const newUserData = {
      fullName: userData.UserName || userData.FullName || 'Usuario',
      email: userData.email || '',
      phone: userData.Phone || userData.phone || '',
      userType: userData.UserType || userData.userType || 'victim',
      createdAt: new Date().toISOString(),
    };
    
    await newUsersRef.child(uid).set(newUserData);
    console.log(`Usuario migrado: ${uid}`);
  }
  
  console.log('Migración completada');
}

migrateUsers();
```

### Paso 3: Crear Usuarios de Prueba

Crea al menos 3 usuarios de prueba para cada rol:

1. **Usuario (Víctima)**:
   ```json
   users/
     {uid}/
       fullName: "María González"
       email: "maria@test.com"
       phone: "+52 55 1234 5678"
       userType: "victim"
       createdAt: "2025-11-24T10:00:00Z"
   ```

2. **Monitorista (C5)**:
   ```json
   users/
     {uid}/
       fullName: "Carlos Monitorista"
       email: "monitor@c5.com"
       phone: "+52 55 8765 4321"
       userType: "monitor"
       createdAt: "2025-11-24T10:00:00Z"
   ```

3. **Policía**:
   ```json
   users/
     {uid}/
       fullName: "Oficial Ramírez"
       email: "ramirez@policia.com"
       phone: "+52 55 5555 1234"
       userType: "police"
       createdAt: "2025-11-24T10:00:00Z"
   ```

---

## 🧪 Pruebas del Sistema

### Prueba 1: Flujo Completo de Alerta

1. **Usuario (Móvil)**:
   - Inicia sesión con cuenta de tipo `victim`
   - Presiona el botón SOS rojo
   - Verifica que aparece "Alerta Activa"
   - Verifica que se muestra la ubicación

2. **Monitorista (Web)**:
   - Inicia sesión con cuenta de tipo `monitor`
   - Verifica que aparece la alerta en "Alertas Pendientes"
   - Verifica que se muestra el nombre, teléfono y ubicación
   - Clic en "Ver Mapa" para abrir Google Maps

3. **Policía (Móvil)**:
   - Inicia sesión con cuenta de tipo `police`
   - Activa el switch ON (Disponible)
   - Verifica que aparece en "Unidades Disponibles" del monitorista

4. **Asignación**:
   - Monitorista selecciona la alerta (clic en la tarjeta)
   - Monitorista clic en "ASIGNAR ALERTA" del policía
   - Verifica que la alerta desaparece de "Alertas Pendientes"
   - Verifica que el policía recibe la notificación (pantalla cambia a "EMERGENCIA ASIGNADA")

5. **Respuesta**:
   - Policía clic en "EN CAMINO"
   - Policía clic en "LLEGUÉ AL LUGAR"
   - Policía clic en "MISIÓN COMPLETADA"
   - Verifica que la pantalla vuelve a "Unidad Disponible"

6. **Historial**:
   - Monitorista clic en el icono de reportes (analytics)
   - Verifica que aparece la estadística: "Alertas resueltas: 1"

### Prueba 2: Cancelación de Alerta

1. Usuario presiona el botón SOS
2. Usuario presiona "CANCELAR ALERTA"
3. Verifica que la alerta desaparece del dashboard del monitorista
4. Verifica que se registra en `history_logs` con `action: "CANCELLED"`

### Prueba 3: Múltiples Alertas Simultáneas

1. Crea 3 usuarios diferentes
2. Envía alertas desde los 3 usuarios
3. Verifica que el monitorista ve las 3 alertas
4. Asigna cada alerta a un policía diferente
5. Verifica que cada policía ve solo su asignación

---

## 🔧 Solución de Problemas

### Problema 1: "No se pudo obtener la ubicación"

**Causa**: Permisos de ubicación no otorgados o GPS deshabilitado.

**Solución**:
- **Android**: Ve a Configuración → Aplicaciones → Mujer Segura → Permisos → Ubicación → Permitir siempre
- **iOS**: Ve a Ajustes → Privacidad → Ubicación → Mujer Segura → Siempre
- Verifica que el GPS esté activado en el dispositivo

### Problema 2: "Alerta no aparece en el dashboard del monitorista"

**Causa**: Reglas de seguridad de Firebase bloqueando la lectura.

**Solución**:
1. Ve a Firebase Console → Realtime Database → Reglas
2. Verifica que las reglas permiten lectura al monitorista:
   ```json
   "emergency_queue": {
     ".read": "root.child('users').child(auth.uid).child('userType').val() === 'monitor'"
   }
   ```
3. Verifica que el usuario tiene `userType: "monitor"` en `users/{uid}`

### Problema 3: "Policía no recibe asignación"

**Causa**: El policía no está escuchando su carpeta personal.

**Solución**:
1. Verifica que el controlador se inicializa correctamente:
   ```dart
   final PoliceDashboardController controller = Get.put(PoliceDashboardController());
   ```
2. Verifica que el UID del policía coincide con el usado en la asignación
3. Revisa los logs de la consola para ver si hay errores

### Problema 4: "Mapa estático no se carga"

**Causa**: API Key de Google Maps no configurada o inválida.

**Solución**:
1. Ve a Google Cloud Console: https://console.cloud.google.com
2. Habilita la API de **Maps Static API**
3. Crea una API Key (o usa la existente)
4. Reemplaza `TU_API_KEY_AQUI` en los archivos:
   - `police_dashboard_screen.dart` (línea 379)
   - `monitor_dashboard_screen.dart` (si usas mapa estático)
5. Reinicia la aplicación

### Problema 5: "Error: GetX Controller not found"

**Causa**: El controlador no está inicializado antes de usarse.

**Solución**:
```dart
// Inicializar el controlador en la pantalla
final AlertController controller = Get.put(AlertController());

// O inicializar globalmente en main.dart
void main() async {
  // ...
  Get.put(AlertController());
  Get.put(MonitorDashboardController());
  Get.put(PoliceDashboardController());
  runApp(const MyApp());
}
```

### Problema 6: "Estadísticas muestran 0"

**Causa**: No hay datos en `history_logs` o el formato de fecha es incorrecto.

**Solución**:
1. Verifica que las misiones completadas se registran en `history_logs`
2. Verifica que el campo `timestamp` tiene formato ISO 8601:
   ```dart
   "timestamp": DateTime.now().toIso8601String()
   ```
3. Revisa la consola de Firebase para ver si hay datos en `history_logs`

---

## 📞 Soporte Adicional

Si tienes dudas o problemas durante la implementación:

1. **Revisa los logs de la consola**:
   ```bash
   flutter run --verbose
   ```

2. **Verifica la consola de Firebase**:
   - Ve a Firebase Console → Realtime Database → Datos
   - Verifica que los nodos se están creando correctamente

3. **Prueba con datos de ejemplo**:
   - Crea manualmente una alerta en `emergency_queue` desde la consola
   - Verifica que aparece en el dashboard del monitorista

4. **Revisa la documentación oficial**:
   - Firebase: https://firebase.google.com/docs
   - GetX: https://pub.dev/packages/get
   - Geolocator: https://pub.dev/packages/geolocator

---

## ✅ Checklist Final

Antes de considerar la implementación completa, verifica:

- [ ] Los 3 controladores están copiados en `lib/controllers/`
- [ ] El modelo `app_user.dart` está en `lib/models/`
- [ ] Las 3 pantallas están copiadas en sus respectivas carpetas
- [ ] `main.dart` está actualizado con el `AuthWrapper`
- [ ] Las reglas de seguridad de Firebase están publicadas
- [ ] Los usuarios de prueba están creados (1 víctima, 1 monitorista, 1 policía)
- [ ] La API Key de Google Maps está configurada
- [ ] El flujo completo de alerta funciona (Usuario → Monitorista → Policía)
- [ ] Las estadísticas se generan correctamente
- [ ] Los archivos obsoletos están eliminados

---

## 🎉 ¡Listo!

Tu sistema de botón de emergencia SOS ahora está completamente refactorizado y funcional.

**Características implementadas**:
- ✅ Envío de alertas SOS con ubicación GPS
- ✅ Dashboard del monitorista con sistema de asignación
- ✅ Dashboard del policía con misiones en tiempo real
- ✅ Historial de alertas y reportes
- ✅ Código limpio y bien documentado
- ✅ Arquitectura escalable y mantenible

**Próximos pasos recomendados**:
1. Implementar notificaciones push con Firebase Cloud Messaging
2. Agregar sonido de alerta cuando llega una nueva emergencia
3. Implementar chat en tiempo real entre policía y víctima
4. Agregar gráficas de estadísticas (con charts_flutter)
5. Implementar modo offline con sincronización automática
