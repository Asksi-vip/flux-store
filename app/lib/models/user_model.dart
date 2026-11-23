class UserModel {
  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.email,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String phone;
  final String? email;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'phone': phone,
        'email': email,
        'created_at': createdAt?.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        uid: json['uid'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  UserModel copyWith({
    String? name,
    String? phone,
    String? email,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt,
    );
  }
}
