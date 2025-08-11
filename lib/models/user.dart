class User {
  final int id;
  final String email;
  final String? profileImagePath;

  User({
    required this.id,
    required this.email,
    this.profileImagePath,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['account_id'] ?? json['id'],
      email: json['email'],
      profileImagePath: json['profile_image_path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'profile_image_path': profileImagePath,
    };
  }

  User copyWith({
    int? id,
    String? email,
    String? profileImagePath,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      profileImagePath: profileImagePath ?? this.profileImagePath,
    );
  }
}
