class UserModel {
  final String uid;
  final String name;
  final String role;

  UserModel({required this.uid, required this.name, required this.role});

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      name: data['name'] ?? '',
      role: data['role'] ?? 'kasir',
    );
  }
}