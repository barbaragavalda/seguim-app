class WatchlistItem {
  const WatchlistItem({
    required this.tvdbId,
    required this.name,
    this.imageUrl,
    this.nextEpisodeCode,
    this.nextEpisodeName,
    required this.remainingEpisodes,
  });

  final String tvdbId;
  final String name;
  final String? imageUrl;
  // raw "T{season} - E{episode}" from the API - see [episodeCode]
  final String? nextEpisodeCode;
  final String? nextEpisodeName;
  final int remainingEpisodes;

  /// [nextEpisodeCode] reformatted to match the "1x03" style used elsewhere
  /// in the app (series detail's episode rows), or null if caught up.
  String? get episodeCode {
    final raw = nextEpisodeCode;
    if (raw == null) return null;
    final match = RegExp(r'T(\d+)\s*-\s*E(\d+)').firstMatch(raw);
    if (match == null) return raw;
    final episode = match.group(2)!.padLeft(2, '0');
    return '${match.group(1)}x$episode';
  }

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      tvdbId: '${json['tvdb_id']}',
      name: json['name'] as String? ?? '',
      imageUrl: json['image'] as String?,
      nextEpisodeCode: json['next_episode'] as String?,
      nextEpisodeName: json['next_episode_name'] as String?,
      remainingEpisodes: (json['remaining_episodes'] as num?)?.toInt() ?? 0,
    );
  }
}
