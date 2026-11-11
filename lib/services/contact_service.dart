import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

class ContactService {
  String get _baseUrl => ApiConfig.baseUrl;

  Future<Map<String, dynamic>> sendContactForm({
    required String firstName,
    required String lastName,
    required String email,
    String? phone,
    required String subject,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/contact'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'phone': phone,
          'subject': subject,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to send contact form: $e');
    }
  }
}

