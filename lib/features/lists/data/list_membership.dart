class ListMembership {
  const ListMembership({
    required this.id,
    required this.name,
    required this.inList,
  });

  final int id;
  final String name;
  final bool inList;

  factory ListMembership.fromJson(Map<String, dynamic> json) {
    return ListMembership(
      id: (json['id_user_list'] as num).toInt(),
      name: json['name'] as String? ?? '',
      inList: json['in_list'] as bool? ?? false,
    );
  }

  ListMembership copyWith({bool? inList}) {
    return ListMembership(
      id: id,
      name: name,
      inList: inList ?? this.inList,
    );
  }
}
