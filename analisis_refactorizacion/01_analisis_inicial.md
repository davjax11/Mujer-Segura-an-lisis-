# Análisis Inicial del Proyecto "Mujer Segura"

## Fecha de Análisis
24 de noviembre de 2025

## Objetivo del Proyecto
Sistema de botón de emergencia SOS que permite:
- **Usuarios (víctimas)**: Enviar alertas de emergencia con ubicación en tiempo real
- **Monitoristas (C5)**: Recibir alertas y asignarlas a policías disponibles
- **Policías**: Recibir asignaciones y responder a emergencias

---

## Estructura Actual del Proyecto

### Tecnologías Identificadas
- **Framework**: Flutter (multiplataforma: móvil y web)
- **Backend**: Firebase Realtime Database
- **Autenticación**: Firebase Auth
- **Gestión de estado**: GetX
- **Geolocalización**: Geolocator, Geocoding
- **Mapas**: Google Maps API (Static Maps)
- **Streaming de video**: Zego UIKit (live streaming)
- **SMS**: background_sms (solo móvil)

### Estructura de Carpetas
```
lib/
├── User.dart                          # Modelo de usuario
├── common_widgets/                    # Widgets compartidos
│   ├── constants.dart
│   ├── form_footer.dart
│   └── onboarding.dart
├── features/
│   ├── emergency_contacts/            # Gestión de contactos de emergencia
│   ├── list_of_responders/            # Selección de respondedores
│   ├── login/                         # Pantallas de login
│   ├── responder/                     # Dashboard del respondedor (policía)
│   ├── response_screen/               # Pantallas de respuesta a emergencias
│   └── user/                          # Funcionalidades del usuario
│       ├── controllers/               # Controladores GetX
│       └── screens/                   # Pantallas del usuario
└── main.dart                          # Punto de entrada
```

---

## Análisis de Componentes Clave

### 1. **message_sending.dart** (Controlador de Alertas)

**Ubicación**: `lib/features/user/controllers/message_sending.dart`

**Funcionalidades Identificadas**:
- ✅ Obtención de ubicación GPS con alta precisión
- ✅ Manejo de permisos de ubicación
- ✅ Geocoding (convertir coordenadas a dirección legible)
- ✅ Envío de SMS a contactos de emergencia (solo móvil)
- ✅ Escritura de alerta en Firebase (`activeResponders`)
- ✅ Obtención de datos del usuario desde Firebase

**Problemas Detectados**:
- ❌ **Nombre de clase no sigue convenciones**: `messageController` debería ser `MessageController`
- ❌ **Estructura de BD inconsistente**: Usa `Users/` con mayúscula, pero debería ser `users/`
- ❌ **Campos inconsistentes**: Busca `UserName`, `FullName`, `Phone`, `phone` (múltiples variantes)
- ❌ **Mezcla de responsabilidades**: Maneja SMS, GPS, Firebase y UI en un solo controlador
- ❌ **No hay separación entre alertas pendientes y asignadas**
- ❌ **El campo `userAddress` contiene el nombre del usuario, no la dirección** (confuso)
- ⚠️ **Dependencia de `background_sms`**: Solo funciona en Android, no en iOS ni Web

**Código Rescatable**:
- ✅ Lógica de permisos de ubicación
- ✅ Obtención de coordenadas GPS
- ✅ Estructura básica de escritura en Firebase
- ✅ Manejo de errores con try-catch

---

### 2. **responder_dashboard.dart** (Dashboard del Policía/Monitorista)

**Ubicación**: `lib/features/responder/responder_dashboard.dart`

**Funcionalidades Identificadas**:
- ✅ StreamBuilder para escuchar alertas en tiempo real desde `activeResponders`
- ✅ Filtrado de alertas (no mostrar al propio usuario, ni a otros policías)
- ✅ Cálculo de distancia entre policía y víctima
- ✅ Visualización de mapa estático con Google Maps API
- ✅ Botones para llamar y abrir ubicación en Google Maps
- ✅ Switch ON/OFF para disponibilidad del policía
- ✅ Persistencia del estado del switch con SharedPreferences

