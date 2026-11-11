import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carauction/services/auth_service.dart';
import 'package:get/get.dart';
import 'package:carauction/controllers/app_state_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Check if app was already initialized (resuming from background)
    final appStateController = Get.find<AppStateController>();
    if (appStateController.shouldSkipSplash) {
      print('⏭️ SplashScreen: Skipping splash - app was already initialized');
      // Skip animation and navigate immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToLastRoute();
      });
      // Initialize with dummy controller that won't animate
      _animationController = AnimationController(
        vsync: this,
        duration: Duration.zero,
      );
      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(_animationController);
      _fadeAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(_animationController);
      return;
    }
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _animationController.forward().then((_) {
      _checkLoginAndNavigate();
    });
  }

  /// Navigate to last active route (when skipping splash)
  void _navigateToLastRoute() {
    final appStateController = Get.find<AppStateController>();
    final lastRoute = appStateController.currentRoute;
    print('🔄 SplashScreen: Navigating to last route: $lastRoute');
    
    if (lastRoute != '/' && lastRoute.isNotEmpty) {
      Navigator.pushReplacementNamed(context, lastRoute);
    } else {
      // Fallback to login check
      _checkLoginAndNavigate();
    }
  }

  Future<void> _checkLoginAndNavigate() async {
    final appStateController = Get.find<AppStateController>();
    
    try {
      // Check if user has a saved token
      final authService = AuthService();
      final token = await authService.getToken();
      
      if (token != null && token.isNotEmpty) {
        // User is logged in - navigate to home
        print('✅ SplashScreen: User is logged in, navigating to /home');
        if (mounted) {
          // Check user role to navigate to appropriate screen
          final prefs = await SharedPreferences.getInstance();
          final userRole = prefs.getString('user_role')?.toLowerCase();
          
          String targetRoute = '/home';
          if (userRole == 'inspector') {
            targetRoute = '/inspector-home';
          } else if (userRole == 'transporter') {
            targetRoute = '/transporter-home';
          }
          
          // Mark initial load complete and track route
          appStateController.markInitialLoadComplete();
          appStateController.setLastActiveRoute(targetRoute);
          
          Navigator.pushReplacementNamed(context, targetRoute);
        }
      } else {
        // User is not logged in - navigate to onboarding
        print('ℹ️ SplashScreen: User is not logged in, navigating to /onboarding');
        if (mounted) {
          appStateController.markInitialLoadComplete();
          appStateController.setLastActiveRoute('/onboarding');
          
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
      }
    } catch (e) {
      print('⚠️ SplashScreen: Error checking login status: $e');
      // On error, navigate to onboarding
      if (mounted) {
        appStateController.markInitialLoadComplete();
        appStateController.setLastActiveRoute('/onboarding');
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image - fully responsive
          Image.asset(
            'assets/images/splash_background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.white,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: ResponsiveHelper.padding(
                context,
                horizontal: 24,
                largeTabletScale: 1.5
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top spacing - minimal to push content to top above the car
                  ResponsiveHelper.sizedBoxHeight(context, 20),
                  
                  // Logo - Smaller and higher up
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Image.asset(
                      'assets/images/carxello_logo.png',
                      height: ResponsiveHelper.heightPercent(context, 15),
                      width: ResponsiveHelper.widthPercent(context, 60),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.directions_car,
                          size: ResponsiveHelper.iconSize(context, mobile: 80, tablet: 100, largeTablet: 140),
                          color: kBlackColor,
                        );
                      },
                    ),
                  ),
                  // Minimal spacing between logo and text
                  ResponsiveHelper.sizedBoxHeight(context, 8),
                  
                  // Text - Fully responsive font size with tablet support
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: ResponsiveHelper.padding(context, horizontal: 16),
                      child: Text(
                        'Your Journey Starts Here',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 25.0, tablet: 36.0, largeTablet: 68.0),
                          fontWeight: FontWeight.bold,
                          color: kBlackColor,
                          letterSpacing: ResponsiveHelper.value(context, mobile: 0.5, tablet: 0.8, largeTablet: 1.0),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}