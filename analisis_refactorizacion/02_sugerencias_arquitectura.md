# Sugerencias de Arquitectura y Refactorización

## Resumen Ejecutivo

Tu proyecto tiene una **base sólida** con funcionalidades clave ya implementadas, pero necesita una **reestructuración para separar responsabilidades** entre los tres actores principales:

1. **Usuario (Víctima)**: Solo necesita enviar alertas SOS con ubicación
2. **Monitorista (C5)**: Recibe alertas y las asigna a policías disponibles
3. **Policía**: Recibe asignaciones y responde a emergencias

---

## 🎯 Arquitectura Propuesta (Simplificada)

### Flujo de Operación

```
┌─────────────┐
│   USUARIO   │ Presiona botón SOS
│  (Víctima)  │
└──────┬──────┘
       │
       │ 1. Envía alerta con GPS
       ↓
┌──────────────────┐
│ emergency_queue  │ Cola de alertas pendientes
│   (Firebase)     │
└──────┬───────────┘
       │
       │ 2. Monitorista ve alertas en tiempo real
       ↓
┌──────────────────┐
│  MONITORISTA     │ Asigna alerta a policía disponible
│     (C5)         │
└──────┬───────────┘
       │
       │ 3. Crea asignación
       ↓
┌──────────────────┐
│  assignments/    │ Carpeta personal del policía
│   {policeUID}    │
└──────┬───────────┘
       │
       │ 4. Policía recibe notificación
       ↓
┌──────────────────┐
│    POLICÍA       │ Ve detalles y responde
│                  │
└──────┬───────────┘
       │
       │ 5. Completa misión
       ↓
┌──────────────────┐
│  history_logs    │ Registro de alertas finalizadas
│   (Reportes)     │
└──────────────────┘
```

---

## 📊 Estructura de Firebase Simplificada

### 1. **users/** - Registro de Usuarios

Solo necesitas el registro de **usuarios (víctimas)**. Los monitoristas y policías pueden usar el mismo nodo pero con un campo `userType` diferente.

```json
users/
  {uid}/
    fullName: "María González"
    phone: "+52 55 1234 5678"
    email: "maria@example.com"
    userType: "victim"  // "victim", "monitor", "police"
    createdAt: "2025-11-24T10:30:00Z"
```

**Campos necesarios**:
- `fullName`: Nombre completo del usuario
- `phone`: Teléfono de contacto
- `email`: Email (ya viene de Firebase Auth)
- `userType`: Tipo de usuario (para filtrar)
- `createdAt`: Fecha de registro

**Campos eliminados**:
- ❌ `UserName`, `FullName` (duplicados)
- ❌ `Phone` (mayúscula inconsistente)
- ❌ `address`, `city`, `state`, `country`, `zipCode` (no se usan)
- ❌ `latitude`, `longitude` (la ubicación es temporal, no del perfil)

---

### 2. **emergency_queue/** - Cola de Alertas Pendientes

Este nodo solo es visible para el **monitorista**. Cuando un usuario presiona el botón SOS, se crea una entrada aquí.

```json
emergency_queue/
  {victimUID}/
    victim_id: "abc123"
    victim_name: "María González"
    victim_phone: "+52 55 1234 5678"
    latitude: 19.432608
    longitude: -99.133209
    status: "PENDING"
    timestamp: "2025-11-24T15:45:30Z"
    type: "SOS"
```

**Estados posibles**:
- `PENDING`: Alerta recién creada, esperando asignación
- `ASSIGNED`: Ya fue asignada a un policía (se mueve a `assignments/`)
- `CANCELLED`: El usuario canceló la alerta

**Cuándo se elimina**:
- Cuando el monitorista la asigna a un policía
- Cuando el usuario cancela la alerta

---

### 3. **available_units/** - Policías Disponibles

Este nodo contiene los policías que tienen el switch **ON** (disponibles para recibir asignaciones).

```json
available_units/
  {policeUID}/
    name: "Oficial Ramírez"
    latitude: 19.430000
    longitude: -99.130000
    status: "available"  // "available", "busy"
    last_update: "2025-11-24T15:50:00Z"
```

**Cuándo se actualiza**:
- Cuando el policía activa/desactiva el switch ON/OFF
- Cuando el policía actualiza su ubicación (cada 30 segundos)
- Cuando el policía recibe una asignación (status → "busy")

**Cuándo se elimina**:
- Cuando el policía desactiva el switch (OFF)
- Cuando el policía cierra sesión

---

### 4. **assignments/** - Asignaciones Activas

Cada policía tiene su **carpeta personal** donde recibe las asignaciones del monitorista.

