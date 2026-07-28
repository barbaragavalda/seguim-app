class UserList {
  const UserList({required this.id, required this.name});

  final int id;
  final String name;

  factory UserList.fromJson(Map<String, dynamic> json) {
    return UserList(
      id: (json['id_user_list'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}
