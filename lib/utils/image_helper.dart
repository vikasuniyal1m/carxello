import 'package:carauction/utils/api_config.dart';

/// Utility class for handling image URLs
/// Images are saved and fetched from same folder (API server uploads/vehicles)
class ImageHelper {
  /// Base URL for images - same server as API so save & fetch use same folder
  static String get _baseUrl {
    final b = ApiConfig.imageBaseUrl;
    return b.endsWith('/') ? b : '$b/';
  }

  /// Normalize and encode image URL
  /// Handles:
  /// - Relative paths (uploads/vehicles/...) → API server base URL
  /// - Full URLs (http://, https://) → as is
  /// - Asset paths (assets/...) → as is
  static String normalizeImageUrl(String url) {
    if (url.isEmpty) {
      return 'assets/images/car1.png';
    }

    if (url.startsWith('assets/')) {
      return url;
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      final base = ApiConfig.imageBaseUrl;
      String adjusted = url;
      if (url.contains('assets/uploads/')) {
        try {
          final uri = Uri.parse(url);
          final path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
          final targetBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
          adjusted = '$targetBase/$path';
        } catch (_) {}
      }
      final encoded = _encodeUrlPath(adjusted);
      // ignore: avoid_print
      print('🖼️ Fetch image: $encoded');
      return encoded;
    }

    if (url.startsWith('/')) {
      final cleanPath = url.substring(1);
      final resolved = _encodeUrlPath('$_baseUrl$cleanPath');
      // ignore: avoid_print
      print('🖼️ Fetch image: $resolved');
      return resolved;
    }

    if (url.contains('uploads/') || url.contains('assets/')) {
      final cleanPath = url.startsWith('/') ? url.substring(1) : url;
      final resolved = _encodeUrlPath('$_baseUrl$cleanPath');
      // ignore: avoid_print
      print('🖼️ Fetch image: $resolved');
      return resolved;
    }

    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    final resolved = _encodeUrlPath('$_baseUrl$cleanPath');
    // ignore: avoid_print
    print('🖼️ Fetch image: $resolved');
    return resolved;
  }

  /// Encode URL path components (especially filenames with spaces)
  /// This ensures that spaces and special characters in filenames are properly encoded
  static String _encodeUrlPath(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Split the path into segments
      final pathSegments = uri.pathSegments;
      
      // Encode each segment (especially the filename which may contain spaces)
      final encodedSegments = pathSegments.map((segment) {
        // Always encode segments that contain spaces or special characters
        // This handles filenames like "1762938755_13-inspector portal Completed.png"
        if (segment.contains(' ') || 
            segment.contains('+') || 
            segment.contains('&') || 
            segment.contains('=') ||
            segment.contains('#') ||
            segment.contains('?')) {
          return Uri.encodeComponent(segment);
        }
        // If already encoded, return as is
        if (segment.contains('%')) {
          return segment;
        }
        return segment;
      }).toList();
      
      // Reconstruct the URI with encoded path
      final encodedPath = '/' + encodedSegments.join('/');
      
      // Reconstruct the full URL with query parameters and fragment if they exist
      final newUri = uri.replace(path: encodedPath);
      return newUri.toString();
    } catch (e) {
      // If parsing fails, try manual encoding
      try {
        // Split URL into parts
        final uriMatch = RegExp(r'^(https?://[^/]+)(/.*)$').firstMatch(url);
        if (uriMatch != null) {
          final base = uriMatch.group(1)!;
          final path = uriMatch.group(2)!;
          
          // Split path and encode each segment
          final pathParts = path.split('/');
          final encodedParts = pathParts.map((part) {
            if (part.isNotEmpty && part.contains(' ')) {
              return Uri.encodeComponent(part);
            }
            return part;
          }).toList();
          
          return base + encodedParts.join('/');
        }
        // If regex fails, return original
        return url;
      } catch (e2) {
        // If all else fails, return original URL
        return url;
      }
    }
  }

  /// Check if URL is a network URL
  static bool isNetworkUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Check if URL is an asset path
  static bool isAssetPath(String url) {
    return url.startsWith('assets/');
  }
}
