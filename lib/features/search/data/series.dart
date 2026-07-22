class Series {
  const Series({required this.tvdbId, required this.name, this.year, this.imageUrl});

  final String tvdbId;
  final String name;
  final String? year;
  final String? imageUrl;

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      tvdbId: json['tvdb_id'] as String,
      name: json['name'] as String? ?? '',
      year: json['year'] as String?,
      imageUrl: (json['thumbnail'] as String?) ?? (json['image_url'] as String?),
    );
  }
}
