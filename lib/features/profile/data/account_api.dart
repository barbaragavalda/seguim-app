import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';

class AccountException implements Exception {
  const AccountException(this.message);

  final String message;
}

class AccountInfo {
  const AccountInfo({
    required this.username,
    required this.email,
    required this.language,
    required this.stats,
  });

  final String username;
  final String email;
  final String? language;
  final AccountStats stats;
}

class AccountStats {
  const AccountStats({
    required this.episodesWatched,
    required this.seriesAdded,
    required this.moviesWatched,
    required this.moviesAdded,
  });

  final int episodesWatched;
  final int seriesAdded;
  final int moviesWatched;
  final int moviesAdded;

  factory AccountStats.fromJson(Map<String, dynamic> json) {
    return AccountStats(
      episodesWatched: (json['episodes_watched'] as num?)?.toInt() ?? 0,
      seriesAdded: (json['series_added'] as num?)?.toInt() ?? 0,
      moviesWatched: (json['movies_watched'] as num?)?.toInt() ?? 0,
      moviesAdded: (json['movies_added'] as num?)?.toInt() ?? 0,
    );
  }
}

class AccountApi {
  AccountApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AccountInfo> getAccount({required String token}) async {
    final data = await _request(
      'GET',
      '/api/account',
      token: token,
    );
    return AccountInfo(
      username: data['username'] as String? ?? '',
      email: data['email'] as String? ?? '',
      language: data['language'] as String?,
      stats: AccountStats.fromJson(
        data['stats'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Future<String> updateUsername(String username, {required String token}) async {
    final data = await _request(
      'POST',
      '/api/account/username',
      token: token,
      body: {'username': username},
    );
    return data['username'] as String;
  }

  /// Only requests the change - it takes effect once confirmed with the
  /// code sent to the new address, so a stolen token can't silently
  /// hijack the account.
  Future<void> requestEmailChange(String email, {required String token}) {
    return _request(
      'POST',
      '/api/account/email',
      token: token,
      body: {'email': email},
    );
  }

  Future<String> confirmEmailChange(String code, {required String token}) async {
    final data = await _request(
      'POST',
      '/api/account/email/confirm',
      token: token,
      body: {'code': code},
    );
    return data['email'] as String;
  }

  Future<String> updateLanguage(String language, {required String token}) async {
    final data = await _request(
      'POST',
      '/api/account/language',
      token: token,
      body: {'language': language},
    );
    return data['language'] as String;
  }

  /// Password changes revoke every device's token server-side, so the
  /// caller must persist the returned token or the session goes stale.
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String token,
  }) async {
    final data = await _request(
      'POST',
      '/api/account/password',
      token: token,
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
    return data['token'] as String;
  }

  Future<void> deleteAccount({required String token}) {
    return _request('DELETE', '/api/account', token: token);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    required String token,
    Map<String, String>? body,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = apiHeaders(token);
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers)
        : method == 'DELETE'
        ? await _client.delete(uri, headers: headers)
        : await _client.post(uri, headers: headers, body: body);

    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(response);
    } on FormatException {
      throw const AccountException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw AccountException(error is String ? error : 'unknown_error');
    }
    return data;
  }
}
