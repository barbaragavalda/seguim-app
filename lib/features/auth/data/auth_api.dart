import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _authRequest('/api/register', {
      'name': name,
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
    final data = _decode(response.body);
    final error = data['error'];
    if (error != false) {
      throw AuthException(error is String ? error : 'unknown_error');
    }
    return data['token'] as String;
  }

  Map<String, dynamic> _decode(String body) {
    // The dev backend prepends PHP debug/warning noise before the JSON
    // payload (a known missing appacman_app_config table) — the response
    // is otherwise never valid JSON from position 0, so take the last `{`.
    final jsonStart = body.lastIndexOf('{');
    if (jsonStart == -1) {
      throw const AuthException('unknown_error');
    }
    return jsonDecode(body.substring(jsonStart)) as Map<String, dynamic>;
  }
}
