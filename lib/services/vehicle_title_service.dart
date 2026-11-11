import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

class VehicleTitleService {
  String get _baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders({bool includeContentType = false}) async {
    final token = await _authService.getToken();
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  /// Get vehicle title
  Future<Map<String, dynamic>> getVehicleTitle(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/$vehicleId/title'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['title'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load title: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load title: $e');
    }
  }

  /// Create vehicle title
  Future<Map<String, dynamic>> createTitle({
    required String vehicleId,
    required String titleNumber,
    String? titleState,
    String? issueDate,
    required String titleStatus, // clean, salvage, rebuilt, flood
    String? lienHolder,
    double? lienAmount,
    File? titleFile,
  }) async {
    try {
      final headers = await _getHeaders();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/vehicle-titles'),
      );
      
      // Add headers
      request.headers.addAll(headers);
      
      // Add fields
      request.fields['vehicle_id'] = vehicleId;
      request.fields['title_number'] = titleNumber;
      request.fields['title_status'] = titleStatus;
      if (titleState != null) {
        request.fields['title_state'] = titleState;
      }
      if (issueDate != null) {
        request.fields['issue_date'] = issueDate;
      }
      if (lienHolder != null) {
        request.fields['lien_holder'] = lienHolder;
      }
      if (lienAmount != null) {
        request.fields['lien_amount'] = lienAmount.toString();
      }
      
      // Add file if provided
      if (titleFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            titleFile.path,
            filename: titleFile.path.split('/').last,
            contentType: MediaType('application', 'pdf'),
          ),
        );
      }
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to create title');
      }
    } catch (e) {
      throw Exception('Failed to create title: $e');
    }
  }

  /// Update vehicle title (admin only)
  Future<Map<String, dynamic>> updateTitle({
    required String titleId,
    String? titleStatus,
    String? status, // available, processing, transferred, lost
    String? lienHolder,
    double? lienAmount,
  }) async {
    try {
      final headers = await _getHeaders(includeContentType: true);
      final body = <String, dynamic>{};
      
      if (titleStatus != null) {
        body['title_status'] = titleStatus;
      }
      if (status != null) {
        body['status'] = status;
      }
      if (lienHolder != null) {
        body['lien_holder'] = lienHolder;
      }
      if (lienAmount != null) {
        body['lien_amount'] = lienAmount;
      }
      
      final response = await http.put(
        Uri.parse('$_baseUrl/vehicle-titles/$titleId'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to update title');
      }
    } catch (e) {
      throw Exception('Failed to update title: $e');
    }
  }
}