```json
assignments/
  {policeUID}/
    victim_id: "abc123"
    victim_name: "María González"
    victim_phone: "+52 55 1234 5678"
    latitude: 19.432608
    longitude: -99.133209
    assigned_at: "2025-11-24T15:46:00Z"
    assigned_by: "monitorUID"
    status: "ASSIGNED"  // "ASSIGNED", "EN_ROUTE", "ARRIVED", "RESOLVED"
```

**Estados posibles**:
- `ASSIGNED`: Recién asignada
- `EN_ROUTE`: Policía en camino
- `ARRIVED`: Policía llegó al lugar
- `RESOLVED`: Emergencia resuelta

**Cuándo se crea**:
- Cuando el monitorista asigna una alerta a un policía

**Cuándo se elimina**:
- Cuando el policía completa la misión (se mueve a `history_logs/`)

---

### 5. **history_logs/** - Historial de Alertas

Registro de todas las alertas finalizadas para generar reportes.

```json
history_logs/
  {logID}/  // Formato: {victimUID}_{timestamp}
    victim_id: "abc123"
    victim_name: "María González"
    assigned_to: "policeUID"
    assigned_to_name: "Oficial Ramírez"
    action: "RESOLVED"  // "DISPATCHED", "RESOLVED", "CANCELLED"
    created_at: "2025-11-24T15:45:30Z"
    assigned_at: "2025-11-24T15:46:00Z"
    resolved_at: "2025-11-24T16:10:00Z"
    response_time_minutes: 24
    latitude: 19.432608
    longitude: -99.133209
```

**Acciones posibles**:
- `DISPATCHED`: Alerta asignada a un policía
- `RESOLVED`: Emergencia resuelta exitosamente
- `CANCELLED`: Usuario canceló la alerta

**Cuándo se crea**:
- Cuando el policía completa la misión
- Cuando el usuario cancela la alerta

---

## 🔧 Refactorización de Controladores

### 1. **AlertController** (antes `messageController`)

**Ubicación**: `lib/features/user/controllers/alert_controller.dart`

**Responsabilidades**:
- Enviar alerta SOS a `emergency_queue/`
- Cancelar alerta
- Obtener ubicación GPS
- Manejar permisos de ubicación

**Cambios**:
- ✅ Renombrar clase a `AlertController` (convención PascalCase)
- ✅ Eliminar lógica de SMS (opcional, solo para contactos personales)
- ✅ Escribir en `emergency_queue/` en lugar de `activeResponders/`
- ✅ Usar campos consistentes: `fullName`, `phone` (minúsculas)
- ✅ Separar responsabilidades: crear un `LocationService` aparte

**Métodos principales**:
```dart
- sendEmergencyAlert()     // Envía alerta SOS
- cancelAlert()            // Cancela alerta activa
- getCurrentPosition()     // Obtiene ubicación GPS
- handleLocationPermission() // Maneja permisos
```

---

### 2. **MonitorDashboardController** (NUEVO)

**Ubicación**: `lib/features/monitor/monitor_dashboard_controller.dart`

**Responsabilidades**:
- Escuchar `emergency_queue/` en tiempo real
- Escuchar `available_units/` en tiempo real
- Asignar alertas a policías disponibles
- Generar reportes desde `history_logs/`

**Métodos principales**:
```dart
- listenEmergencyQueue()   // Stream de alertas pendientes
- listenAvailableUnits()   // Stream de policías disponibles
- assignAlertToPolice()    // Asigna alerta a policía
- generateDailyReport()    // Genera reporte del día
```

---

### 3. **PoliceController** (antes parte de `responder_dashboard.dart`)

**Ubicación**: `lib/features/police/police_controller.dart`

**Responsabilidades**:
- Escuchar `assignments/{myUID}` en tiempo real
- Actualizar estado de disponibilidad (switch ON/OFF)
- Actualizar ubicación en `available_units/`
- Completar misión y mover a `history_logs/`

**Métodos principales**:
```dart
- listenMyAssignment()     // Stream de mi asignación actual
- toggleAvailability()     // ON/OFF switch
- updateMyLocation()       // Actualiza GPS cada 30s
- completeMission()        // Marca como resuelta
```

---

## 🗑️ Código a Eliminar

### Archivos Completos
- ❌ `emergencies_screen.dart` (usa nodo `sos` que no existe)
- ❌ `select_responder.dart` (lógica de asignación manual obsoleta)
- ❌ `response_maps.dart` (si no se usa)

### Nodos de Firebase
- ❌ `activeResponders/` (reemplazar por `emergency_queue/` y `assignments/`)
- ❌ `sos/` (no se usa actualmente)

