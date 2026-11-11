import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

class NewsletterService {
  String get _baseUrl => ApiConfig.baseUrl;

  Future<Map<String, dynamic>> subscribe(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/newsletter/subscribe'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to subscribe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to subscribe: $e');
    }
  }

  Future<Map<String, dynamic>> unsubscribe(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/newsletter/unsubscribe'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to unsubscribe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to unsubscribe: $e');
    }
  }

  Future<Map<String, dynamic>> checkStatus(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/newsletter/status?email=$email'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to check status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to check newsletter status: $e');
    }
  }
}

