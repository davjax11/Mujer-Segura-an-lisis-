import 'package:firebase_database/firebase_database.dart';

/// Modelo de Usuario de la Aplicación
/// Representa a todos los tipos de usuarios: víctimas, monitoristas y policías
class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String userType; // "victim", "monitor", "police"
  final String? imageUrl;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.userType,
    this.imageUrl,
    required this.createdAt,
  });

  /// Constructor desde DataSnapshot de Firebase
  factory AppUser.fromSnapshot(DataSnapshot snapshot) {
    if (!snapshot.exists) {
      throw Exception("Usuario no encontrado");
    }

    Map<dynamic, dynamic> data = snapshot.value as Map;
    String userId = snapshot.key!;

    return AppUser(
      id: userId,
      // Soportar tanto el formato nuevo como el antiguo
      fullName: data['fullName'] ?? data['UserName'] ?? data['FullName'] ?? 'Usuario',
      email: data['email'] ?? '',
      phone: data['phone'] ?? data['Phone'] ?? '',
      userType: data['userType'] ?? data['UserType'] ?? 'victim',
      imageUrl: data['imageUrl'],
      createdAt: data['createdAt'] != null 
          ? DateTime.parse(data['createdAt']) 
          : DateTime.now(),
    );
  }

  /// Convertir a Map para guardar en Firebase
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'userType': userType,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Crear una copia con campos modificados
  AppUser copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? userType,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Verificar si es víctima
  bool get isVictim => userType == 'victim';

  /// Verificar si es monitorista
  bool get isMonitor => userType == 'monitor';

  /// Verificar si es policía
  bool get isPolice => userType == 'police';

  @override
  String toString() {
    return 'AppUser(id: $id, fullName: $fullName, email: $email, phone: $phone, userType: $userType)';
  }
}

/// Modelo de Alerta de Emergencia
class EmergencyAlert {
  final String victimId;
  final String victimName;
  final String victimPhone;
  final double latitude;
  final double longitude;
  final String status; // "PENDING", "ASSIGNED", "RESOLVED", "CANCELLED"
  final DateTime timestamp;
  final String type; // "SOS"

  EmergencyAlert({
    required this.victimId,
    required this.victimName,
    required this.victimPhone,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.timestamp,
    required this.type,
  });

  /// Constructor desde Map de Firebase
  factory EmergencyAlert.fromMap(Map<dynamic, dynamic> data) {
    return EmergencyAlert(
      victimId: data['victim_id'] ?? '',
      victimName: data['victim_name'] ?? 'Usuario',
      victimPhone: data['victim_phone'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'PENDING',
      timestamp: DateTime.parse(data['timestamp']),
      type: data['type'] ?? 'SOS',
    );
  }

  /// Convertir a Map para guardar en Firebase
  Map<String, dynamic> toMap() {
    return {
      'victim_id': victimId,
      'victim_name': victimName,
      'victim_phone': victimPhone,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
    };
  }

  /// Crear una copia con campos modificados
  EmergencyAlert copyWith({
    String? victimId,
    String? victimName,
    String? victimPhone,
    double? latitude,
    double? longitude,
    String? status,
    DateTime? timestamp,
    String? type,
  }) {
    return EmergencyAlert(
      victimId: victimId ?? this.victimId,
      victimName: victimName ?? this.victimName,
      victimPhone: victimPhone ?? this.victimPhone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
    );
  }

  @override
  String toString() {
    return 'EmergencyAlert(victimId: $victimId, victimName: $victimName, status: $status, timestamp: $timestamp)';
  }
}

/// Modelo de Unidad Policial Disponible
class PoliceUnit {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String status; // "available", "busy"
  final DateTime lastUpdate;

  PoliceUnit({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.lastUpdate,
  });

  /// Constructor desde Map de Firebase
  factory PoliceUnit.fromMap(String id, Map<dynamic, dynamic> data) {
    return PoliceUnit(
      id: id,
      name: data['name'] ?? 'Oficial',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'available',
      lastUpdate: DateTime.parse(data['last_update']),
    );
  }

  /// Convertir a Map para guardar en Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'last_update': lastUpdate.toIso8601String(),
    };
  }

  /// Verificar si está disponible
  bool get isAvailable => status == 'available';

  /// Verificar si está ocupado
  bool get isBusy => status == 'busy';

  @override
  String toString() {
    return 'PoliceUnit(id: $id, name: $name, status: $status, lastUpdate: $lastUpdate)';
  }
}

/// Modelo de Asignación de Misión
class MissionAssignment {
  final String victimId;
  final String victimName;
  final String victimPhone;
  final double latitude;
  final double longitude;
  final DateTime assignedAt;
  final String assignedBy;
  final String status; // "ASSIGNED", "EN_ROUTE", "ARRIVED", "RESOLVED"

  MissionAssignment({
    required this.victimId,
    required this.victimName,
    required this.victimPhone,
    required this.latitude,
    required this.longitude,
    required this.assignedAt,
    required this.assignedBy,
    required this.status,
  });

  /// Constructor desde Map de Firebase
  factory MissionAssignment.fromMap(Map<dynamic, dynamic> data) {
    return MissionAssignment(
      victimId: data['victim_id'] ?? '',
      victimName: data['victim_name'] ?? 'Usuario',
      victimPhone: data['victim_phone'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      assignedAt: DateTime.parse(data['assigned_at']),
      assignedBy: data['assigned_by'] ?? '',
      status: data['status'] ?? 'ASSIGNED',
    );
  }

  /// Convertir a Map para guardar en Firebase
  Map<String, dynamic> toMap() {
    return {
      'victim_id': victimId,
      'victim_name': victimName,
      'victim_phone': victimPhone,
      'latitude': latitude,
      'longitude': longitude,
      'assigned_at': assignedAt.toIso8601String(),
      'assigned_by': assignedBy,
      'status': status,
    };
  }

  @override
  String toString() {
    return 'MissionAssignment(victimId: $victimId, victimName: $victimName, status: $status)';
  }
}