### Dependencias Innecesarias
- ❌ `background_sms` (si decides no enviar SMS)
- ❌ `flutter_sms` (duplicado con background_sms)
- ❌ `android_intent_plus` (si no se usa)
- ❌ `zego_uikit_prebuilt_live_streaming` (si no implementas videollamada)

### Código Comentado
- ❌ Eliminar todo el código comentado en `emergencies_screen.dart` (líneas 90-112)
- ❌ Eliminar imports no utilizados

---

## 📱 Interfaces de Usuario Propuestas

### 1. **Usuario (Víctima) - Móvil**

**Pantalla Principal**:
```
┌─────────────────────────┐
│   Mujer Segura          │
│                         │
│   ┌───────────────┐     │
│   │               │     │
│   │   BOTÓN SOS   │     │ ← Botón rojo grande
│   │   (ROJO)      │     │
│   │               │     │
│   └───────────────┘     │
│                         │
│   Estado: Segura ✓      │
│                         │
│   [Mis Contactos]       │
│   [Mi Perfil]           │
└─────────────────────────┘
```

**Al presionar SOS**:
```
┌─────────────────────────┐
│   ⚠️ ALERTA ACTIVA      │
│                         │
│   Ubicación enviada     │
│   Esperando respuesta...│
│                         │
│   📍 Lat: 19.4326       │
│   📍 Long: -99.1332     │
│                         │
│   ┌───────────────┐     │
│   │  CANCELAR     │     │ ← Botón verde
│   └───────────────┘     │
└─────────────────────────┘
```

---

### 2. **Monitorista (C5) - Web**

**Dashboard Principal**:
```
┌────────────────────────────────────────────────────────┐
│  Centro de Comando C5                    [Reportes]    │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌─────────────────────┐  ┌──────────────────────┐   │
│  │ ALERTAS PENDIENTES  │  │ UNIDADES DISPONIBLES │   │
│  │ (emergency_queue)   │  │ (available_units)    │   │
│  ├─────────────────────┤  ├──────────────────────┤   │
│  │ 🔴 María González   │  │ 🟢 Oficial Ramírez   │   │
│  │    15:45:30         │  │    [ASIGNAR]         │   │
│  │    📍 Ver mapa      │  │                      │   │
│  │    📞 55-1234-5678  │  │ 🟢 Oficial López     │   │
│  │    [ASIGNAR]        │  │    [ASIGNAR]         │   │
│  ├─────────────────────┤  │                      │   │
│  │ 🔴 Ana Martínez     │  │ 🔴 Oficial Torres    │   │
│  │    15:50:12         │  │    (Ocupado)         │   │
│  │    📍 Ver mapa      │  │                      │   │
│  │    [ASIGNAR]        │  └──────────────────────┘   │
│  └─────────────────────┘                             │
│                                                        │
│  Estadísticas del día:                                │
│  • Alertas recibidas: 12                              │
│  • Alertas resueltas: 10                              │
│  • Tiempo promedio de respuesta: 18 min              │
└────────────────────────────────────────────────────────┘
```

**Flujo de Asignación**:
1. Monitorista ve alerta en "ALERTAS PENDIENTES"
2. Selecciona un policía de "UNIDADES DISPONIBLES"
3. Clic en "ASIGNAR"
4. La alerta se mueve de `emergency_queue/` a `assignments/{policeUID}`
5. El policía recibe notificación en su app

---

### 3. **Policía - Móvil**

**Estado: Sin Asignación**
```
┌─────────────────────────┐
│   Patrulla en Servicio  │
│                         │
│   🟢                    │
│   UNIDAD DISPONIBLE     │
│                         │
│   Esperando asignación  │
│   del C5...             │
│                         │
│   [ON] ←→ [OFF]         │ ← Switch
│                         │
│   [Mi Perfil]           │
└─────────────────────────┘
```

**Estado: Con Asignación**
```
┌─────────────────────────┐
│   ⚠️ EMERGENCIA ASIGNADA│
│                         │
│   María González        │
│   📞 55-1234-5678       │
│                         │
│   [🗺️ Ver en Mapa]      │
│   [📞 Llamar]           │
│                         │
│   Distancia: 2.3 km     │
│                         │
│   ┌───────────────┐     │
│   │ EN CAMINO     │     │
│   └───────────────┘     │
│   ┌───────────────┐     │
│   │ LLEGUÉ        │     │
│   └───────────────┘     │
│   ┌───────────────┐     │
│   │ COMPLETADA ✓  │     │
│   └───────────────┘     │
└─────────────────────────┘
```

---

## 🚀 Plan de Implementación

### Fase 1: Refactorizar Estructura de Firebase ✅
1. Crear nodos nuevos: `emergency_queue/`, `available_units/`, `assignments/`, `history_logs/`
2. Migrar datos de `Users/` a `users/` (minúscula)
3. Estandarizar campos: `fullName`, `phone`, `userType`

