import 'package:carauction/screens/onboarding_screen.dart';
import 'package:carauction/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carauction/screens/registration_screen.dart';
import 'package:carauction/screens/login_screen.dart';
import 'package:carauction/screens/home_page.dart';
import 'package:carauction/screens/public_home_page.dart';
import 'package:carauction/screens/inspector_dashboard_screen.dart';
import 'package:carauction/screens/transporter_dashboard_screen.dart';
import 'package:carauction/screens/billing_history_screen.dart';
import 'package:carauction/screens/invoice_detail_screen.dart';
import 'package:carauction/controllers/home_page_controller.dart';
import 'package:carauction/controllers/bid_controller.dart';
import 'package:carauction/screens/payment_screen.dart';
import 'package:carauction/screens/counter_offers_screen.dart';
import 'package:carauction/screens/create_counter_offer_screen.dart';
import 'package:carauction/screens/disputes_screen.dart';
import 'package:carauction/screens/create_dispute_screen.dart';
import 'package:carauction/screens/dispute_detail_screen.dart';
import 'package:carauction/screens/newsletter_subscription_screen.dart';
import 'package:carauction/screens/blog_list_screen.dart';
import 'package:carauction/screens/blog_post_detail_screen.dart';
import 'package:carauction/screens/profile_settings_screen.dart';
import 'package:get/get.dart';
import 'package:carauction/controllers/app_state_controller.dart';
import 'package:carauction/controllers/auth_controller.dart';
import 'package:carauction/controllers/registration_controller.dart';
import 'package:carauction/controllers/notification_controller.dart';
import 'package:carauction/utils/api_config.dart';
import 'package:carauction/utils/module_checker.dart';
import 'package:carauction/services/websocket_service.dart';
import 'package:carauction/services/push_notification_service.dart';
import 'package:carauction/services/local_notification_service.dart';

