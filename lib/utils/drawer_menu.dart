import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/controllers/home_page_controller.dart';
import 'package:carauction/controllers/auth_controller.dart';
import 'package:carauction/screens/my_bids_screen.dart';
import 'package:carauction/screens/watchlist_screen.dart';
import 'package:carauction/screens/billing_history_screen.dart';
import 'package:carauction/screens/list_vehicle_screen.dart';
import 'package:carauction/controllers/bid_controller.dart';
import 'package:carauction/screens/about_us_screen.dart';
import 'package:carauction/screens/contact_us_screen.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/screens/chat_list_screen.dart';
import 'dart:io';

class DrawerMenu extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final HomePageController? controller;
  final bool hideBuyerSellerSwitch; // Hide buyer/seller switch for inspector/transporter

  const DrawerMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.controller,
    this.hideBuyerSellerSwitch = false,
  });

  // Device-specific helper methods
  bool _isIPad(BuildContext context) => ResponsiveHelper.isIPad(context);
  bool _isIPhone(BuildContext context) => ResponsiveHelper.isIPhone(context);
  bool _isAndroidTablet(BuildContext context) => ResponsiveHelper.isAndroid(context) && ResponsiveHelper.isTablet(context);
  bool _isAndroidMobile(BuildContext context) => ResponsiveHelper.isAndroid(context) && ResponsiveHelper.isMobile(context);

  // Get device-specific font sizes - MUCH LARGER for 1280x1880 @2.0
  double _getHeaderTitleSize(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGE
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return 42.0; // EXTRA LARGE for large tablet (increased from 32.0)
    }
    
    if (_isIPad(context)) {
      return screenHeight >= 1400 ? 28.0 : 30.0;
    }
    if (_isIPhone(context)) {
      return 24.0;
    }
    if (_isAndroidTablet(context)) {
      return screenHeight >= 1400 ? 28.0 : 30.0;
    }
    return 24.0; // Android Mobile
  }

  double _getHeaderSubtitleSize(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGE
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return 24.0; // EXTRA LARGE for large tablet (increased from 18.0)
    }
    
    if (_isIPad(context) || _isAndroidTablet(context)) {
      return screenHeight >= 1400 ? 16.0 : 17.0;
    }
    return 13.0; // Mobile
  }

  double _getMenuItemTextSize(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGE
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return 26.0; // EXTRA LARGE for large tablet (increased from 20.0)
    }
    
    if (_isIPad(context) || _isAndroidTablet(context)) {
      return screenHeight >= 1400 ? 18.0 : 19.0;
    }
    return 15.0; // Mobile
  }

  double _getSwitchModeTextSize(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGE
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return 28.0; // EXTRA LARGE for large tablet (increased from 22.0)
    }
    
    if (_isIPad(context) || _isAndroidTablet(context)) {
      return screenHeight >= 1400 ? 20.0 : 21.0;
    }
    return 16.0; // Mobile
  }

  double _getSwitchButtonTextSize(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGE
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return 24.0; // EXTRA LARGE for large tablet (increased from 19.0)
    }
    
    if (_isIPad(context) || _isAndroidTablet(context)) {
      return screenHeight >= 1400 ? 17.0 : 18.0;
    }
    return 14.0; // Mobile
  }

  double _getIconSize(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGER
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return 40.0; // EXTRA LARGE for large tablet (increased from 32.0)
    }
    
    if (_isIPad(context) || _isAndroidTablet(context)) {
      return screenHeight >= 1400 ? 28.0 : 30.0;
    }
    return 22.0; // Mobile
  }

  double _getHeaderIconSize(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGE
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return 52.0; // EXTRA LARGE for large tablet (increased from 40.0)
    }
    
    if (_isIPad(context) || _isAndroidTablet(context)) {
      return screenHeight >= 1400 ? 36.0 : 38.0;
    }
    return 28.0; // Mobile
  }

  // Get device-specific padding - MUCH LARGER for 1280x1880 @2.0
  EdgeInsets _getHeaderPadding(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGE PADDING
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return EdgeInsets.fromLTRB(44.0, MediaQuery.of(context).padding.top + 36.0, 44.0, 52.0);
    }
    
    double horizontal;
    double top;
    double bottom;
    
    if (_isIPad(context) || _isAndroidTablet(context)) {
      horizontal = screenWidth >= 800 ? 28.0 : 24.0;
      top = MediaQuery.of(context).padding.top + 24.0;
      bottom = screenHeight >= 1400 ? 32.0 : 36.0;
    } else {
      horizontal = 20.0;
      top = MediaQuery.of(context).padding.top + 20.0;
      bottom = 30.0;
    }
    
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  double _getSwitchContainerPadding(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGE
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return 32.0; // EXTRA LARGE for large tablet (increased from 24.0)
    }
    
    if (_isIPad(context) || _isAndroidTablet(context)) {
      return screenHeight >= 1400 ? 20.0 : 22.0;
    }
    return 16.0; // Mobile
  }

  double _getSwitchButtonPadding(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGE
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return 24.0; // EXTRA LARGE for large tablet (increased from 18.0)
    }
    
    if (_isIPad(context) || _isAndroidTablet(context)) {
      return screenHeight >= 1400 ? 16.0 : 18.0;
    }
    return 12.0; // Mobile
  }

  double _getMenuItemPadding(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGE
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return 18.0; // EXTRA LARGE for large tablet (increased from 12.0)
    }
    
    if (_isIPad(context) || _isAndroidTablet(context)) {
      return screenHeight >= 1400 ? 10.0 : 12.0;
    }
    return 8.0; // Mobile
  }

  double _getMenuItemMargin(BuildContext context) {
    final screenHeight = ResponsiveHelper.screenHeight(context);
    final screenWidth = ResponsiveHelper.screenWidth(context);
    
    // Special handling for LARGE TABLET: 1280x1880 @2.0 - EXTRA LARGE
    if (screenWidth >= 1200 && screenHeight >= 1800) {
      return 12.0; // EXTRA LARGE for large tablet (increased from 8.0)
    }
    
    if (_isIPad(context) || _isAndroidTablet(context)) {
      return screenHeight >= 1400 ? 6.0 : 8.0;
    }
    return 4.0; // Mobile
  }

  @override
  Widget build(BuildContext context) {
    // Only get HomePageController if buyer/seller switch is visible (not hidden)
    HomePageController? homeController;
    if (!hideBuyerSellerSwitch) {
      if (controller != null) {
        homeController = controller;
      } else if (Get.isRegistered<HomePageController>()) {
        try {
          homeController = Get.find<HomePageController>();
        } catch (e) {
          homeController = null;
        }
      }
    }
    final AuthController authController = Get.find<AuthController>(); // Get AuthController instance
    
    return Drawer(
      width: ResponsiveHelper.drawerWidth(context), // Responsive drawer width
      backgroundColor: Colors.white,
      child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            // Enhanced Header - Device Adaptive
            Container(
              padding: _getHeaderPadding(context),
              decoration: BoxDecoration(
                color: kAccentColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(
                          (ResponsiveHelper.screenWidth(context) >= 1200 && ResponsiveHelper.screenHeight(context) >= 1800)
                              ? _getMenuItemPadding(context) * 1.8  // EXTRA LARGE for large tablet
                              : _getMenuItemPadding(context) * 1.2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_offer,
                          color: Colors.white,
                          size: _getHeaderIconSize(context),
                        ),
                      ),
                      SizedBox(width: 
                        (ResponsiveHelper.screenWidth(context) >= 1200 && ResponsiveHelper.screenHeight(context) >= 1800)
                            ? _getMenuItemPadding(context) * 2.0  // EXTRA LARGE spacing for large tablet
                            : _getMenuItemPadding(context) * 1.5,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Car Auction',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _getHeaderTitleSize(context),
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 
                              (ResponsiveHelper.screenWidth(context) >= 1200 && ResponsiveHelper.screenHeight(context) >= 1800)
                                  ? 8.0  // EXTRA LARGE spacing for large tablet
                                  : 4.0,
                            ),
                            Text(
                              'Your Auto Marketplace',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: _getHeaderSubtitleSize(context),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // Buyer/Seller Switch - Only show if not hidden (for inspector/transporter) - Device Adaptive
          if (!hideBuyerSellerSwitch)
            Container(
              margin: EdgeInsets.fromLTRB(
                _getSwitchContainerPadding(context) * 0.8,
                _getSwitchContainerPadding(context),
                _getSwitchContainerPadding(context) * 0.8,
                _getSwitchContainerPadding(context) * 0.5,
              ),
              padding: EdgeInsets.all(_getSwitchContainerPadding(context)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.swap_horiz, color: kAccentColor, size: _getIconSize(context) * 0.7),
                      SizedBox(width: _getMenuItemPadding(context)),
                      Text(
                        'Switch Mode',
                        style: TextStyle(
                          fontSize: _getSwitchModeTextSize(context),
                          fontWeight: FontWeight.bold,
                          color: kBlackColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _getSwitchContainerPadding(context)),
                  Obx(
                    () {
                      if (homeController == null) return const SizedBox.shrink();
                      return Container(
                        padding: EdgeInsets.all(
                          (ResponsiveHelper.screenWidth(context) >= 1200 && ResponsiveHelper.screenHeight(context) >= 1800)
                              ? 8.0  // EXTRA LARGE for large tablet
                              : 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final c = homeController;
                                  if (c != null) await c.toggleBuyerSeller(true);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    vertical: _getSwitchButtonPadding(context),
                                    horizontal: _getMenuItemPadding(context),
                                  ),
                                  decoration: BoxDecoration(
                                    color: homeController!.isBuyer.value 
                                        ? kAccentColor 
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: homeController.isBuyer.value
                                        ? [
                                            BoxShadow(
                                              color: kAccentColor.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shopping_cart,
                                        color: homeController.isBuyer.value 
                                            ? Colors.white 
                                            : Colors.grey[700],
                                        size: _getIconSize(context) * 0.7,
                                      ),
                                      SizedBox(width: _getMenuItemPadding(context)),
                                      Text(
                                        'Buyer',
                                        style: TextStyle(
                                          fontSize: _getSwitchButtonTextSize(context),
                                          fontWeight: FontWeight.w600,
                                          color: homeController.isBuyer.value 
                                              ? Colors.white 
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final c = homeController;
                                  if (c != null) await c.toggleBuyerSeller(false);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    vertical: _getSwitchButtonPadding(context),
                                    horizontal: _getMenuItemPadding(context),
                                  ),
                                  decoration: BoxDecoration(
                                    color: !homeController!.isBuyer.value 
                                        ? kAccentColor 
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: !homeController.isBuyer.value
                                        ? [
                                            BoxShadow(
                                              color: kAccentColor.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.store,
                                        color: !homeController.isBuyer.value 
                                            ? Colors.white 
                                            : Colors.grey[700],
                                        size: _getIconSize(context) * 0.7,
                                      ),
                                      SizedBox(width: _getMenuItemPadding(context)),
                                      Text(
                                        'Seller',
                                        style: TextStyle(
                                          fontSize: _getSwitchButtonTextSize(context),
                                          fontWeight: FontWeight.w600,
                                          color: !homeController.isBuyer.value 
                                              ? Colors.white 
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ],
              ),
            ),
          // Menu Items - Dynamic based on Buyer/Seller mode
          _buildDrawerItem(
            context: context,
            icon: Icons.home_rounded,
            title: 'HOME',
            isSelected: selectedIndex == 0,
            onTap: () {
              onItemSelected(0);
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.person_outline_rounded,
            title: 'My Profile',
            isSelected: false,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile-settings');
            },
          ),
          // Dynamic menu items based on Buyer/Seller mode - Only show if buyer/seller switch is visible
          if (!hideBuyerSellerSwitch && homeController != null)
            Obx(() {
              if (homeController!.isBuyer.value) {
              // Buyer Mode Menu Items
              return Column(
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Messages',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.gavel_rounded,
                    title: 'My Bids',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyBidsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.emoji_events_rounded,
                    title: 'Won Auctions',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      // Initialize BidController and set tab to "Won Auctions" (tab index 2)
                      final bidController = Get.put(BidController());
                      bidController.updateSelectedTab(2);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyBidsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.shopping_bag_rounded,
                    title: 'Purchase History',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BillingHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.bookmark_rounded,
                    title: 'Watchlist',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WatchlistScreen(),
                        ),
                      );
                    },
                  ),
                ],
              );
            } else {
              // Seller Mode Menu Items (matching header.php seller menu)
              return Column(
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Messages',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChatListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.gavel_rounded,
                    title: 'Manage Bids',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to seller's Active Sales tab (which shows bids)
                      homeController?.selectedSellerTab.value = 2; // Active Sales tab
                      onItemSelected(0); // Go to home
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.warehouse_rounded,
                    title: 'My Inventory',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to seller's Inventory tab
                      homeController?.selectedSellerTab.value = 3; // Inventory tab
                      onItemSelected(0); // Go to home
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Sell a Car',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ListVehicleScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.analytics_rounded,
                    title: 'Analytics',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to seller's Performance tab (analytics)
                      homeController?.selectedSellerTab.value = 4; // Performance tab
                      onItemSelected(0); // Go to home
                    },
                  ),
                ],
              );
            }
          }),
          const SizedBox(height: 8),
          const Divider(height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 8),
          // Common menu items for all roles
          _buildDrawerItem(
            context: context,
            icon: Icons.info_outline_rounded,
            title: 'About Us',
            isSelected: false,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutUsScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.contact_mail_rounded,
            title: 'Contact Us',
            isSelected: false,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactUsScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.delete_forever_rounded,
            title: 'Delete Account',
            isSelected: false,
            iconColor: Colors.red,
            textColor: Colors.red,
            onTap: () async {
              Navigator.pop(context); // Close drawer first
              bool confirmDelete = await showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );

              if (confirmDelete == true) {
                try {
                  await authController.deleteAccount();
                  // After successful deletion, sign out and navigate to login
                  await authController.signOut();
                } catch (e) {
                  Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
                }
              }
            },
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 8),
          _buildDrawerItem(
            context: context,
            icon: Icons.logout_rounded,
            title: 'Logout',
            isSelected: false,
            iconColor: Colors.red,
            textColor: Colors.red,
            onTap: () async {
              Navigator.pop(context);
              await authController.signOut();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final defaultIconColor = iconColor ?? (isSelected ? kAccentColor : Colors.grey[700]);
    final defaultTextColor = textColor ?? (isSelected ? kBlackColor : Colors.grey[800]);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _getMenuItemMargin(context) * 1.5,
        vertical: _getMenuItemMargin(context),
      ),
      decoration: BoxDecoration(
        color: isSelected ? kAccentColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 
            (ResponsiveHelper.screenWidth(context) >= 1200 && ResponsiveHelper.screenHeight(context) >= 1800)
                ? 20.0  // EXTRA LARGE for large tablet
                : 16.0,
          vertical: 
            (ResponsiveHelper.screenWidth(context) >= 1200 && ResponsiveHelper.screenHeight(context) >= 1800)
                ? 8.0  // EXTRA LARGE for large tablet
                : 4.0,
        ),
        minVerticalPadding: 
          (ResponsiveHelper.screenWidth(context) >= 1200 && ResponsiveHelper.screenHeight(context) >= 1800)
              ? 16.0  // EXTRA LARGE for large tablet
              : 8.0,
        leading: Container(
          padding: EdgeInsets.all(_getMenuItemPadding(context)),
          decoration: BoxDecoration(
            color: isSelected 
                ? kAccentColor.withOpacity(0.2) 
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: defaultIconColor,
            size: _getIconSize(context),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: _getMenuItemTextSize(context),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: defaultTextColor,
            height: 1.3, // Better line height for readability
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 
                  (ResponsiveHelper.screenWidth(context) >= 1200 && ResponsiveHelper.screenHeight(context) >= 1800)
                      ? 6.0  // EXTRA LARGE for large tablet
                      : 4.0,
                height: _getMenuItemTextSize(context) * 1.2,
                decoration: BoxDecoration(
                  color: kAccentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

