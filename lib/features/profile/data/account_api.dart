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
  });

  final String username;
  final String email;
  final String? language;
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

  /// Only *requests* the change - it doesn't take effect until confirmed
  /// with the code this sends to the new address (see confirmEmailChange
  /// below), so a stolen/shared-device session token can't silently
  /// hijack the account (see Api\Controller\Account\UpdateEmail).
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

  /// Returns the freshly-issued token for this session - the backend
  /// revokes every device's token on a password change (see
  /// Webservice\Controller\ChangePassword), so the caller must swap its
  /// stored token for this one or the current session goes stale.
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
      data = decodeApiResponse(response.body);
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