### Fase 2: Refactorizar Controlador de Usuario ✅
1. Renombrar `messageController` → `AlertController`
2. Cambiar escritura de `activeResponders/` → `emergency_queue/`
3. Simplificar campos enviados
4. Eliminar lógica de SMS (opcional)

### Fase 3: Crear Dashboard del Monitorista ✅
1. Crear `MonitorDashboard` (Web)
2. StreamBuilder para `emergency_queue/`
3. StreamBuilder para `available_units/`
4. Implementar lógica de asignación
5. Agregar botón de reportes

### Fase 4: Refactorizar Dashboard del Policía ✅
1. Cambiar de escuchar `activeResponders/` → `assignments/{myUID}`
2. Implementar switch ON/OFF que actualice `available_units/`
3. Agregar botones de estado: "EN CAMINO", "LLEGUÉ", "COMPLETADA"
4. Al completar, mover a `history_logs/`

### Fase 5: Implementar Sistema de Reportes ✅
1. Crear `ReportsController`
2. Consultar `history_logs/` por fecha
3. Calcular métricas: total de alertas, tiempo promedio, etc.
4. Generar gráficas (opcional)

---

## 📋 Checklist de Refactorización

### Estructura de Firebase
- [ ] Crear nodo `emergency_queue/`
- [ ] Crear nodo `available_units/`
- [ ] Crear nodo `assignments/`
- [ ] Crear nodo `history_logs/`
- [ ] Migrar `Users/` → `users/`
- [ ] Eliminar nodo `activeResponders/`
- [ ] Eliminar nodo `sos/`

### Controladores
- [ ] Renombrar `messageController` → `AlertController`
- [ ] Crear `MonitorDashboardController`
- [ ] Crear `PoliceController`
- [ ] Crear `ReportsController`
- [ ] Eliminar código comentado

### Interfaces
- [ ] Crear `MonitorDashboard` (Web)
- [ ] Refactorizar `ResponderDashboard` → `PoliceDashboard`
- [ ] Simplificar pantalla de usuario (solo botón SOS)
- [ ] Crear `ReportsScreen`

### Limpieza
- [ ] Eliminar `emergencies_screen.dart`
- [ ] Eliminar `select_responder.dart`
- [ ] Eliminar dependencias no usadas
- [ ] Eliminar imports no utilizados
- [ ] Estandarizar nombres de variables

---

## 💡 Recomendaciones Adicionales

### Seguridad
- ⚠️ **No expongas API Keys en el código**: Usa variables de entorno o Firebase Remote Config
- ⚠️ **Implementa reglas de seguridad en Firebase**: Solo el monitorista puede escribir en `assignments/`
- ⚠️ **Valida datos del lado del servidor**: Usa Cloud Functions para validar alertas

### Rendimiento
- ⚠️ **Limita las consultas de Firebase**: Usa `.limitToLast(50)` para no cargar todas las alertas
- ⚠️ **Implementa paginación en reportes**: No cargues todo el historial de una vez
- ⚠️ **Optimiza la actualización de ubicación**: Solo actualiza si el policía se movió >50 metros

### Experiencia de Usuario
- ⚠️ **Agrega notificaciones push**: Usa Firebase Cloud Messaging para notificar al policía
- ⚠️ **Implementa sonido de alerta**: Cuando el monitorista recibe una nueva alerta
- ⚠️ **Agrega confirmación de asignación**: El policía debe confirmar que recibió la asignación

### Testing
- ⚠️ **Crea usuarios de prueba**: Un usuario, un monitorista, dos policías
- ⚠️ **Prueba el flujo completo**: Desde el botón SOS hasta la resolución
- ⚠️ **Prueba casos extremos**: Sin GPS, sin internet, múltiples alertas simultáneas

---

## 🎯 Resultado Esperado

Al finalizar la refactorización, tendrás:

1. ✅ **Sistema de alertas funcional** con flujo claro: Usuario → Monitorista → Policía
2. ✅ **Separación de responsabilidades** entre los tres actores
3. ✅ **Código limpio y mantenible** con nombres consistentes
4. ✅ **Base de datos estructurada** con nodos específicos para cada función
5. ✅ **Sistema de reportes** para analizar el desempeño
6. ✅ **Interfaces intuitivas** para cada tipo de usuario

---

## 📞 Contacto y Soporte

Si tienes dudas durante la implementación, revisa:
- Documentación de Firebase: https://firebase.google.com/docs
- Documentación de GetX: https://pub.dev/packages/get
- Documentación de Geolocator: https://pub.dev/packages/geolocator
