import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:wareeny/shared/emergency/emergency_contact.dart';

typedef SessionTokenProvider = Future<String?> Function();

class EmergencyApiClient {
  EmergencyApiClient({required String apiBaseUrl, required http.Client client})
    : _baseUri = Uri.parse(apiBaseUrl),
      _client = client;

  final Uri _baseUri;
  final http.Client _client;
  SessionTokenProvider? _tokenProvider;

  void setTokenProvider(SessionTokenProvider? provider) {
    _tokenProvider = provider;
  }

  Future<void> bootstrap() => _send('POST', '/api/v1/users/bootstrap');

  Future<void> saveContact(EmergencyContact contact) {
    return _send('PUT', '/api/v1/me/emergency-contact', body: contact.toJson());
  }

  Future<EmergencyContact?> getContact() async {
    final response = await _request('GET', '/api/v1/me/emergency-contact');
    if (response == null || response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EmergencyApiException(response.statusCode);
    }
    return EmergencyContact.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteContact() {
    return _send('DELETE', '/api/v1/me/emergency-contact');
  }

  Future<void> uploadEvent(Map<String, dynamic> event) {
    return _send('POST', '/api/v1/me/emergency-events', body: event);
  }

  Future<void> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _request(method, path, body: body);
    if (response == null) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EmergencyApiException(response.statusCode);
    }
  }

  Future<http.Response?> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _tokenProvider?.call();
    if (token == null || token.isEmpty) return null;

    final request = http.Request(method, _baseUri.resolve(path))
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Content-Type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);

    return http.Response.fromStream(await _client.send(request));
  }
}

class EmergencyApiException implements Exception {
  const EmergencyApiException(this.statusCode);

  final int statusCode;
}
