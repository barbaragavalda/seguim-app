import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_response_parser.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> register({
    required String username,
    required String email,
    required String password,
  }) {
    return _authRequest('/api/register', {
      'username': username,
      'email': email,
      'password': password,
    });
  }

  Future<String> login({required String email, required String password}) {
    return _authRequest('/api/login', {'email': email, 'password': password});
  }

  Future<void> logout(String token) async {
    await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/logout'),
      headers: {'Authorization': token},
    );
  }

  Future<String> _authRequest(String path, Map<String, String> body) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {'Authorization': ApiConfig.defaultToken},
      body: body,
    );
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(response.body);
    } on FormatException {
      throw const AuthException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw AuthException(error is String ? error : 'unknown_error');
    }
    return data['token'] as String;
  }
}
