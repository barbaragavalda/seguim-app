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
  });

  final int showsSynced;
  final int showsFailed;
  // shows whose tv_show_id no longer resolved on TheTVDB at all and whose
  // name search (Api\Model\TvTimeImport\SeriesMatcher) couldn't confidently
  // resolve one either - waiting in Api\Model\SeriesImportPending for the
  // user to pick the right one by hand (see PendingResolutionScreen)
  final int showsPending;
  final int episodesWatched;
  final int listsCreated;
  final int moviesSynced;
  // titles Api\Model\TvTimeImport\MovieMatcher couldn't confidently resolve
  // on its own - waiting in Api\Model\MovieImportPending for the user to
  // pick the right one by hand (see PendingResolutionScreen)
  final int moviesPending;

  factory TvTimeImportSummary.fromJson(Map<String, dynamic> json) {
    return TvTimeImportSummary(
      showsSynced: (json['shows_synced'] as num?)?.toInt() ?? 0,
      showsFailed: (json['shows_failed'] as List<dynamic>?)?.length ?? 0,
      showsPending: (json['shows_pending'] as num?)?.toInt() ?? 0,
      episodesWatched: (json['episodes_watched'] as num?)?.toInt() ?? 0,
      listsCreated: (json['lists_created'] as num?)?.toInt() ?? 0,
      moviesSynced: (json['movies_synced'] as num?)?.toInt() ?? 0,
      moviesPending: (json['movies_pending'] as num?)?.toInt() ?? 0,
    );
  }
}

class TvTimeImportStatus {
  const TvTimeImportStatus({
    required this.status,
    this.summary,
    this.errorMessage,
  });

  // "pending" | "processing" | "done" | "failed"
  final String status;
  final TvTimeImportSummary? summary;
  final String? errorMessage;

  factory TvTimeImportStatus.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>?;
    return TvTimeImportStatus(
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
    final body = await streamed.stream.bytesToString();
    final data = _decode(body);
    return (data['id'] as num).toInt();
  }

  Future<TvTimeImportStatus> getStatus(int id, {required String token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/import/tvtime/$id'),
      headers: apiHeaders(token),
    );
    return TvTimeImportStatus.fromJson(_decode(response.body));
  }

  Map<String, dynamic> _decode(String body) {
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(body);
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
