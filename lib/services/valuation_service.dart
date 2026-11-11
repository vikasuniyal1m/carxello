import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';

class ValuationService {
  String get _baseUrl => ApiConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getValuation({
    String? vehicleId,
    String? vin,
    String? make,
    String? model,
    int? year,
    int? mileage,
    String? condition,
    String? zipcode,
  }) async {
    final headers = await _getHeaders();
    
    final queryParams = <String, String>{};
    if (vehicleId != null) queryParams['vehicle_id'] = vehicleId;
    if (vin != null) queryParams['vin'] = vin;
    if (make != null) queryParams['make'] = make;
    if (model != null) queryParams['model'] = model;
    if (year != null) queryParams['year'] = year.toString();
    if (mileage != null) queryParams['mileage'] = mileage.toString();
    if (condition != null) queryParams['condition'] = condition;
    if (zipcode != null) queryParams['zipcode'] = zipcode;

    final uri = Uri.parse('$_baseUrl/valuation').replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(uri, headers: headers);
      final decoded = json.decode(response.body);

      if (response.statusCode == 200 && decoded['success'] == true) {
        return decoded['data'];
      } else {
        throw Exception(decoded['error'] ?? 'Failed to load valuation');
      }
    } catch (e) {
      print('❌ ERROR in ValuationService: $e');
      rethrow;
    }
  }
}
