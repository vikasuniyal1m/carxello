import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_search.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

class SavedSearchService {
  String get _baseUrl => ApiConfig.baseUrl;
  final AuthService _authService = AuthService();
  static const String _prefsKey = 'saved_searches';

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

  /// Save search to SharedPreferences (local storage)
  Future<void> saveSearchLocally(SavedSearch search) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = await getSavedSearchesLocally();
      
      // Check if search already exists
      final existingIndex = searches.indexWhere((s) => s.id == search.id);
      if (existingIndex >= 0) {
        searches[existingIndex] = search;
      } else {
        searches.add(search);
      }
      
      // Save to SharedPreferences
      final searchesJson = searches.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_prefsKey, searchesJson);
      print('✅ Saved search locally: ${search.searchName}');
    } catch (e) {
      print('❌ Error saving search locally: $e');
      throw Exception('Failed to save search locally: $e');
    }
  }

  /// Get saved searches from SharedPreferences
  Future<List<SavedSearch>> getSavedSearchesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searchesJson = prefs.getStringList(_prefsKey) ?? [];
      
      return searchesJson.map((jsonStr) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return SavedSearch.fromJson(json);
      }).toList();
    } catch (e) {
      print('❌ Error loading saved searches: $e');
      return [];
    }
  }

  /// Delete search from SharedPreferences
  Future<void> deleteSearchLocally(String searchId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = await getSavedSearchesLocally();
      searches.removeWhere((s) => s.id == searchId);
      
      final searchesJson = searches.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_prefsKey, searchesJson);
      print('✅ Deleted search locally: $searchId');
    } catch (e) {
      print('❌ Error deleting search: $e');
      throw Exception('Failed to delete search: $e');
    }
  }

  /// Save search to backend
  Future<void> saveSearchToBackend(SavedSearch search) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/saved-searches'),
        headers: headers,
        body: jsonEncode({
          'search_criteria': search.toJson(),
          'search_name': search.searchName,
          'notification_frequency': search.enableEmailAlerts ? 'immediate' : 'daily',
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Saved search to backend: ${data['search']?['id'] ?? 'success'}');
        // Update local ID if backend returned one
        if (data['search'] != null && data['search']['id'] != null) {
          // Note: SavedSearch model would need to be updated to handle backend ID
        }
      } else if (response.statusCode == 409) {
        // Conflict - search already exists
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'This search is already saved');
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to save search to backend');
      }
    } catch (e) {
      print('⚠️ Backend save failed: $e');
      throw Exception(e.toString());
    }
  }

  /// Get saved searches from backend
  Future<List<SavedSearch>> getSavedSearchesFromBackend() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/saved-searches'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final searches = (data['searches'] as List? ?? [])
            .map((json) {
              try {
                // Convert backend format to SavedSearch model
                final criteria = json['search_criteria'] as Map<String, dynamic>? ?? {};
                return SavedSearch(
                  id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  searchName: json['search_name'] ?? 'Saved Search',
                  make: criteria['make'],
                  model: criteria['model'],
                  yearFrom: criteria['year_from'],
                  yearTo: criteria['year_to'],
                  priceMin: criteria['price_from']?.toDouble() ?? criteria['price_min']?.toDouble(),
                  priceMax: criteria['price_to']?.toDouble() ?? criteria['price_max']?.toDouble(),
                  maxMileage: criteria['mileage_to'] ?? criteria['mileage_max'] ?? criteria['max_mileage'],
                  condition: criteria['condition'],
                  zipCode: criteria['location'] ?? criteria['zip_code'],
                  searchRadius: criteria['search_radius'],
                  enableEmailAlerts: json['notification_frequency'] == 'immediate' || json['notification_frequency'] == 'daily',
                  alertFrequency: json['notification_frequency'] ?? 'Immediate',
                  createdAt: json['created_at'] != null 
                    ? DateTime.parse(json['created_at'])
                    : DateTime.now(),
                  lastMatch: json['last_match']?.toString(),
                  currentMatches: json['current_matches'] ?? 0,
                );
              } catch (e) {
                print('⚠️ Error parsing search: $e');
                return null;
              }
            })
            .whereType<SavedSearch>()
            .toList();
        print('✅ Fetched ${searches.length} searches from backend');
        return searches;
      } else {
        throw Exception('Failed to fetch searches: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Backend fetch failed: $e');
      return [];
    }
  }

  /// Save search (both local and backend)
  Future<void> saveSearch(SavedSearch search) async {
    try {
      // Try backend first (primary storage)
      await saveSearchToBackend(search);
      // Also save locally as backup
      await saveSearchLocally(search);
    } catch (e) {
      // If backend fails, save locally only
      print('⚠️ Backend save failed, saving locally only: $e');
      await saveSearchLocally(search);
      rethrow; // Re-throw to notify caller
    }
  }

  /// Get all saved searches (try backend first, fallback to local)
  Future<List<SavedSearch>> getSavedSearches() async {
    try {
      // Try backend first (primary source)
      final backendSearches = await getSavedSearchesFromBackend();
      if (backendSearches.isNotEmpty) {
        // Sync to local as backup
        final prefs = await SharedPreferences.getInstance();
        final searchesJson = backendSearches.map((s) => jsonEncode(s.toJson())).toList();
        await prefs.setStringList(_prefsKey, searchesJson);
        return backendSearches;
      }
      // If backend returns empty, try local
      final localSearches = await getSavedSearchesLocally();
      if (localSearches.isNotEmpty) {
        // Try to sync local to backend
        for (var search in localSearches) {
          try {
            await saveSearchToBackend(search);
          } catch (e) {
            print('⚠️ Failed to sync local search to backend: $e');
          }
        }
        return localSearches;
      }
      return [];
    } catch (e) {
      print('⚠️ Backend fetch failed, using local: $e');
      // Fallback to local
      return await getSavedSearchesLocally();
    }
  }

  /// Delete search (both local and backend)
  Future<void> deleteSearch(String searchId) async {
    try {
      // Try backend first
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/saved-searches/$searchId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        print('✅ Deleted search from backend: $searchId');
      } else {
        throw Exception('Failed to delete from backend: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Backend delete failed: $e');
      // Still delete locally
    }
    // Always delete locally as well
    await deleteSearchLocally(searchId);
  }
}