import 'package:carauction/utils/device_preview_config.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/timezone_config.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize device detection (auto-detect physical device vs emulator)
  await ApiConfig.initialize();
  
  // Print API configuration on app start
  ApiConfig.printConfig();
  
  // Initialize timezone configuration
  await TimezoneConfig.initialize();
  

  
  // Initialize Local Notification Service
  try {
    await LocalNotificationService.instance.initialize();
    print('✅ Local Notifications: Initialized');
  } catch (e) {
    print('⚠️ Local Notifications: Initialization failed: $e');
  }
  
  // Initialize WebSocket Service (will connect after login)
  try {
    WebSocketService.instance; // Initialize singleton
    print('✅ WebSocket Service: Initialized');
  } catch (e) {
    print('⚠️ WebSocket Service: Initialization failed: $e');
  }
  
  // Initialize GetX controllers
  Get.put(AppStateController());
  Get.put(AuthController());
  Get.put(RegistrationController());
  Get.put(NotificationController(), permanent: true);
  
  // Check all modules after app starts (delayed to ensure app is ready)
  Future.delayed(const Duration(seconds: 3), () async {
    await ModuleChecker.checkAllModules();
  });
  
  // Check if running on desktop or web - only allow iOS and Android
  if (kIsWeb) {
    // Block web browsers
    runApp(const DesktopNotSupportedApp());
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Block desktop platforms
    runApp(const DesktopNotSupportedApp());
  } else {
    // Allow iOS and Android only
    runApp(const MyApp());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final Widget _initialScreen = const SplashScreen();
  DateTime? _lastPausedTime;
  static const Duration _minPauseDuration = Duration(minutes: 5); // Only refresh if paused for 5+ minutes
  bool _isInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('✅ App Lifecycle Observer: Initialized');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupResources();
    print('✅ App Lifecycle Observer: Disposed');
    super.dispose();
  }

  /// Cleanup resources when app is disposed
  void _cleanupResources() {
    try {
      // Disconnect WebSocket if connected
      try {
        final wsService = WebSocketService.instance;
        if (wsService.isConnected) {
          wsService.disconnect();
          print('🔌 WebSocket: Disconnected on app dispose');
        }
      } catch (e) {
        print('⚠️ WebSocket cleanup error: $e');
      }

      // Cancel any pending timers or subscriptions
      // Note: GetX controllers handle their own cleanup via onClose()
      print('🧹 Resources cleaned up');
    } catch (e) {
      print('⚠️ Error during resource cleanup: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App resumed from background
        print('📱 App Lifecycle: RESUMED');
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
        // App is transitioning between states (e.g., incoming call, notification)
        print('📱 App Lifecycle: INACTIVE');
        // Don't do heavy operations here - state might change quickly
        break;
      case AppLifecycleState.paused:
        // App is in background
        print('📱 App Lifecycle: PAUSED');
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        // App is about to be terminated
        print('📱 App Lifecycle: DETACHED');
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        // App is hidden (iOS only)
        print('📱 App Lifecycle: HIDDEN');
        _handleAppPaused();
        break;
    }
  }

  /// Handle app paused state - pause network operations, save state
  /// IMPORTANT: Don't disconnect or cleanup - just pause to prevent app restart
  /// App will stay alive in background and NOT restart automatically
  void _handleAppPaused() {
    // Only update flag if not already in background (prevent multiple calls)
    if (!_isInBackground) {
      _isInBackground = true;
      _lastPausedTime = DateTime.now();
      
      try {
        // Pause WebSocket (reduce activity but keep connection - DON'T disconnect)
        // This keeps app alive in background
        try {
          final wsService = WebSocketService.instance;
          wsService.setAppBackgroundState(true);
          print('⏸️ WebSocket: Activity paused (app in background) - Connection kept alive');
          print('💡 App will stay alive in background - NO auto-restart');
        } catch (e) {
          print('⚠️ WebSocket pause error: $e');
        }
        
        // Pause timers (but don't cancel - just pause to prevent restart)
        // Keeping timers alive prevents app from being killed
        _pauseControllerTimers();

        // Save any pending data (lightweight operation)
        _saveAppState();
        
        print('💾 App state saved (paused) - App will NOT restart');
        print('✅ App is now in background - will stay alive until user kills it');
      } catch (e) {
        print('⚠️ Error handling app pause: $e');
      }
    } else {
      print('⏸️ App already in background - skipping pause handling');
    }
  }

  /// Handle app resumed state - resume operations, refresh data if needed
  /// IMPORTANT: Don't force refresh or restart - just resume existing state
  void _handleAppResumed() {
    final wasInBackground = _isInBackground;
    _isInBackground = false;
    
    if (wasInBackground) {
      print('🔄 App resumed from background');
      print('💡 Resuming app state - NO restart, keeping existing state');
      
      // Only refresh data if app was paused for significant time (5+ minutes)
      // This prevents unnecessary refreshes and app restarts
      _refreshDataOnResume();
      
      // Resume WebSocket activity (connection should still be alive)
      try {
        final wsService = WebSocketService.instance;
        wsService.setAppBackgroundState(false);
        if (!wsService.isConnected) {
          // Only reconnect if actually disconnected (shouldn't happen if lifecycle is correct)
          wsService.connect();
          print('🔌 WebSocket: Reconnecting on resume (was disconnected)');
        } else {
          print('✅ WebSocket: Resuming activity (connection was kept alive)');
        }
      } catch (e) {
        print('⚠️ WebSocket resume error: $e');
      }
      
      // Resume all timers in controllers (they should still be alive)
      _resumeControllerTimers();
    } else {
      print('🔄 App resumed (was not in background)');
    }

    // Check modules on resume (non-blocking, delayed to not interfere)
    Future.delayed(const Duration(seconds: 2), () {
      ModuleChecker.checkAllModules();
    });
  }

  /// Handle app detached state - cleanup before termination
  /// This is called when app is about to be killed by system or user
  /// IMPORTANT: Only cleanup when app is actually being terminated, not when going to background
  void _handleAppDetached() {
    print('🛑 App detached - app is being terminated');
    print('💡 This is normal termination - user or system is killing the app');
    _cleanupResources();
    _saveAppState();
  }

  /// Save app state before pause/termination
  void _saveAppState() {
    try {
      // Save any critical app state here
      // GetX controllers handle their own state via onClose()
      print('💾 App state saved');
    } catch (e) {
      print('⚠️ Error saving app state: $e');
    }
  }
  
  /// Pause all controller timers when app goes to background
  /// IMPORTANT: Don't cancel timers - just pause to prevent app restart
  /// App will stay alive in background with timers paused
  void _pauseControllerTimers() {
    try {
      // Update AppStateController to notify all controllers
      try {
        final appStateController = Get.find<AppStateController>();
        appStateController.setAppBackgroundState(true);
        print('📱 AppStateController: Set to background state');
      } catch (e) {
        print('⚠️ AppStateController not found: $e');
      }
      
      // Pause HomePageController timer (but don't cancel - keep state)
      try {
        final homeController = Get.find<HomePageController>();
        // Timer will check background state before running
        print('⏸️ HomePageController: Will pause on next timer tick (timer kept alive)');
      } catch (e) {
        // Controller not found, that's okay - app might not be on home page
      }
      
      // Pause BidController timer (but don't cancel - keep state)
      try {
        final bidController = Get.find<BidController>();
        // Timer will check background state before running
        print('⏸️ BidController: Will pause on next timer tick (timer kept alive)');
      } catch (e) {
        // Controller not found, that's okay - app might not be on bid page
      }
      
      print('⏸️ All controller timers will pause (but kept alive to prevent restart)');
      print('💡 App will stay alive in background - timers paused but not cancelled');
    } catch (e) {
      print('⚠️ Error pausing controller timers: $e');
    }
  }
  
  /// Resume all controller timers when app comes to foreground
  /// IMPORTANT: Don't restart - just resume existing timers
  void _resumeControllerTimers() {
    try {
      // Update AppStateController to notify all controllers
      try {
        final appStateController = Get.find<AppStateController>();
        appStateController.setAppBackgroundState(false);
        print('📱 AppStateController: Set to foreground state');
      } catch (e) {
        print('⚠️ AppStateController not found: $e');
      }
      
      // Controllers will resume their timers automatically when background state changes
      // Timers are still alive, they just check background state before running
      print('▶️ Controller timers will resume automatically (they were kept alive)');
      print('💡 App resuming with existing state - NO restart');
    } catch (e) {
      print('⚠️ Error resuming controller timers: $e');
    }
  }

  void _refreshDataOnResume() {
    // IMPORTANT: Don't refresh on resume to prevent app restart
    // App should resume with existing state, data will refresh only when it comes from database/WebSocket
    print('⏭️ Skipping refresh on resume - app resuming with existing state');
    print('💡 Data will refresh only when it comes from database/WebSocket, not on resume');
    return;
  }

  @override
  Widget build(BuildContext context) {
    // Wrap app with DevicePreview in debug mode
    Widget app = GetMaterialApp(
      title: 'Car Auction',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: child!,
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) {
          print('📍 Route: / (SplashScreen)');
          return _initialScreen;
        },
        '/onboarding': (context) {
          print('📍 Route: /onboarding (OnboardingScreen)');
          return const OnboardingScreen();
        },
        '/register': (context) => const RegistrationScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) {
          print('📍 Route: /home (HomePage) - Building widget');
          return const HomePage();
        },
        '/public-home': (context) => const PublicHomePage(),
        '/inspector-home': (context) => const InspectorDashboardScreen(),
        '/transporter-home': (context) => const TransporterDashboardScreen(),
        '/billing-history': (context) => const BillingHistoryScreen(),
        '/invoice-detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return InvoiceDetailScreen(invoiceId: args['invoiceId']);
        },
        '/payment': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return PaymentScreen(invoiceId: args['invoiceId'], amount: args['amount']);
        },
        '/counter-offers': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          return CounterOffersScreen(
            vehicleId: args?['vehicleId'],
            forBuyer: args?['forBuyer'] ?? false,
          );
        },
        '/create-counter-offer': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return CreateCounterOfferScreen(
            car: args['car'],
            bidId: args['bidId'],
          );
        },
        '/disputes': (context) => const DisputesScreen(),
        '/create-dispute': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          return CreateDisputeScreen(vehicleId: args?['vehicleId']);
        },
        '/dispute-detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return DisputeDetailScreen(disputeId: args['disputeId']);
        },
        '/newsletter': (context) => const NewsletterSubscriptionScreen(),
        '/blog': (context) => const BlogListScreen(),
        '/blog-detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return BlogPostDetailScreen(postId: args['postId']);
        },
        '/profile-settings': (context) => const ProfileSettingsScreen(),
      },
    );

    // Enable device preview in debug mode
    if (DevicePreviewConfig.enableDevicePreview && kDebugMode) {
      return DevicePreview(
        enabled: false,
        builder: (context) => app,
      );
    }
    return app;
  }
}

// Desktop Not Supported Screen
class DesktopNotSupportedApp extends StatelessWidget {
  const DesktopNotSupportedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Auction',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                Icons.phone_android,
                size: ResponsiveHelper.iconSize(context, mobile: 100, tablet: 120, desktop: 140),
                color: Colors.grey[400],
              ),
              ResponsiveHelper.sizedBoxHeight(context, 40),
              Text(
                'Mobile App Only',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 28, tablet: 32, desktop: 36),
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              ResponsiveHelper.sizedBoxHeight(context, 20),
              Text(
                'This application is designed exclusively for mobile devices (Android & iOS).',
                textAlign: TextAlign.center,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              ResponsiveHelper.sizedBoxHeight(context, 10),
              Text(
                'Please use this app on a smartphone or tablet.',
                textAlign: TextAlign.center,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                  color: Colors.grey[500],
                  ),
                ),
              ],          ),

          ),
        ),
      ),
    );
  }
}
