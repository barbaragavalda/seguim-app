class WatchlistItem {
  const WatchlistItem({
    required this.tvdbId,
    required this.name,
    this.imageUrl,
    this.nextEpisodeCode,
    this.nextEpisodeName,
    this.nextEpisodeTvdbId,
    required this.remainingEpisodes,
    this.premiereInDays,
  });

  final String tvdbId;
  final String name;
  final String? imageUrl;
  // raw "T{season} - E{episode}" from the API - see [episodeCode]
  final String? nextEpisodeCode;
  final String? nextEpisodeName;
  // lets the watchlist row mark this one episode watched directly - null
  // exactly when nextEpisodeCode is (nothing left to mark)
  final String? nextEpisodeTvdbId;
  final int remainingEpisodes;
  // only ever set when nextEpisodeCode is null (a not-started series with
  // nothing aired yet)
  final int? premiereInDays;

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
      // this landscape row always wants the fanart, not the poster
      imageUrl: json['background'] as String?,
      nextEpisodeCode: json['next_episode'] as String?,
      nextEpisodeName: json['next_episode_name'] as String?,
      nextEpisodeTvdbId: json['next_episode_tvdb_id'] == null
          ? null
          : '${json['next_episode_tvdb_id']}',
      remainingEpisodes: (json['remaining_episodes'] as num?)?.toInt() ?? 0,
      premiereInDays: (json['premiere_in_days'] as num?)?.toInt(),
    );
  }
}
