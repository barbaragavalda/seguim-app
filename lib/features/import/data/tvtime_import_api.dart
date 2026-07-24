import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_response_parser.dart';

class TvTimeImportException implements Exception {
  const TvTimeImportException(this.message);

  final String message;
}

class TvTimeImportSummary {
  const TvTimeImportSummary({
    required this.showsSynced,
    required this.showsFailed,
    required this.episodesWatched,
  });

  final int showsSynced;
  final int showsFailed;
  final int episodesWatched;

  factory TvTimeImportSummary.fromJson(Map<String, dynamic> json) {
    return TvTimeImportSummary(
      showsSynced: (json['shows_synced'] as num?)?.toInt() ?? 0,
      showsFailed: (json['shows_failed'] as List<dynamic>?)?.length ?? 0,
      episodesWatched: (json['episodes_watched'] as num?)?.toInt() ?? 0,
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
    request.headers['Authorization'] = token;
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
      headers: {'Authorization': token},
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
