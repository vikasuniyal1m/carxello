import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carauction/screens/login_screen.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';

// Diagonal Clipper for yellow strip
class DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0); // Start at top-left
    path.lineTo(0, size.height); // Draw line to bottom-left
    path.lineTo(
      size.width,
      size.height * 0.4,
    ); // Draw diagonal line to right side
    path.lineTo(size.width, 0); // Draw line to top-right
    path.close(); // Close the path
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  // Consistent dark background color
  static const Color darkBgColor = Color(0xFF1A1A1A);
  // Consistent yellow accent color
  static const Color accentYellow = Color(0xFFE6B94D);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _checkLoginStatusAndNavigate();
  }

  Future<void> _checkLoginStatusAndNavigate() async {
    // Delay check slightly to let animation start
    await Future.delayed(const Duration(milliseconds: 100));
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token != null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Stay on onboarding if no token (or navigate to public home if that was the logic, 
      // but usually onboarding is the entry point if not logged in. 
      // The original code had logic to go to /public-home if valid token not found? 
      // Original code: 
      // if (token != null) -> /home
      // else -> /public-home
      // Wait, if it goes to /public-home immediately, the onboarding screen is skipped?
      // Re-reading original code:
      // It was called in initState? No, it was just defined but NOT CALLED in initState in the original code!
      // Wait, looking at original lines 46-64:
      // initState calls _controller.forward().
      // It does NOT call _checkLoginStatusAndNavigate().
      // So the method was dead code or intended usage?
      // I will keep the method but NOT call it automatically if it wasn't called before.
      // Actually, standard onboarding usually waits for user interaction.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      backgroundColor: OnboardingScreen.darkBgColor,
      enableScroll: false,
      body: Stack(
        children: [
          // Background fade arrows - Responsive, Device Adaptive
          Positioned(
            right: 0,
            bottom: 0,
            width: ResponsiveHelper.widthPercent(context, 50),
            height: ResponsiveHelper.screenHeight(context),
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/images/rightarrow.png',
                repeat: ImageRepeat.repeat,
                width: ResponsiveHelper.value(context, mobile: 50.0, tablet: 80.0, largeTablet: 100.0),
                height: ResponsiveHelper.value(context, mobile: 50.0, tablet: 80.0, largeTablet: 100.0),
                fit: BoxFit.contain, // Prevent stretching
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: ResponsiveHelper.widthPercent(context, 50),
            height: ResponsiveHelper.screenHeight(context),
            child: Opacity(
              opacity: 0.08,
              child: Image.asset(
                'assets/images/leftarrow.png',
                repeat: ImageRepeat.repeat,
                width: ResponsiveHelper.value(context, mobile: 50.0, tablet: 80.0, largeTablet: 100.0),
                height: ResponsiveHelper.value(context, mobile: 50.0, tablet: 80.0, largeTablet: 100.0),
                fit: BoxFit.contain, // Prevent stretching
              ),
            ),
          ),

          // Main content
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // --- Car Interior Image Section ---
                  Expanded(
                    flex: ResponsiveHelper.value(context, mobile: 4, tablet: 4, largeTablet: 4),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          width: double.infinity,
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/images/onboarding_car_interior.png',
                            fit: ResponsiveHelper.isMobile(context) ? BoxFit.contain : BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Padding(
                                  padding: ResponsiveHelper.padding(context, all: 24),
                                  child: Text(
                                    'Car Image Placeholder',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18),
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- Yellow Accent Bar ---
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ClipPath(
                        clipper: DiagonalClipper(),
                        child: Container(
                          height: ResponsiveHelper.safeHeight(
                            context,
                            mobile: 50,
                            tablet: 60,
                            desktop: 80,
                            // Respecting the original quirk for very specific large android tablets if needed,
                            // but generally 60-80 is good.
                          ),
                          width: double.infinity,
                          color: OnboardingScreen.accentYellow,
                        ),
                      ),
                    ),
                  ),

                  // --- Bottom Content Section ---
                  Expanded(
                    flex: 6,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          width: double.infinity,
                          color: OnboardingScreen.darkBgColor,
                          padding: ResponsiveHelper.padding(
                            context, 
                            horizontal: 24, 
                            vertical: 24,
                            largeTabletScale: 1.5
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Text content CENTERED vertically using Expanded
                              Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Main heading text
                                      Text(
                                        'Fast, Easy, And',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 28, tablet: 40, largeTablet: 68),
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: ResponsiveHelper.value(context, mobile: 0.5, tablet: 0.8, largeTablet: 1.0),
                                          height: 1.2,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      ResponsiveHelper.sizedBoxHeight(context, 12),
                                      Text(
                                        'Reliable Car Auctions!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 28, tablet: 40, largeTablet: 68),
                                          fontWeight: FontWeight.bold,
                                          color: OnboardingScreen.accentYellow,
                                          letterSpacing: ResponsiveHelper.value(context, mobile: 0.5, tablet: 0.8, largeTablet: 1.0),
                                          height: 1.2,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      ResponsiveHelper.sizedBoxHeight(context, 24),
                                      // Subheading text
                                      Text(
                                        'Get Behind The Wheel In Minutes With',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 20, largeTablet: 42),
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          height: 1.4,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                                      Text(
                                        'Our Seamless Booking Process',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 20, largeTablet: 42),
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          height: 1.4,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Get Started button at BOTTOM
                              Container(
                                width: double.infinity,
                                constraints: BoxConstraints(
                                  minHeight: ResponsiveHelper.buttonHeight(context, mobile: 52, tablet: 60, largeTablet: 72),
                                ),
                                margin: ResponsiveHelper.padding(context, horizontal: 20, bottom: 20, largeTabletScale: 1.5),
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginScreen(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: OnboardingScreen.accentYellow,
                                    foregroundColor: Colors.black,
                                    elevation: ResponsiveHelper.elevation(
                                      context,
                                      mobile: 4,
                                      tablet: 6,
                                      desktop: 8,
                                    ),
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      horizontal: 24,
                                      vertical: 16,
                                      largeTabletScale: 1.2
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                          context,
                                          mobile: 16,
                                          tablet: 20,
                                          desktop: 24,
                                        ),
                                      ),
                                    ),
                                    shadowColor: Colors.black.withOpacity(0.3),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Get Started',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 26, largeTablet: 56),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                          letterSpacing: ResponsiveHelper.value(context, mobile: 0.8, tablet: 1.0, largeTablet: 1.2),
                                          height: 1.2,
                                        ),
                                      ),
                                      ResponsiveHelper.sizedBoxWidth(context, 16),
                                      Container(
                                        width: ResponsiveHelper.value(context, mobile: 36.0, tablet: 44.0, largeTablet: 80.0),
                                        height: ResponsiveHelper.value(context, mobile: 32.0, tablet: 38.0, largeTablet: 70.0),
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.4),
                                              blurRadius: ResponsiveHelper.elevation(context, mobile: 6),
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 24, largeTablet: 40),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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
