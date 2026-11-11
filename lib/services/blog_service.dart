import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_service.dart';

class BlogService {
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

  Future<List<Map<String, dynamic>>> getBlogPosts({bool includeDrafts = false}) async {
    try {
      final headers = await _getHeaders();
      String url = '$_baseUrl/blog/posts';
      if (includeDrafts) {
        url += '?include_drafts=true';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['posts']);
      } else {
        throw Exception('Failed to load blog posts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load blog posts: $e');
    }
  }

  Future<Map<String, dynamic>> getBlogPost(String postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/blog/posts/$postId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load blog post: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load blog post: $e');
    }
  }

  Future<Map<String, dynamic>> createBlogPost({
    required String title,
    String? excerpt,
    required String content,
    String? featuredImage,
    String status = 'draft',
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/blog/posts'),
        headers: headers,
        body: json.encode({
          'title': title,
          'excerpt': excerpt,
          'content': content,
          'featured_image': featuredImage,
          'status': status,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to create blog post: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to create blog post: $e');
    }
  }

  Future<Map<String, dynamic>> updateBlogPost(String postId, {
    String? title,
    String? excerpt,
    String? content,
    String? featuredImage,
    String? status,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (excerpt != null) body['excerpt'] = excerpt;
      if (content != null) body['content'] = content;
      if (featuredImage != null) body['featured_image'] = featuredImage;
      if (status != null) body['status'] = status;

      final response = await http.put(
        Uri.parse('$_baseUrl/blog/posts/$postId'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to update blog post: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update blog post: $e');
    }
  }

  Future<void> deleteBlogPost(String postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/blog/posts/$postId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to delete blog post: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete blog post: $e');
    }
  }
}

