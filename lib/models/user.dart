class AppUser {
  final String uid;
  final String name;
  final String email;
  final bool isAdmin;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.isAdmin = false,
  });

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      isAdmin: data['isAdmin'] ?? false,
    );
  }
}