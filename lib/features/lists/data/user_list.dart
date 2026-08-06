class UserList {
  const UserList({
    required this.id,
    required this.name,
    this.seriesCount = 0,
    this.moviesCount = 0,
    this.preview = const [],
  });

  final int id;
  final String name;
  final int seriesCount;
  final int moviesCount;

  /// up to Lists\Index's own PREVIEW_LIMIT poster thumbnails for
  /// ListsScreen's own row - series first (own manual order), topped up
  /// with movies, never the two merged/re-sorted by date - see
  /// Api\Model\UserListMovie::previewForList()'s own docblock on why
  final List<ListPreviewItem> preview;

  factory UserList.fromJson(Map<String, dynamic> json) {
    return UserList(
      id: (json['id_user_list'] as num).toInt(),
      name: json['name'] as String? ?? '',
      seriesCount: (json['series_count'] as num?)?.toInt() ?? 0,
      moviesCount: (json['movies_count'] as num?)?.toInt() ?? 0,
      preview: (json['preview'] as List<dynamic>? ?? [])
          .map((item) => ListPreviewItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ListPreviewItem {
  const ListPreviewItem({required this.tvdbId, this.imageUrl});

  final int tvdbId;
  final String? imageUrl;

  factory ListPreviewItem.fromJson(Map<String, dynamic> json) {
    return ListPreviewItem(
      tvdbId: (json['tvdb_id'] as num).toInt(),
      imageUrl: json['image'] as String?,
    );
  }
}