**Problemas Detectados**:
- ❌ **Mezcla de roles**: Este dashboard es para policías, pero debería haber uno separado para monitoristas
- ❌ **No hay lógica de asignación**: Los policías ven todas las alertas, pero no hay sistema de asignación
- ❌ **Coordenadas hardcodeadas**: `responderLat = 19.4326` (Ciudad de México) no es dinámica
- ❌ **API Key expuesta en el código**: Riesgo de seguridad
- ❌ **No hay historial de alertas atendidas**
- ❌ **Falta sistema de reportes**
- ⚠️ **Filtro manual por tipo**: Usa strings como `'Police'`, `'Ambulance'`, `'Fire Fighter'` (propenso a errores)

**Código Rescatable**:
- ✅ StreamBuilder para escuchar Firebase en tiempo real
- ✅ Lógica de filtrado de alertas
- ✅ Cálculo de distancia (fórmula Haversine)
- ✅ Integración con Google Maps (estático y dinámico)
- ✅ UI con Cards y ListTiles

---

### 3. **emergencies_screen.dart** (Pantalla de Emergencias)

**Ubicación**: `lib/features/response_screen/emergencies_screen.dart`

**Funcionalidades Identificadas**:
- ✅ StreamBuilder para escuchar nodo `sos` en Firebase
- ✅ Navegación a `SelectResponder` para asignar respondedor
- ✅ Botón para abrir ubicación en Google Maps
- ✅ Botón para iniciar videollamada con Zego

**Problemas Detectados**:
- ❌ **Nodo `sos` no se usa en el código actual**: El sistema escribe en `activeResponders`, no en `sos`
- ❌ **Funcionalidad de videollamada no está integrada con el flujo principal**
- ❌ **Código comentado sin eliminar** (líneas 90-112)
- ❌ **No hay validación de datos nulos**
- ⚠️ **Dependencia de `Platform.isAndroid`**: No funciona en Web

**Código Rescatable**:
- ✅ Estructura de StreamBuilder
- ✅ Integración con url_launcher para abrir mapas

---

### 4. **User.dart** (Modelo de Usuario)

**Ubicación**: `lib/User.dart`

**Funcionalidades Identificadas**:
- ✅ Modelo de datos para usuarios
- ✅ Constructor desde DataSnapshot de Firebase

**Problemas Detectados**:
- ❌ **Campos inconsistentes**: Usa `UserName`, `Phone`, `UserType` con mayúsculas
- ❌ **Falta validación de datos nulos**
- ❌ **No incluye campos necesarios**: `fullName`, `phone` (minúsculas)
- ⚠️ **Campos opcionales sin uso claro**: `address`, `city`, `state`, etc.

**Código Rescatable**:
- ✅ Estructura básica del modelo
- ✅ Constructor `fromSnapshot`

---

## Funcionalidades NO Implementadas o Incompletas

### ❌ Sistema de Asignación de Alertas
- No existe un flujo claro de **Alerta → Monitorista → Asignación → Policía**
- Las alertas se escriben en `activeResponders`, pero no hay cola de espera
- No hay distinción entre alertas pendientes, asignadas y resueltas

### ❌ Dashboard del Monitorista (C5)
- No existe una interfaz específica para el monitorista
- El `responder_dashboard.dart` es para policías, no para monitoristas
- No hay sistema de asignación manual de alertas a policías

### ❌ Dashboard del Policía con Asignaciones
- Los policías ven todas las alertas, no solo las asignadas a ellos
- No hay carpeta personal `assignments/{policeID}` en Firebase
- No hay sistema de notificación cuando se asigna una alerta

### ❌ Historial de Alertas
- No existe el nodo `history_logs` en Firebase
- No hay registro de alertas finalizadas
- No se puede generar reportes de alertas atendidas

### ❌ Sistema de Reportes
- No hay estadísticas de alertas por día/mes
- No hay métricas de tiempo de respuesta
- No hay análisis de zonas con más alertas

### ❌ Gestión de Unidades Disponibles
- No existe el nodo `available_units` en Firebase
- El switch ON/OFF del policía no actualiza su disponibilidad en Firebase
- No hay lista de policías disponibles para el monitorista

