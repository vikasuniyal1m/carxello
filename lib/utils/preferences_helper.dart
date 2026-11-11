import 'package:shared_preferences/shared_preferences.dart';

/// Helper class for managing SharedPreferences across the app
class PreferencesHelper {
  // Keys
  static const String _keyUserRole = 'user_role';
  /// When [user_role] is `seller/buyer`, stores which mode is active: `buyer` or `seller`.
  static const String _keyBuyerSellerMode = 'buyer_seller_mode';
  static const String _keyUserId = 'user_id';
  static const String _keyBuyerId = 'buyer_id';
  static const String _keySellerId = 'seller_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyToken = 'token';

  /// Same key as [AuthService] token storage — use for services that must not depend on AuthService timing.
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await _getSafePreferences();
      return prefs?.getString(_keyToken);
    } catch (e) {
      print('⚠️ PreferencesHelper.getAuthToken: $e');
      return null;
    }
  }
  static const String _keyLastSortBy = 'last_sort_by';
  static const String _keyLastFilterSettings = 'last_filter_settings';
  static const String _keyScrollPosition = 'scroll_position_';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLanguage = 'language';
  static const String _keyNotificationEnabled = 'notification_enabled';

  /// Safe wrapper to get SharedPreferences instance with error handling
  static Future<SharedPreferences?> _getSafePreferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      print('⚠️ PreferencesHelper: SharedPreferences error: $e');
      return null;
    }
  }

  // User Preferences
  static Future<void> saveUserRole(String role) async {
    try {
      final prefs = await _getSafePreferences();
      if (prefs != null) {
        await prefs.setString(_keyUserRole, role);
      }
    } catch (e) {
      print('⚠️ PreferencesHelper.saveUserRole: Error: $e');
    }
  }

  static Future<String?> getUserRole() async {
    try {
      final prefs = await _getSafePreferences();
      return prefs?.getString(_keyUserRole);
    } catch (e) {
      print('⚠️ PreferencesHelper.getUserRole: Error: $e');
      return null;
    }
  }

  /// Persists Buyer vs Seller toggle for accounts with role `seller/buyer`.
  static Future<void> saveBuyerSellerMode(String mode) async {
    try {
      final m = mode.toLowerCase().trim();
      if (m != 'buyer' && m != 'seller') return;
      final prefs = await _getSafePreferences();
      if (prefs != null) {
        await prefs.setString(_keyBuyerSellerMode, m);
      }
    } catch (e) {
      print('⚠️ PreferencesHelper.saveBuyerSellerMode: Error: $e');
    }
  }

  static Future<String?> getBuyerSellerMode() async {
    try {
      final prefs = await _getSafePreferences();
      return prefs?.getString(_keyBuyerSellerMode);
    } catch (e) {
      print('⚠️ PreferencesHelper.getBuyerSellerMode: Error: $e');
      return null;
    }
  }

  /// Role for API/UI: if account is `seller/buyer`, returns `buyer` or `seller` based on toggle; else raw role.
  static Future<String> getEffectiveRoleForNotifications() async {
    final raw = (await getUserRole())?.toLowerCase().trim() ?? '';
    if (raw == 'seller/buyer') {
      final mode = (await getBuyerSellerMode())?.toLowerCase().trim();
      if (mode == 'seller') return 'seller';
      return 'buyer';
    }
    return raw;
  }

  static Future<void> saveUserId(String userId) async {
    try {
      final prefs = await _getSafePreferences();
      if (prefs != null) {
        await prefs.setString(_keyUserId, userId);
      }
    } catch (e) {
      print('⚠️ PreferencesHelper.saveUserId: Error: $e');
    }
  }

  static Future<String?> getUserId() async {
    try {
      final prefs = await _getSafePreferences();
      return prefs?.getString(_keyUserId);
    } catch (e) {
      print('⚠️ PreferencesHelper.getUserId: Error: $e');
      return null;
    }
  }

  // Role-based IDs
  static Future<void> saveBuyerId(String buyerId) async {
    try {
      final prefs = await _getSafePreferences();
      if (prefs != null) {
        await prefs.setString(_keyBuyerId, buyerId);
      }
    } catch (e) {
      print('⚠️ PreferencesHelper.saveBuyerId: Error: $e');
    }
  }

  static Future<String?> getBuyerId() async {
    try {
      final prefs = await _getSafePreferences();
      return prefs?.getString(_keyBuyerId);
    } catch (e) {
      print('⚠️ PreferencesHelper.getBuyerId: Error: $e');
      return null;
    }
  }

  static Future<void> saveSellerId(String sellerId) async {
    try {
      final prefs = await _getSafePreferences();
      if (prefs != null) {
        await prefs.setString(_keySellerId, sellerId);
      }
    } catch (e) {
      print('⚠️ PreferencesHelper.saveSellerId: Error: $e');
    }
  }

  static Future<String?> getSellerId() async {
    try {
      final prefs = await _getSafePreferences();
      return prefs?.getString(_keySellerId);
    } catch (e) {
      print('⚠️ PreferencesHelper.getSellerId: Error: $e');
      return null;
    }
  }

  // Filter & Sort Settings
  static Future<void> saveLastSortBy(String sortBy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSortBy, sortBy);
  }

  static Future<String?> getLastSortBy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastSortBy);
  }

  static Future<void> saveFilterSettings(Map<String, dynamic> filters) async {
    final prefs = await SharedPreferences.getInstance();
    final filtersJson = filters.entries.map((e) => '${e.key}:${e.value}').join(',');
    await prefs.setString(_keyLastFilterSettings, filtersJson);
  }

  static Future<Map<String, dynamic>?> getFilterSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filtersJson = prefs.getString(_keyLastFilterSettings);
      if (filtersJson == null || filtersJson.isEmpty) return null;
      final Map<String, dynamic> filters = {};
      filtersJson.split(',').forEach((entry) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          // Try to parse as number if possible, otherwise keep as string
          final value = parts[1];
          if (value == 'true') {
            filters[parts[0]] = true;
          } else if (value == 'false') {
            filters[parts[0]] = false;
          } else {
            final numValue = int.tryParse(value) ?? double.tryParse(value);
            filters[parts[0]] = numValue ?? value;
          }
        }
      });
      return filters.isEmpty ? null : filters;
    } catch (e) {
      print('⚠️ Error loading filter settings: $e');
      return null;
    }
  }

  // Scroll Position
  static Future<void> saveScrollPosition(String screenName, double position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_keyScrollPosition$screenName', position);
  }

  static Future<double?> getScrollPosition(String screenName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_keyScrollPosition$screenName');
  }

  // Theme & Language
  static Future<void> saveThemeMode(String themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, themeMode);
  }

  static Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? 'light';
  }

  static Future<void> saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language);
  }

  static Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'en';
  }

  // Notifications
  static Future<void> saveNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationEnabled, enabled);
  }

  static Future<bool> getNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationEnabled) ?? true;
  }

  // Clear all preferences
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Clear specific keys
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyBuyerId);
    await prefs.remove(_keySellerId);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyBuyerSellerMode);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyToken);
  }
}

