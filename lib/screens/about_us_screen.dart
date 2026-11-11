import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/screen_size.dart';
import 'package:carauction/screens/home_page.dart';
import 'package:carauction/screens/contact_us_screen.dart';
import 'package:carauction/screens/login_screen.dart';
import 'package:carauction/screens/inspector_dashboard_screen.dart';
import 'package:carauction/screens/transporter_dashboard_screen.dart';
import 'package:carauction/services/auth_service.dart';
import 'package:carauction/utils/drawer_menu.dart';
import 'package:carauction/controllers/home_page_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  bool _hideBuyerSellerSwitch = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userRole = prefs.getString('user_role')?.toLowerCase();
      setState(() {
        _userRole = userRole;
        // Hide buyer/seller switch for transporter and inspector
        _hideBuyerSellerSwitch = userRole == 'transporter' || userRole == 'inspector';
      });
    } catch (e) {
      print('⚠️ Error checking user role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    return Scaffold(
      backgroundColor: kWhiteColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: kAccentColor, // Golden/light brown color for AppBar
        elevation: 0,
        toolbarHeight: ScreenSize.isLargeTablet ? 64.0 : (ScreenSize.isSmallTablet ? ScreenSize.appBarHeight : 56.0),
        iconTheme: IconThemeData(
          color: Colors.white,
          size: ScreenSize.isLargeTablet ? 32.0 : (ScreenSize.isSmallTablet ? ScreenSize.iconLarge : 28.0),
        ),
        centerTitle: ScreenSize.isLargeTablet ? true : false,
        leadingWidth: ScreenSize.isLargeTablet ? 80.0 : null,
        title: Text(
          'About Us',
          style: TextStyle(
            fontSize: ScreenSize.isLargeTablet ? 24.0 : (ScreenSize.isSmallTablet ? ScreenSize.headingMedium : 22.0),
            color: kWhiteColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu), // Menu icon
              onPressed: () {
                Scaffold.of(context).openDrawer(); // Open the drawer
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications), // Notification icon
            onPressed: () {
              // Handle notification action
            },
          ),
        ],
      ),
      drawer: DrawerMenu(
        selectedIndex: 0, // Home is selected by default when on About Us
        hideBuyerSellerSwitch: _hideBuyerSellerSwitch, // Hide switch for transporter/inspector
        controller: Get.isRegistered<HomePageController>() 
            ? Get.find<HomePageController>() 
            : Get.put(HomePageController(), permanent: true), // Use existing or register permanently
        onItemSelected: (index) {
          // Handle navigation based on selected index
          if (index == 0) {
            // Navigate to Home based on user role
            Navigator.pop(context);
            if (_userRole == 'transporter') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const TransporterDashboardScreen()),
              );
            } else if (_userRole == 'inspector') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const InspectorDashboardScreen()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            }
          }
        },
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            Stack(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.4,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/car1.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 20,
                  child: Text(
                    'About CarXello',
                    style: TextStyle(
                      color: kWhiteColor,
                      fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.headingHuge : 32.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // Content Section
            Padding(
              padding: EdgeInsets.all((ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.paddingMedium : 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Our Story Section
                  Text(
                    'Our Story',
                    style: TextStyle(
                      fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.headingSmall : 24.0,
                      fontWeight: FontWeight.bold,
                      color: kBlackColor,
                    ),
                  ),
                  SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/car2.png',
                          width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconExtraLarge : 100.0,
                          height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconExtraLarge : 100.0,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconExtraLarge : 100.0,
                              height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconExtraLarge : 100.0,
                              color: Colors.grey[300],
                              child: Icon(Icons.directions_car, size: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconLarge : 50.0),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                      Expanded(
                        child: Text(
                          'From the heart of San Francisco, we curate the world\'s most desired auto mobiles, linking enthusiasts to exceptional driving experiences.',
                          style: TextStyle(
                            fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.textLarge : 16.0,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingExtraLarge : 40.0),
                  // Why Choose us Section
                  Text(
                    'Why Choose us ?',
                    style: TextStyle(
                      fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.headingSmall : 24.0,
                      fontWeight: FontWeight.bold,
                      color: kBlackColor,
                    ),
                  ),
                  SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.gavel,
                          text: 'Bid, win, and secure your vehicle confidently from anywhere in the world.',
                        ),
                      ),
                      SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingSmall : 8.0),
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.search,
                          text: 'Every car is inspected and verified for authenticity before it goes to auction.',
                        ),
                      ),
                      SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingSmall : 8.0),
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.smartphone,
                          text: 'Find & Acquire Premium Cars on Your Phone.',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingExtraLarge : 40.0),
                  // Join Our Community Section
                  Text(
                    'Join Our Community',
                    style: TextStyle(
                      fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.headingSmall : 24.0,
                      fontWeight: FontWeight.bold,
                      color: kBlackColor,
                    ),
                  ),
                  SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular((ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.borderRadiusLarge : 16.0),
                        child: Container(
                          height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? 250.0 : 200.0,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/car3.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.4),
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 30,
                        left: 20,
                        child: Text(
                          'Bid. Win. Drive.\nJoin the community today.',
                          style: TextStyle(
                            color: kWhiteColor,
                            fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.headingSmall : 24.0,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingExtraLarge : 40.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFeatureCard({required IconData icon, required String text}) {
    return Container(
      padding: EdgeInsets.all((ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.paddingMedium : 16.0),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular((ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.borderRadiusMedium : 12.0),
        border: Border.all(color: kLightGreyColor, width: 1.0),
      ),
      child: Column(
        children: [
          Icon(icon, size: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconLarge : 40.0, color: kBlackColor),
          SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 12.0),
          Text(
            text,
            style: TextStyle(
              fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.textSmall : 12.0,
              color: Colors.grey,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
