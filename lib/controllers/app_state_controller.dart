import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStateController extends GetxController {
  var counter = 0.obs;
  
  // App lifecycle state - tracks if app is in background
  final RxBool isAppInBackground = false.obs;
  
  // Session state - tracks if app has already completed initial load
  // This prevents splash screen from re-running when app resumes from background
  final RxBool hasCompletedInitialLoad = false.obs;
  
  // Last active route - to restore navigation on resume
  final RxString lastActiveRoute = '/'.obs;
  
  /// Mark initial load as complete (called after splash screen completes)
  void markInitialLoadComplete() {
    hasCompletedInitialLoad.value = true;
    print('✅ AppStateController: Initial load marked as complete');
  }
  
  /// Check if splash screen should be skipped
  bool get shouldSkipSplash => hasCompletedInitialLoad.value;
  
  /// Set the last active route (for navigation restoration)
  void setLastActiveRoute(String route) {
    lastActiveRoute.value = route;
    print('📍 AppStateController: Last active route = $route');
  }
  
  /// Get the last active route
  String get currentRoute => lastActiveRoute.value;
  
  /// Set app background state (called from main.dart lifecycle)
  void setAppBackgroundState(bool inBackground) {
    isAppInBackground.value = inBackground;
    print('📱 AppStateController: App background state = $inBackground');
  }
  
  /// Check if app is in background
  bool get isInBackground => isAppInBackground.value;

  @override
  void onInit() {
    super.onInit();
    _loadCounter();
  }

  void increment() {
    counter.value++;
    _saveCounter();
  }

  void _loadCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    counter.value = prefs.getInt('counter') ?? 0;
  }

  void _saveCounter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('counter', counter.value);
  }

  @override
  void onClose() {
    // Save counter before closing
    _saveCounter();
    super.onClose();
  }
}