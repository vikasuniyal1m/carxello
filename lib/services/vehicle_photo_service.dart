import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

class VehiclePhotoService {
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

  /// Get vehicle photos
  Future<List<dynamic>> getVehiclePhotos(String vehicleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/vehicles/$vehicleId/photos'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['photos'] as List<dynamic>? ?? [];
      } else {
        throw Exception('Failed to load photos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load photos: $e');
    }
  }

  /// Upload vehicle photo
  Future<Map<String, dynamic>> uploadPhoto({
    required String vehicleId,
    required File imageFile,
    String? caption,
    bool isFeatured = false,
  }) async {
    try {
      print('📤 VehiclePhotoService.uploadPhoto: Preparing upload');
      print('   📍 URL: $_baseUrl/vehicles/$vehicleId/photos');
      print('   📸 File: ${imageFile.path}');
      print('   🏷️ Caption: ${caption ?? "-"} | ⭐ Featured: $isFeatured');
      final headers = await _getHeaders();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/vehicles/$vehicleId/photos'),
      );
      
      // Add headers
      request.headers.addAll(headers);
      
      // Add fields
      if (caption != null) {
        request.fields['photo_caption'] = caption;
      }
      request.fields['is_featured'] = isFeatured.toString();
      
      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          imageFile.path,
          filename: imageFile.path.split('/').last,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final res = json.decode(response.body);
        try {
          final photo = res['photo'] as Map<String, dynamic>? ?? {};
          final relativePath = photo['photo_url']?.toString() ?? '';
          final fetchUrlBase = ApiConfig.imageBaseUrl.endsWith('/')
              ? ApiConfig.imageBaseUrl
              : '${ApiConfig.imageBaseUrl}/';
          final fetchUrl = relativePath.isNotEmpty
              ? '$fetchUrlBase$relativePath'
              : '-';
          print('✅ Upload success');
          print('   🗂️ Saved path (relative): $relativePath');
          print('   🌐 Fetch URL: $fetchUrl');
        } catch (e) {
          print('⚠️ Upload parsed but logging failed: $e');
        }
        return res;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to upload photo');
      }
    } catch (e) {
      throw Exception('Failed to upload photo: $e');
    }
  }

  /// Update photo (set as featured, update caption)
  Future<Map<String, dynamic>> updatePhoto({
    required String photoId,
    String? caption,
    bool? isFeatured,
  }) async {
    try {
      final headers = await _getHeaders(includeContentType: true);
      final body = <String, dynamic>{};
      
      if (caption != null) {
        body['photo_caption'] = caption;
      }
      if (isFeatured != null) {
        body['is_featured'] = isFeatured;
      }
      
      final response = await http.put(
        Uri.parse('$_baseUrl/vehicle-photos/$photoId'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to update photo');
      }
    } catch (e) {
      throw Exception('Failed to update photo: $e');
    }
  }

  /// Delete photo
  Future<void> deletePhoto(String photoId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/vehicle-photos/$photoId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to delete photo');
      }
    } catch (e) {
      throw Exception('Failed to delete photo: $e');
    }
  }
}

