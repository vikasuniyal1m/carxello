import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

class InspectionService {
  String get _baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/inspections/dashboard'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Try to parse error message from response
        String errorMessage = 'Failed to load dashboard: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) {
            errorMessage = errorData['error'].toString();
          } else if (errorData['message'] != null) {
            errorMessage = errorData['message'].toString();
          }
        } catch (e) {
          // If can't parse error, use status code
          errorMessage = 'Failed to load dashboard: ${response.statusCode} - ${response.body}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e.toString().contains('Failed to load dashboard')) {
        rethrow;
      }
      throw Exception('Failed to load dashboard: $e');
    }
  }

  Future<List<dynamic>> getAssignedInspections() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/inspections/assigned'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['inspections'] as List<dynamic>;
      } else {
        throw Exception('Failed to load inspections: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load inspections: $e');
    }
  }

  Future<List<dynamic>> getCompletedInspections() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/inspections/completed'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['inspections'] as List<dynamic>;
      } else {
        throw Exception('Failed to load completed inspections: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load completed inspections: $e');
    }
  }

  Future<Map<String, dynamic>> submitReport({
    required String inspectionId,
    required int vehicleGrade,
    required bool vinVerified,
    required Map<String, bool> documentsStatus,
    String? notes,
    List<String>? photoUrls,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/inspections/$inspectionId/report'),
        headers: headers,
        body: json.encode({
          'vehicle_grade': vehicleGrade,
          'vin_verified': vinVerified,
          'documents_status': documentsStatus,
          'notes': notes,
          'photo_urls': photoUrls ?? [],
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to submit report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  Future<List<dynamic>> getSellerPendingRequests() async {
    try {
      print('🔍 InspectionService.getSellerPendingRequests: Starting...');
      final headers = await _getHeaders();
      print('📍 URL: $_baseUrl/inspections/seller/pending');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/inspections/seller/pending'),
        headers: headers,
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final inspections = data['inspections'] as List<dynamic>? ?? [];
        print('✅ Successfully fetched ${inspections.length} pending inspection requests');
        return inspections;
      } else {
        final errorBody = json.decode(response.body);
        final errorMsg = errorBody['error'] ?? 'Failed to load pending inspection requests: ${response.statusCode}';
        print('❌ Error: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('❌ InspectionService.getSellerPendingRequests Error: $e');
      throw Exception('Failed to load pending inspection requests: $e');
    }
  }

  Future<Map<String, dynamic>> sellerAcceptRequest(String inspectionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/inspections/$inspectionId/seller/accept'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to accept inspection request');
      }
    } catch (e) {
      throw Exception('Failed to accept inspection request: $e');
    }
  }

  Future<Map<String, dynamic>> sellerRejectRequest(String inspectionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/inspections/$inspectionId/seller/reject'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to reject inspection request');
      }
    } catch (e) {
      throw Exception('Failed to reject inspection request: $e');
    }
  }

  Future<Map<String, dynamic>> claimInspection(String inspectionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/inspections/$inspectionId/claim'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to claim inspection: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to claim inspection: $e');
    }
  }

  Future<Map<String, dynamic>> startInspection(String inspectionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/inspections/$inspectionId/start'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to start inspection: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to start inspection: $e');
    }
  }

  Future<Map<String, dynamic>> createRequest({
    required String vehicleId,
    String? scheduledDate,
    String? location,
    String? priority,
    String? notes,
    String? inspectorId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/inspections/request'),
        headers: headers,
        body: json.encode({
          'vehicle_id': vehicleId,
          'scheduled_date': scheduledDate,
          'location': location,
          'priority': priority,
          'notes': notes,
          'inspector_id': inspectorId,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        try {
          final errorBody = json.decode(response.body);
          
          // Handle validation errors (422 status)
          if (response.statusCode == 422 && errorBody['errors'] != null) {
            final errors = errorBody['errors'] as Map<String, dynamic>;
            final errorMessages = <String>[];
            
            errors.forEach((field, messages) {
              if (messages is List) {
                for (var message in messages) {
                  errorMessages.add('${field.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')}: $message');
                }
              } else {
                errorMessages.add('${field.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')}: $messages');
              }
            });
            
            throw Exception(errorMessages.join('\n'));
          }
          
          // Handle other error formats
          if (errorBody['error'] != null) {
            throw Exception(errorBody['error']);
          }
          
          if (errorBody['message'] != null) {
            throw Exception(errorBody['message']);
          }
          
          throw Exception('Failed to create inspection request: ${response.statusCode}');
        } catch (e) {
          if (e is Exception) {
            rethrow;
          }
          throw Exception('Failed to create inspection request: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      // Don't double-wrap if it's already an Exception with a message
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to create inspection request: $e');
    }
  }

  Future<Map<String, String>> _getHeadersForMultipart() async {
    final token = await _authService.getToken();
    final headers = <String, String>{};
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  /// Get detailed inspection information by inspection ID (with track record)
  Future<Map<String, dynamic>> getInspectionDetails(String inspectionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/inspections/$inspectionId/details'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to get inspection details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get inspection details: $e');
    }
  }

  /// Get inspection details for a specific vehicle
  Future<Map<String, dynamic>> getVehicleInspection(String vehicleId) async {
    try {
      print('🌐 getVehicleInspection - Calling API for vehicle: $vehicleId');
      final headers = await _getHeaders();
      final url = '$_baseUrl/inspections/vehicle/$vehicleId';
      print('🌐 getVehicleInspection - URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('🌐 getVehicleInspection - Response status: ${response.statusCode}');
      print('🌐 getVehicleInspection - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        print('🌐 getVehicleInspection - Decoded response: $decoded');
        return decoded;
      } else {
        final errorBody = response.body;
        print('❌ getVehicleInspection - Error response: $errorBody');
        throw Exception('Failed to get inspection details: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      print('❌ getVehicleInspection - Exception: $e');
      throw Exception('Failed to get inspection details: $e');
    }
  }

  Future<Map<String, dynamic>> submitDetailedReport({
    required String inspectionId,
    required String overallGrade,
    required String summary,
    String? recommendations,
    required Map<String, dynamic> inspectionData,
    List<File>? photos,
  }) async {
    try {
      final headers = await _getHeadersForMultipart();
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/inspections/$inspectionId/detailed-report'),
      );
      
      // Add headers
      request.headers.addAll(headers);
      
      // Add form fields
      request.fields['overall_grade'] = overallGrade;
      request.fields['summary'] = summary;
      if (recommendations != null && recommendations.isNotEmpty) {
        request.fields['recommendations'] = recommendations;
      }
      request.fields['inspection_data'] = json.encode(inspectionData);
      
      // Add photos
      if (photos != null && photos.isNotEmpty) {
        for (var photo in photos) {
          final file = await http.MultipartFile.fromPath(
            'inspection_photos[]',
            photo.path,
            filename: photo.path.split('/').last,
            contentType: MediaType('image', 'jpeg'),
          );
          request.files.add(file);
        }
      }
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to submit detailed report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to submit detailed report: $e');
    }
  }
}

