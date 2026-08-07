import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';

class TvTimeImportException implements Exception {
  const TvTimeImportException(this.message);

  final String message;
}

class TvTimeImportSummary {
  const TvTimeImportSummary({
    required this.showsSynced,
    required this.showsFailed,
    required this.showsPending,
    required this.episodesWatched,
    required this.listsCreated,
    required this.moviesSynced,
    required this.moviesPending,
    required this.showsTotal,
    required this.moviesTotal,
  });

  final int showsSynced;
  final int showsFailed;
  // waiting for the user to resolve by hand (see PendingResolutionScreen)
  final int showsPending;
  final int episodesWatched;
  final int listsCreated;
  final int moviesSynced;
  // waiting for the user to resolve by hand (see PendingResolutionScreen)
  final int moviesPending;
  // export's fixed totals, not accumulated like the rest of this class -
  // lets ProcessingView show a real progress fraction instead of a spinner
  final int showsTotal;
  final int moviesTotal;

  factory TvTimeImportSummary.fromJson(Map<String, dynamic> json) {
    return TvTimeImportSummary(
      showsSynced: (json['shows_synced'] as num?)?.toInt() ?? 0,
      showsFailed: (json['shows_failed'] as List<dynamic>?)?.length ?? 0,
      showsPending: (json['shows_pending'] as num?)?.toInt() ?? 0,
      episodesWatched: (json['episodes_watched'] as num?)?.toInt() ?? 0,
      listsCreated: (json['lists_created'] as num?)?.toInt() ?? 0,
      moviesSynced: (json['movies_synced'] as num?)?.toInt() ?? 0,
      moviesPending: (json['movies_pending'] as num?)?.toInt() ?? 0,
      showsTotal: (json['shows_total'] as num?)?.toInt() ?? 0,
      moviesTotal: (json['movies_total'] as num?)?.toInt() ?? 0,
    );
  }
}

class TvTimeImportStatus {
  const TvTimeImportStatus({
    this.id,
    required this.status,
    this.summary,
    this.errorMessage,
  });

  // only set by getCurrent() - getStatus() already knows the id it asked
  // for, so its own response never bothers echoing it back
  final int? id;
  // "pending" | "processing" | "done" | "failed"
  final String status;
  final TvTimeImportSummary? summary;
  final String? errorMessage;

  factory TvTimeImportStatus.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>?;
    return TvTimeImportStatus(
      id: (json['id'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'pending',
      summary: summaryJson != null
          ? TvTimeImportSummary.fromJson(summaryJson)
          : null,
      errorMessage: json['error_message'] as String?,
    );
  }
}

class TvTimeImportApi {
  TvTimeImportApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<int> upload({
    required List<int> bytes,
    required String filename,
    required String token,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/import/tvtime'),
    );
    request.headers.addAll(apiHeaders(token));
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = _decode(response);
    return (data['id'] as num).toInt();
  }

  Future<TvTimeImportStatus> getStatus(int id, {required String token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/import/tvtime/$id'),
      headers: apiHeaders(token),
    );
    return TvTimeImportStatus.fromJson(_decode(response));
  }

  /// Finds this user's latest not-yet-finished job, letting a fresh app
  /// process recover an import it has no memory of. Null if none to resume.
  Future<TvTimeImportStatus?> getCurrent({required String token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/import/tvtime/current'),
      headers: apiHeaders(token),
    );
    final data = _decode(response);
    if (data['id'] == null) return null;
    return TvTimeImportStatus.fromJson(data);
  }

  Map<String, dynamic> _decode(http.Response response) {
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(response);
    } on FormatException {
      throw const TvTimeImportException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw TvTimeImportException(error is String ? error : 'unknown_error');
    }
    return data;
  }
}