### ⚠️ Videollamada en Vivo
- Está integrada con Zego, pero no está conectada con el flujo de alertas
- No se activa automáticamente al enviar una alerta
- No está claro cómo el policía accede a la videollamada

### ⚠️ Contactos de Emergencia
- Existe el módulo, pero solo envía SMS (no funciona en Web)
- No hay integración con el sistema de alertas principal

---

## Estructura de Firebase Actual vs. Propuesta

### Estructura Actual (Problemática)
```
firebase/
├── Users/                    # Usuarios (inconsistente con mayúscula)
│   └── {uid}/
│       ├── UserName
│       ├── Phone
│       ├── UserType
│       └── email
├── activeResponders/         # Alertas activas (mezcla víctimas y policías)
│   └── {uid}/
│       ├── lat
│       ├── long
│       ├── userAddress       # Contiene el nombre, no la dirección
│       ├── responderType     # "User", "Police", "Ambulance", etc.
│       ├── userID
│       ├── phone
│       ├── timestamp
│       └── status
└── sos/                      # Nodo no utilizado actualmente
```

### Estructura Propuesta (Profesional)
```
firebase/
├── users/                    # Usuarios (minúscula, consistente)
│   └── {uid}/
│       ├── fullName
│       ├── phone
│       ├── email
│       └── userType          # "victim", "monitor", "police"
├── emergency_queue/          # Cola de alertas pendientes (solo monitorista)
│   └── {victimUID}/
│       ├── victim_id
│       ├── victim_name
│       ├── victim_phone
│       ├── latitude
│       ├── longitude
│       ├── status            # "PENDING"
│       ├── timestamp
│       └── type              # "SOS"
├── available_units/          # Policías disponibles (switch ON)
│   └── {policeUID}/
│       ├── name
│       ├── latitude
│       ├── longitude
│       ├── status            # "available", "busy"
│       └── last_update
├── assignments/              # Asignaciones activas (carpeta personal del policía)
│   └── {policeUID}/
│       ├── victim_id
│       ├── victim_name
│       ├── victim_phone
│       ├── latitude
│       ├── longitude
│       ├── assigned_at
│       └── status            # "ASSIGNED", "EN_ROUTE", "ARRIVED"
└── history_logs/             # Historial de alertas finalizadas
    └── {logID}/
        ├── victim_id
        ├── assigned_to       # policeUID
        ├── action            # "DISPATCHED", "RESOLVED", "CANCELLED"
        ├── timestamp
        └── ...
```

---

## Resumen de Código Rescatable

### ✅ Funcionalidades que Funcionan Bien
1. **Autenticación con Firebase Auth**
2. **Obtención de ubicación GPS con permisos**
3. **StreamBuilder para escuchar Firebase en tiempo real**
4. **Cálculo de distancia entre dos coordenadas**
5. **Integración con Google Maps (estático y dinámico)**
6. **Apertura de Google Maps con url_launcher**
7. **UI con GetX para navegación y snackbars**
8. **Persistencia de estado con SharedPreferences**

### ⚠️ Funcionalidades que Necesitan Refactorización
1. **Controlador de alertas** (`message_sending.dart`) → Renombrar y simplificar
2. **Dashboard del respondedor** → Separar en dos: monitorista y policía
3. **Modelo de usuario** → Estandarizar nombres de campos
4. **Estructura de Firebase** → Implementar arquitectura propuesta

### ❌ Funcionalidades que Deben Eliminarse
1. **Código comentado sin usar**
2. **Nodo `sos` en Firebase** (no se usa)
3. **Campos duplicados en el modelo de usuario**
4. **Dependencias innecesarias** (si no se usan)

---

## Próximos Pasos

1. **Diseñar arquitectura simplificada** basada en el flujo:
   - Usuario → Alerta SOS → Cola de Emergencias → Monitorista → Asignación → Policía
2. **Refactorizar controladores** con nombres consistentes
3. **Crear dashboard del monitorista** (Web) con sistema de asignación
4. **Crear dashboard del policía** que solo muestre su asignación actual
5. **Implementar historial y reportes**
6. **Estandarizar estructura de Firebase**
7. **Eliminar código innecesario**
