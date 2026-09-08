/// Model representing a student's bound hardware device for single session enforcement.
class StudentDeviceModel {
  final String id;
  final String studentId;
  final String deviceIdentifier;
  final String deviceModel;
  final String platform; // 'android', 'ios', 'web', 'windows'
  final String fcmToken;
  final bool isActive;
  final DateTime lastSeen;
  final DateTime createdAt;

  const StudentDeviceModel({
    required this.id,
    required this.studentId,
    required this.deviceIdentifier,
    this.deviceModel = '',
    this.platform = 'android',
    this.fcmToken = '',
    this.isActive = true,
    required this.lastSeen,
    required this.createdAt,
  });

  Map<String, dynamic> toSupabaseMap() {
    final map = <String, dynamic>{
      'student_id': studentId,
      'device_identifier': deviceIdentifier,
      'device_model': deviceModel,
      'platform': platform,
      'fcm_token': fcmToken,
      'is_active': isActive,
      'last_seen': lastSeen.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  factory StudentDeviceModel.fromSupabase(Map<String, dynamic> map) {
    return StudentDeviceModel(
      id: map['id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      deviceIdentifier: map['device_identifier']?.toString() ?? '',
      deviceModel: map['device_model']?.toString() ?? '',
      platform: map['platform']?.toString() ?? 'android',
      fcmToken: map['fcm_token']?.toString() ?? '',
      isActive: map['is_active'] as bool? ?? true,
      lastSeen: map['last_seen'] != null 
          ? DateTime.tryParse(map['last_seen'].toString()) ?? DateTime.now() 
          : DateTime.now(),
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() 
          : DateTime.now(),
    );
  }
}
