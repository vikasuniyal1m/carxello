import 'package:get/get.dart';
import 'package:carauction/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carauction/services/auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  
  Future<void> signOut() async {
    // Clear user session data (e.g., tokens, user info)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all stored data

    // Navigate to LoginScreen and remove all previous routes
    Get.offAll(() => LoginScreen());
  }
  
  Future<void> deleteAccount() async {
    try {
      await _authService.deleteAccount();
      // Clear user session data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      // Navigate to LoginScreen
      Get.offAll(() => LoginScreen());
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  @override
  void onClose() {
    // Cleanup resources if any
    super.onClose();
  }
}