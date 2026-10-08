class OperatorUser {
  final String id;
  final String name;
  final String role;
  final String deviceLabel;
  final String avatarColor;

  OperatorUser({
    required this.id,
    required this.name,
    required this.role,
    required this.deviceLabel,
    required this.avatarColor,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'deviceLabel': deviceLabel,
      'avatarColor': avatarColor,
    };
  }

  factory OperatorUser.fromJson(Map<String, dynamic> map) {
    return OperatorUser(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Warehouse Staff',
      role: map['role']?.toString() ?? 'Staff',
      deviceLabel: map['deviceLabel']?.toString() ?? 'Android Tablet',
      avatarColor: map['avatarColor']?.toString() ?? '#0ea5e9',
    );
  }
}
