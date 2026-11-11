import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/screen_size.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/services/auth_service.dart';
import 'package:carauction/services/user_service.dart';
import 'package:carauction/controllers/home_page_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  late HomePageController _homeController;
  
  // Profile Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  
  // Notification Settings
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _bidAlerts = true;
  bool _auctionReminders = true;
  bool _winningBidAlerts = true;
  bool _priceDropAlerts = false;
  
  // Payment Methods
  List<Map<String, dynamic>> _paymentMethods = [];
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  
  // Shipping Addresses
  List<Map<String, dynamic>> _shippingAddresses = [];
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();
  
  // Bidding Preferences (Buyer only)
  double _defaultBidIncrement = 100.0;
  bool _autoBidEnabled = false;
  double _maxAutoBidAmount = 0.0;
  bool _bidConfirmations = true;
  
  // Privacy Settings
  bool _showProfileToSellers = true;
  bool _showBidHistory = true;
  bool _showPurchaseHistory = false;
  bool _allowDirectMessages = true;
  
  // Seller-specific fields
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  
  // Business Hours (Seller only)
  Map<String, Map<String, String>> _businessHours = {
    'Monday': {'open': '09:00', 'close': '17:00', 'enabled': 'true'},
    'Tuesday': {'open': '09:00', 'close': '17:00', 'enabled': 'true'},
    'Wednesday': {'open': '09:00', 'close': '17:00', 'enabled': 'true'},
    'Thursday': {'open': '09:00', 'close': '17:00', 'enabled': 'true'},
    'Friday': {'open': '09:00', 'close': '17:00', 'enabled': 'true'},
    'Saturday': {'open': '09:00', 'close': '13:00', 'enabled': 'true'},
    'Sunday': {'open': '00:00', 'close': '00:00', 'enabled': 'false'},
  };
  
  // Payment Settings (Seller - Payout preferences)
  String _payoutMethod = 'bank_transfer';
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _routingNumberController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  
  // Listing Preferences (Seller only)
  double _defaultStartingBid = 1000.0;
  int _defaultAuctionDuration = 7; // days
  bool _autoApproveBids = true;
  bool _requireInspections = false;
  bool _allowCounterOffers = true;
  String _defaultPaymentTerms = 'immediate';
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isBuyer = true;
  
  // Account information
  Map<String, dynamic> _accountInfo = {};
  String? _userRole;
  bool _hideBiddingForRole = false;
  bool _hideShippingForRole = false;

  @override
  void initState() {
    super.initState();
    // Safely get or register HomePageController
    if (Get.isRegistered<HomePageController>()) {
      _homeController = Get.find<HomePageController>();
      _isBuyer = _homeController.isBuyer.value;
    } else {
      // If controller not registered (e.g., transporter/inspector), register it and set default buyer mode
      _homeController = Get.put(HomePageController(), permanent: true);
      _isBuyer = true; // Default to buyer mode if not registered
      // Check user role to determine if buyer/seller switch should be available
      _checkUserRole();
    }
    _tabController = TabController(length: 6, vsync: this);
    _loadUserData();
  }

  Future<void> _checkUserRole() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userRole = prefs.getString('user_role')?.toLowerCase();
      _userRole = userRole;
      if (userRole == 'transporter' || userRole == 'inspector') {
        _isBuyer = true;
      }
      _hideBiddingForRole = userRole == 'transporter' || userRole == 'inspector';
      _hideShippingForRole = userRole == 'inspector';
      int newLen = _isBuyer ? (6 - (_hideBiddingForRole ? 1 : 0) - (_hideShippingForRole ? 1 : 0)) : 6;
      if (newLen < 1) newLen = 1;
      if (_tabController.length != newLen) {
        _tabController.dispose();
        _tabController = TabController(length: newLen, vsync: this);
        setState(() {});
      }
    } catch (e) {
      print('⚠️ Error checking user role: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _taxIdController.dispose();
    _businessDescriptionController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _routingNumberController.dispose();
    _accountHolderNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Fetch user profile from backend
      try {
        final userProfile = await _userService.getUserProfile();
        print('📥 User Profile from Backend: $userProfile');
        
        // Load profile data from backend response
        _nameController.text = userProfile['full_name'] ?? 
                               userProfile['name'] ?? 
                               prefs.getString('user_name') ?? '';
        _emailController.text = userProfile['email'] ?? prefs.getString('user_email') ?? '';
        _phoneController.text = userProfile['phone'] ?? 
                                userProfile['phone_number'] ?? 
                                prefs.getString('user_phone_number') ?? '';
        _companyController.text = userProfile['company_name'] ?? 
                                  prefs.getString('user_company_name') ?? '';
        
        // Load address fields
        _addressLine1Controller.text = userProfile['address'] ?? 
                                       prefs.getString('user_address') ?? '';
        _cityController.text = userProfile['city'] ?? 
                                prefs.getString('user_city') ?? '';
        _stateController.text = userProfile['state'] ?? 
                                prefs.getString('user_state') ?? '';
        _zipCodeController.text = userProfile['zip_code'] ?? 
                                   prefs.getString('user_zip_code') ?? '';
        
        // Store account info for display
        _accountInfo = {
          'created_at': userProfile['created_at'],
          'last_login': userProfile['last_login'],
          'role': userProfile['role'],
        };
        
        // Update SharedPreferences with backend data
        await prefs.setString('user_name', _nameController.text);
        await prefs.setString('user_email', _emailController.text);
        await prefs.setString('user_phone_number', _phoneController.text);
        await prefs.setString('user_company_name', _companyController.text);
        await prefs.setString('user_address', _addressLine1Controller.text);
        await prefs.setString('user_city', _cityController.text);
        await prefs.setString('user_state', _stateController.text);
        await prefs.setString('user_zip_code', _zipCodeController.text);
        
        // Load seller-specific data if available
        if (!_isBuyer) {
          _businessNameController.text = userProfile['business_name'] ?? 
                                        prefs.getString('business_name') ?? '';
          _businessAddressController.text = userProfile['business_address'] ?? 
                                           prefs.getString('business_address') ?? '';
          _businessPhoneController.text = userProfile['business_phone'] ?? 
                                        prefs.getString('business_phone') ?? '';
          _businessEmailController.text = userProfile['business_email'] ?? 
                                         userProfile['email'] ?? '';
          _taxIdController.text = userProfile['tax_id'] ?? 
                                  prefs.getString('tax_id') ?? '';
          _businessDescriptionController.text = userProfile['business_description'] ?? 
                                               prefs.getString('business_description') ?? '';
          
          // Update SharedPreferences
          await prefs.setString('business_name', _businessNameController.text);
          await prefs.setString('business_address', _businessAddressController.text);
          await prefs.setString('business_phone', _businessPhoneController.text);
          await prefs.setString('tax_id', _taxIdController.text);
          await prefs.setString('business_description', _businessDescriptionController.text);
        }
      } catch (e) {
        print('⚠️ Error fetching user profile from backend: $e');
        // Fallback to SharedPreferences if backend fails
        _nameController.text = prefs.getString('user_name') ?? '';
        _emailController.text = prefs.getString('user_email') ?? '';
        _phoneController.text = prefs.getString('user_phone_number') ?? '';
        _companyController.text = prefs.getString('user_company_name') ?? '';
        _addressLine1Controller.text = prefs.getString('user_address') ?? '';
        _cityController.text = prefs.getString('user_city') ?? '';
        _stateController.text = prefs.getString('user_state') ?? '';
        _zipCodeController.text = prefs.getString('user_zip_code') ?? '';
      }
      
      // Load notification settings
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _bidAlerts = prefs.getBool('bid_alerts') ?? true;
      _auctionReminders = prefs.getBool('auction_reminders') ?? true;
      _winningBidAlerts = prefs.getBool('winning_bid_alerts') ?? true;
      _priceDropAlerts = prefs.getBool('price_drop_alerts') ?? false;
      
      // Load payment methods
      final paymentMethodsJson = prefs.getString('payment_methods');
      if (paymentMethodsJson != null) {
        try {
          _paymentMethods = List<Map<String, dynamic>>.from(
            (jsonDecode(paymentMethodsJson) as List).map((e) => e as Map<String, dynamic>)
          );
        } catch (e) {
          _paymentMethods = [];
        }
      }
      
      // Load shipping addresses
      final addressesJson = prefs.getString('shipping_addresses');
      if (addressesJson != null) {
        try {
          _shippingAddresses = List<Map<String, dynamic>>.from(
            (jsonDecode(addressesJson) as List).map((e) => e as Map<String, dynamic>)
          );
        } catch (e) {
          _shippingAddresses = [];
        }
      }
      
      // Load bidding preferences
      _defaultBidIncrement = prefs.getDouble('default_bid_increment') ?? 100.0;
      _autoBidEnabled = prefs.getBool('auto_bid_enabled') ?? false;
      _maxAutoBidAmount = prefs.getDouble('max_auto_bid_amount') ?? 0.0;
      _bidConfirmations = prefs.getBool('bid_confirmations') ?? true;
      
      // Load privacy settings
      _showProfileToSellers = prefs.getBool('show_profile_to_sellers') ?? true;
      _showBidHistory = prefs.getBool('show_bid_history') ?? true;
      _showPurchaseHistory = prefs.getBool('show_purchase_history') ?? false;
      _allowDirectMessages = prefs.getBool('allow_direct_messages') ?? true;
      
      // Load seller-specific data
      _businessNameController.text = prefs.getString('business_name') ?? '';
      _businessAddressController.text = prefs.getString('business_address') ?? '';
      _businessPhoneController.text = prefs.getString('business_phone') ?? '';
      _taxIdController.text = prefs.getString('tax_id') ?? '';
      _businessDescriptionController.text = prefs.getString('business_description') ?? '';
      
      // Load business hours
      final businessHoursJson = prefs.getString('business_hours');
      if (businessHoursJson != null) {
        try {
          final loaded = jsonDecode(businessHoursJson) as Map<String, dynamic>;
          _businessHours = loaded.map((key, value) => 
            MapEntry(key, Map<String, String>.from(value as Map))
          );
        } catch (e) {
          print('Error loading business hours: $e');
        }
      }
      
      // Load payment settings (seller)
      _payoutMethod = prefs.getString('payout_method') ?? 'bank_transfer';
      _bankNameController.text = prefs.getString('bank_name') ?? '';
      _accountNumberController.text = prefs.getString('account_number') ?? '';
      _routingNumberController.text = prefs.getString('routing_number') ?? '';
      _accountHolderNameController.text = prefs.getString('account_holder_name') ?? '';
      
      // Load listing preferences (seller)
      _defaultStartingBid = prefs.getDouble('default_starting_bid') ?? 1000.0;
      _defaultAuctionDuration = prefs.getInt('default_auction_duration') ?? 7;
      _autoApproveBids = prefs.getBool('auto_approve_bids') ?? true;
      _requireInspections = prefs.getBool('require_inspections') ?? false;
      _allowCounterOffers = prefs.getBool('allow_counter_offers') ?? true;
      _defaultPaymentTerms = prefs.getString('default_payment_terms') ?? 'immediate';
      
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Prepare profile data for backend
      final profileData = <String, dynamic>{
        'full_name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'address': _addressLine1Controller.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'zip_code': _zipCodeController.text,
        'company_name': _companyController.text,
      };
      
      // Update backend
      try {
        await _userService.updateUserProfile(profileData);
        print('✅ Profile updated successfully on backend');
      } catch (e) {
        print('⚠️ Error updating profile on backend: $e');
        // Continue to save locally even if backend fails
      }
      
      // Update local storage
      await prefs.setString('user_name', _nameController.text);
      await prefs.setString('user_email', _emailController.text);
      await prefs.setString('user_phone_number', _phoneController.text);
      await prefs.setString('user_company_name', _companyController.text);
      await prefs.setString('user_address', _addressLine1Controller.text);
      await prefs.setString('user_city', _cityController.text);
      await prefs.setString('user_state', _stateController.text);
      await prefs.setString('user_zip_code', _zipCodeController.text);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('email_notifications', _emailNotifications);
      await prefs.setBool('push_notifications', _pushNotifications);
      await prefs.setBool('bid_alerts', _bidAlerts);
      await prefs.setBool('auction_reminders', _auctionReminders);
      await prefs.setBool('winning_bid_alerts', _winningBidAlerts);
      await prefs.setBool('price_drop_alerts', _priceDropAlerts);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification settings saved'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDeleteAccountConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text('Are you sure you want to delete your account?'),
                Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteAccount();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    try {
      // Show loading indicator
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      await _authService.deleteAccount();

      // Dismiss loading indicator
      Get.back();

      Get.snackbar(
        'Account Deleted',
        'Your account has been successfully deleted.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Navigate to login screen or home screen after deletion
      // Ensure all user data is cleared locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Clear all stored preferences

      // Example: Navigate to login screen
      Get.offAllNamed('/login'); // Assuming you have a named route for login

    } catch (e) {
      // Dismiss loading indicator
      Get.back();

      Get.snackbar(
        'Error',
        'Failed to delete account: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _saveBiddingPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('default_bid_increment', _defaultBidIncrement);
      await prefs.setBool('auto_bid_enabled', _autoBidEnabled);
      await prefs.setDouble('max_auto_bid_amount', _maxAutoBidAmount);
      await prefs.setBool('bid_confirmations', _bidConfirmations);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bidding preferences saved'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving preferences: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _savePrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_profile_to_sellers', _showProfileToSellers);
      await prefs.setBool('show_bid_history', _showBidHistory);
      await prefs.setBool('show_purchase_history', _showPurchaseHistory);
      await prefs.setBool('allow_direct_messages', _allowDirectMessages);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Privacy settings saved'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    return SafeScaffold(
      backgroundColor: Colors.grey[50],
      enableScroll: false, // Disable auto-scroll for TabBarView
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        toolbarHeight: ScreenSize.isLargeTablet ? 64.0 : (ScreenSize.isSmallTablet ? ScreenSize.appBarHeight : 56.0),
        iconTheme: IconThemeData(
          color: Colors.white,
          size: ScreenSize.isLargeTablet ? 32.0 : (ScreenSize.isSmallTablet ? ScreenSize.iconLarge : 28.0),
        ),
        centerTitle: ScreenSize.isLargeTablet ? true : false,
        leadingWidth: ScreenSize.isLargeTablet ? 80.0 : null,
        title: Text(
          'Profile & Settings',
          style: TextStyle(
            fontSize: ScreenSize.isLargeTablet ? 24.0 : (ScreenSize.isSmallTablet ? ScreenSize.headingMedium : 22.0),
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Obx(() {
              final isBuyer = _homeController.isBuyer.value;
              return Column(
                children: [
                  // Tab Bar
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: kAccentColor,
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: kAccentColor,
                      indicatorWeight: 3,
                      tabs: () {
                        if (isBuyer) {
                          final list = <Tab>[
                            const Tab(text: 'Profile'),
                            const Tab(text: 'Notifications'),
                            const Tab(text: 'Payment'),
                            if (!_hideShippingForRole) const Tab(text: 'Shipping'),
                            if (!_hideBiddingForRole) const Tab(text: 'Bidding'),
                            const Tab(text: 'Privacy'),
                          ];
                          return list;
                        } else {
                          return const [
                            Tab(text: 'Profile'),
                            Tab(text: 'Business Hours'),
                            Tab(text: 'Notifications'),
                            Tab(text: 'Payment'),
                            Tab(text: 'Listing'),
                            Tab(text: 'Privacy'),
                          ];
                        }
                      }(),
                    ),
                  ),
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: () {
                        if (isBuyer) {
                          final views = <Widget>[
                            _buildProfileTab(),
                            _buildNotificationsTab(),
                            _buildPaymentMethodsTab(),
                          ];
                          if (!_hideShippingForRole) {
                            views.add(_buildShippingAddressesTab());
                          }
                          if (!_hideBiddingForRole) {
                            views.add(_buildBiddingPreferencesTab());
                          }
                          views.add(_buildPrivacySettingsTab());
                          return views;
                        } else {
                          return [
                            _buildSellerProfileTab(),
                            _buildBusinessHoursTab(),
                            _buildNotificationsTab(),
                            _buildSellerPaymentSettingsTab(),
                            _buildListingPreferencesTab(),
                            _buildSellerPrivacySettingsTab(),
                          ];
                        }
                      }(),
                    ),
                  ),
                ],
              );
            }),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: kAccentColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: kAccentColor, width: 2),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: kAccentColor,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.isNotEmpty ? _nameController.text : 'Your Name',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: kBlackColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emailController.text.isNotEmpty ? _emailController.text : 'your.email@example.com',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Account Information Card
          Container(
            padding: EdgeInsets.all((ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.paddingMedium : 20.0),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular((ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.borderRadiusLarge : 16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: kAccentColor, size: 24),
                    SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 12.0),
                    Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.headingSmall : 18.0,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                _buildAccountInfoRow(
                  context,
                  'Member since:',
                  _formatAccountDate(_accountInfo['created_at']),
                ),
                SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingSmall : 8.0),
                _buildAccountInfoRow(
                  context,
                  'Last login:',
                  _formatAccountDate(_accountInfo['last_login'] ?? _accountInfo['created_at']),
                ),
                SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingSmall : 8.0),
                _buildAccountInfoRow(
                  context,
                  'Account type:',
                  _formatRole(_accountInfo['role']),
                ),
                SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                const Divider(),
                SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 12.0),
                Text(
                  'Security',
                      style: TextStyle(
                        fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.textLarge : 16.0,
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                ),
                SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 12.0),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to change password screen
                      Get.snackbar(
                        'Change Password',
                        'Password change feature coming soon',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Change Password'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kAccentColor,
                      side: BorderSide(color: kAccentColor),
                      padding: EdgeInsets.symmetric(vertical: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.paddingSmall : 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular((ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.borderRadiusSmall : 8.0),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: ScreenSize.dividerHeight * 0.02), // Add some spacing
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showDeleteAccountConfirmationDialog,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text('Delete Account'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(vertical: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.paddingSmall : 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular((ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.borderRadiusSmall : 8.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Profile Form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kWhiteColor,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: true, // Email can be changed
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _companyController,
                  label: 'Company Name (Optional)',
                  icon: Icons.business_outlined,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Address Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _addressLine1Controller,
                  label: 'Address',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _cityController,
                        label: 'City',
                        icon: Icons.location_city_outlined,
                      ),
                    ),
                    SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 12.0),
                    Expanded(
                      child: _buildTextField(
                        controller: _stateController,
                        label: 'State',
                        icon: Icons.map_outlined,
                      ),
                    ),
                    SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 12.0),
                    Expanded(
                      child: _buildTextField(
                        controller: _zipCodeController,
                        label: 'ZIP Code',
                        icon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Update Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kWhiteColor,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active, color: kAccentColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Notification Preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSwitchTile(
                  title: 'Email Notifications',
                  subtitle: 'Receive notifications via email',
                  value: _emailNotifications,
                  onChanged: (value) {
                    setState(() => _emailNotifications = value);
                    _saveNotificationSettings();
                  },
                  icon: Icons.email,
                ),
                const Divider(height: 32),
                _buildSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications on device',
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() => _pushNotifications = value);
                    _saveNotificationSettings();
                  },
                  icon: Icons.notifications,
                ),
                const Divider(height: 32),
                _buildSwitchTile(
                  title: 'Bid Alerts',
                  subtitle: 'Get notified when someone outbids you',
                  value: _bidAlerts,
                  onChanged: (value) {
                    setState(() => _bidAlerts = value);
                    _saveNotificationSettings();
                  },
                  icon: Icons.gavel,
                ),
                const Divider(height: 32),
                _buildSwitchTile(
                  title: 'Auction Reminders',
                  subtitle: 'Reminders for auctions ending soon',
                  value: _auctionReminders,
                  onChanged: (value) {
                    setState(() => _auctionReminders = value);
                    _saveNotificationSettings();
                  },
                  icon: Icons.access_time,
                ),
                const Divider(height: 32),
                _buildSwitchTile(
                  title: 'Winning Bid Alerts',
                  subtitle: 'Notifications when you win an auction',
                  value: _winningBidAlerts,
                  onChanged: (value) {
                    setState(() => _winningBidAlerts = value);
                    _saveNotificationSettings();
                  },
                  icon: Icons.emoji_events,
                ),
                const Divider(height: 32),
                _buildSwitchTile(
                  title: 'Price Drop Alerts',
                  subtitle: 'Alert when saved vehicles drop in price',
                  value: _priceDropAlerts,
                  onChanged: (value) {
                    setState(() => _priceDropAlerts = value);
                    _saveNotificationSettings();
                  },
                  icon: Icons.trending_down,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Payment Method Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddPaymentMethodDialog(),
              icon: const Icon(Icons.add_card),
              label: const Text('Add Payment Method'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Payment Methods List
          if (_paymentMethods.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: kWhiteColor,
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
                  Icon(Icons.credit_card, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No payment methods added',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a payment method to make purchases faster',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            ..._paymentMethods.map((method) => _buildPaymentMethodCard(method)),
        ],
      ),
    );
  }

  Widget _buildShippingAddressesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Address Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddAddressDialog(),
              icon: const Icon(Icons.add_location),
              label: const Text('Add Shipping Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Addresses List
          if (_shippingAddresses.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: kWhiteColor,
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
                  Icon(Icons.location_on, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No shipping addresses added',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a shipping address for faster checkout',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            ..._shippingAddresses.map((address) => _buildAddressCard(address)),
        ],
      ),
    );
  }

  Widget _buildBiddingPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kWhiteColor,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: kAccentColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Bidding Preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Default Bid Increment
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 20, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Default Bid Increment',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: kBlackColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '\$${_defaultBidIncrement.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kAccentColor,
                        ),
                      ),
                      Slider(
                        value: _defaultBidIncrement,
                        min: 50,
                        max: 1000,
                        divisions: 19,
                        label: '\$${_defaultBidIncrement.toStringAsFixed(0)}',
                        activeColor: kAccentColor,
                        onChanged: (value) {
                          setState(() => _defaultBidIncrement = value);
                          _saveBiddingPreferences();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Auto-Bid Settings
                _buildSwitchTile(
                  title: 'Enable Auto-Bid',
                  subtitle: 'Automatically increase your bid when outbid',
                  value: _autoBidEnabled,
                  onChanged: (value) {
                    setState(() => _autoBidEnabled = value);
                    _saveBiddingPreferences();
                  },
                  icon: Icons.auto_awesome,
                ),
                if (_autoBidEnabled) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Maximum Auto-Bid Amount',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kBlackColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: TextEditingController(
                            text: _maxAutoBidAmount > 0 
                                ? _maxAutoBidAmount.toStringAsFixed(0)
                                : '',
                          ),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter max amount',
                            prefixText: '\$ ',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: kAccentColor, width: 2),
                            ),
                          ),
                          onChanged: (value) {
                            final amount = double.tryParse(value) ?? 0.0;
                            setState(() => _maxAutoBidAmount = amount);
                            _saveBiddingPreferences();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildSwitchTile(
                  title: 'Bid Confirmations',
                  subtitle: 'Show confirmation dialog before placing bids',
                  value: _bidConfirmations,
                  onChanged: (value) {
                    setState(() => _bidConfirmations = value);
                    _saveBiddingPreferences();
                  },
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveBiddingPreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Preferences',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kWhiteColor,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.privacy_tip, color: kAccentColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Privacy Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSwitchTile(
                  title: 'Show Profile to Sellers',
                  subtitle: 'Allow sellers to view your profile information',
                  value: _showProfileToSellers,
                  onChanged: (value) {
                    setState(() => _showProfileToSellers = value);
                    _savePrivacySettings();
                  },
                  icon: Icons.visibility,
                ),
                const Divider(height: 32),
                _buildSwitchTile(
                  title: 'Show Bid History',
                  subtitle: 'Display your bidding history to sellers',
                  value: _showBidHistory,
                  onChanged: (value) {
                    setState(() => _showBidHistory = value);
                    _savePrivacySettings();
                  },
                  icon: Icons.history,
                ),
                const Divider(height: 32),
                _buildSwitchTile(
                  title: 'Show Purchase History',
                  subtitle: 'Display your purchase history to sellers',
                  value: _showPurchaseHistory,
                  onChanged: (value) {
                    setState(() => _showPurchaseHistory = value);
                    _savePrivacySettings();
                  },
                  icon: Icons.shopping_bag,
                ),
                const Divider(height: 32),
                _buildSwitchTile(
                  title: 'Allow Direct Messages',
                  subtitle: 'Let sellers send you direct messages',
                  value: _allowDirectMessages,
                  onChanged: (value) {
                    setState(() => _allowDirectMessages = value);
                    _savePrivacySettings();
                  },
                  icon: Icons.message,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savePrivacySettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Privacy Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kAccentColor),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kAccentColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kAccentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kAccentColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kBlackColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: kAccentColor,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final isDefault = method['is_default'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16),
        border: isDefault
            ? Border.all(color: kAccentColor, width: 2)
            : Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kAccentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.credit_card, color: kAccentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      method['card_type'] ?? 'Card',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kAccentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kAccentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '**** **** **** ${method['last_4'] ?? '0000'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
                onTap: () => _showEditPaymentMethodDialog(method),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
                onTap: () => _deletePaymentMethod(method),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> address) {
    final isDefault = address['is_default'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(16),
        border: isDefault
            ? Border.all(color: kAccentColor, width: 2)
            : Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: kAccentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                address['label'] ?? 'Home',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kBlackColor,
                ),
              ),
              if (isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kAccentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Default',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kAccentColor,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              PopupMenuButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                    onTap: () => _showEditAddressDialog(address),
                  ),
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                    onTap: () => _deleteAddress(address),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${address['address_line_1'] ?? ''}\n${address['address_line_2'] ?? ''}\n${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['zip_code'] ?? ''}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentMethodDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _cardNumberController,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  hintText: '1234 5678 9012 3456',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cardHolderController,
                decoration: const InputDecoration(
                  labelText: 'Card Holder Name',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expiryController,
                      decoration: const InputDecoration(
                        labelText: 'Expiry',
                        hintText: 'MM/YY',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cvvController,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_cardNumberController.text.isNotEmpty) {
                setState(() {
                  _paymentMethods.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'card_type': 'Visa',
                    'last_4': _cardNumberController.text.length >= 4
                        ? _cardNumberController.text.substring(_cardNumberController.text.length - 4)
                        : '0000',
                    'is_default': _paymentMethods.isEmpty,
                  });
                  _savePaymentMethods();
                });
                _cardNumberController.clear();
                _cardHolderController.clear();
                _expiryController.clear();
                _cvvController.clear();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddAddressDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Shipping Address'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _addressLine1Controller,
                decoration: const InputDecoration(labelText: 'Address Line 1'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressLine2Controller,
                decoration: const InputDecoration(labelText: 'Address Line 2 (Optional)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _stateController,
                      decoration: const InputDecoration(labelText: 'State'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _zipCodeController,
                      decoration: const InputDecoration(labelText: 'ZIP Code'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _countryController,
                      decoration: const InputDecoration(labelText: 'Country'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_addressLine1Controller.text.isNotEmpty) {
                setState(() {
                  _shippingAddresses.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'label': 'Address ${_shippingAddresses.length + 1}',
                    'address_line_1': _addressLine1Controller.text,
                    'address_line_2': _addressLine2Controller.text,
                    'city': _cityController.text,
                    'state': _stateController.text,
                    'zip_code': _zipCodeController.text,
                    'country': _countryController.text,
                    'is_default': _shippingAddresses.isEmpty,
                  });
                  _saveShippingAddresses();
                });
                _addressLine1Controller.clear();
                _addressLine2Controller.clear();
                _cityController.clear();
                _stateController.clear();
                _zipCodeController.clear();
                _countryController.clear();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditPaymentMethodDialog(Map<String, dynamic> method) {
    // Similar to add dialog but pre-filled
    _showAddPaymentMethodDialog();
  }

  void _showEditAddressDialog(Map<String, dynamic> address) {
    _addressLine1Controller.text = address['address_line_1'] ?? '';
    _addressLine2Controller.text = address['address_line_2'] ?? '';
    _cityController.text = address['city'] ?? '';
    _stateController.text = address['state'] ?? '';
    _zipCodeController.text = address['zip_code'] ?? '';
    _countryController.text = address['country'] ?? '';
    _showAddAddressDialog();
  }

  void _deletePaymentMethod(Map<String, dynamic> method) {
    setState(() {
      _paymentMethods.removeWhere((m) => m['id'] == method['id']);
      _savePaymentMethods();
    });
  }

  void _deleteAddress(Map<String, dynamic> address) {
    setState(() {
      _shippingAddresses.removeWhere((a) => a['id'] == address['id']);
      _saveShippingAddresses();
    });
  }

  Future<void> _savePaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('payment_methods', jsonEncode(_paymentMethods));
    // TODO: Save to backend API
  }

  Future<void> _saveShippingAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shipping_addresses', jsonEncode(_shippingAddresses));
    // TODO: Save to backend API
  }

  // Seller-specific methods
  Widget _buildSellerProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: kAccentColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: kAccentColor, width: 2),
                  ),
                  child: Icon(
                    Icons.business,
                    size: 40,
                    color: kAccentColor,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _businessNameController.text.isNotEmpty 
                            ? _businessNameController.text 
                            : 'Business Name',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: kBlackColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emailController.text.isNotEmpty ? _emailController.text : 'your.email@example.com',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kWhiteColor,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Business Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kBlackColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _nameController,
                  label: 'Owner Name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _businessNameController,
                  label: 'Business Name',
                  icon: Icons.business_outlined,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: false,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _businessPhoneController,
                  label: 'Business Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _businessAddressController,
                  label: 'Business Address',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _taxIdController,
                  label: 'Tax ID / EIN (Optional)',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _businessDescriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Business Description',
                    prefixIcon: Icon(Icons.description_outlined, color: kAccentColor),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kAccentColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSellerProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessHoursTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kWhiteColor,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, color: kAccentColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Business Hours',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ..._businessHours.entries.map((entry) {
                  final day = entry.key;
                  final hours = entry.value;
                  final isEnabled = hours['enabled'] == 'true';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: kBlackColor,
                                  ),
                                ),
                              ),
                              Switch(
                                value: isEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _businessHours[day]!['enabled'] = value.toString();
                                  });
                                  _saveBusinessHours();
                                },
                                activeColor: kAccentColor,
                              ),
                            ],
                          ),
                          if (isEnabled) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Open: ${hours['open']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Close: ${hours['close']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _showTimePickerDialog(day, 'open'),
                                  child: const Text('Edit'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveBusinessHours,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Business Hours',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerPaymentSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kWhiteColor,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: kAccentColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Payout Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Payout Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kBlackColor,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _payoutMethod,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kAccentColor, width: 2),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'paypal', child: Text('PayPal')),
                    DropdownMenuItem(value: 'check', child: Text('Check')),
                  ],
                  onChanged: (value) {
                    setState(() => _payoutMethod = value ?? 'bank_transfer');
                    _savePaymentSettings();
                  },
                ),
                const SizedBox(height: 24),
                if (_payoutMethod == 'bank_transfer') ...[
                  _buildTextField(
                    controller: _bankNameController,
                    label: 'Bank Name',
                    icon: Icons.account_balance,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _accountHolderNameController,
                    label: 'Account Holder Name',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _accountNumberController,
                    label: 'Account Number',
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _routingNumberController,
                    label: 'Routing Number',
                    icon: Icons.numbers_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savePaymentSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Payment Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kWhiteColor,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, color: kAccentColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Listing Preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Default Starting Bid',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kBlackColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '\$${_defaultStartingBid.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kAccentColor,
                        ),
                      ),
                      Slider(
                        value: _defaultStartingBid,
                        min: 100,
                        max: 100000,
                        divisions: 99,
                        label: '\$${_defaultStartingBid.toStringAsFixed(0)}',
                        activeColor: kAccentColor,
                        onChanged: (value) {
                          setState(() => _defaultStartingBid = value);
                          _saveListingPreferences();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Default Auction Duration',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kBlackColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_defaultAuctionDuration days',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kAccentColor,
                        ),
                      ),
                      Slider(
                        value: _defaultAuctionDuration.toDouble(),
                        min: 1,
                        max: 30,
                        divisions: 29,
                        label: '$_defaultAuctionDuration days',
                        activeColor: kAccentColor,
                        onChanged: (value) {
                          setState(() => _defaultAuctionDuration = value.toInt());
                          _saveListingPreferences();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSwitchTile(
                  title: 'Auto-Approve Bids',
                  subtitle: 'Automatically approve bids without manual review',
                  value: _autoApproveBids,
                  onChanged: (value) {
                    setState(() => _autoApproveBids = value);
                    _saveListingPreferences();
                  },
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 16),
                _buildSwitchTile(
                  title: 'Require Inspections',
                  subtitle: 'Require vehicle inspection before listing',
                  value: _requireInspections,
                  onChanged: (value) {
                    setState(() => _requireInspections = value);
                    _saveListingPreferences();
                  },
                  icon: Icons.verified_user,
                ),
                const SizedBox(height: 16),
                _buildSwitchTile(
                  title: 'Allow Counter Offers',
                  subtitle: 'Allow buyers to make counter offers',
                  value: _allowCounterOffers,
                  onChanged: (value) {
                    setState(() => _allowCounterOffers = value);
                    _saveListingPreferences();
                  },
                  icon: Icons.swap_horiz,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Default Payment Terms',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kBlackColor,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _defaultPaymentTerms,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'immediate', child: Text('Immediate Payment')),
                    DropdownMenuItem(value: '3_days', child: Text('3 Days')),
                    DropdownMenuItem(value: '7_days', child: Text('7 Days')),
                  ],
                  onChanged: (value) {
                    setState(() => _defaultPaymentTerms = value ?? 'immediate');
                    _saveListingPreferences();
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveListingPreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Preferences',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerPrivacySettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kWhiteColor,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.privacy_tip, color: kAccentColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Privacy Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kBlackColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSwitchTile(
                  title: 'Show Profile to Buyers',
                  subtitle: 'Allow buyers to view your profile information',
                  value: _showProfileToSellers,
                  onChanged: (value) {
                    setState(() => _showProfileToSellers = value);
                    _savePrivacySettings();
                  },
                  icon: Icons.visibility,
                ),
                const Divider(height: 32),
                _buildSwitchTile(
                  title: 'Show Listing History',
                  subtitle: 'Display your listing history to buyers',
                  value: _showBidHistory,
                  onChanged: (value) {
                    setState(() => _showBidHistory = value);
                    _savePrivacySettings();
                  },
                  icon: Icons.history,
                ),
                const Divider(height: 32),
                _buildSwitchTile(
                  title: 'Show Sale History',
                  subtitle: 'Display your sale history to buyers',
                  value: _showPurchaseHistory,
                  onChanged: (value) {
                    setState(() => _showPurchaseHistory = value);
                    _savePrivacySettings();
                  },
                  icon: Icons.shopping_bag,
                ),
                const Divider(height: 32),
                _buildSwitchTile(
                  title: 'Allow Direct Messages',
                  subtitle: 'Let buyers send you direct messages',
                  value: _allowDirectMessages,
                  onChanged: (value) {
                    setState(() => _allowDirectMessages = value);
                    _savePrivacySettings();
                  },
                  icon: Icons.message,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savePrivacySettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Privacy Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSellerProfile() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Prepare seller profile data for backend
      final profileData = <String, dynamic>{
        'name': _nameController.text,
        'phone_number': _businessPhoneController.text,
        'business_name': _businessNameController.text,
        'business_address': _businessAddressController.text,
        'business_phone': _businessPhoneController.text,
        'tax_id': _taxIdController.text,
        'business_description': _businessDescriptionController.text,
      };
      
      // Update backend
      try {
        await _userService.updateUserProfile(profileData);
        print('✅ Seller profile updated successfully on backend');
      } catch (e) {
        print('⚠️ Error updating seller profile on backend: $e');
        // Continue to save locally even if backend fails
      }
      
      // Update local storage
      await prefs.setString('user_name', _nameController.text);
      await prefs.setString('user_email', _emailController.text);
      await prefs.setString('business_name', _businessNameController.text);
      await prefs.setString('business_address', _businessAddressController.text);
      await prefs.setString('business_phone', _businessPhoneController.text);
      await prefs.setString('tax_id', _taxIdController.text);
      await prefs.setString('business_description', _businessDescriptionController.text);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveBusinessHours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('business_hours', jsonEncode(_businessHours));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Business hours saved'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving business hours: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _savePaymentSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('payout_method', _payoutMethod);
      await prefs.setString('bank_name', _bankNameController.text);
      await prefs.setString('account_number', _accountNumberController.text);
      await prefs.setString('routing_number', _routingNumberController.text);
      await prefs.setString('account_holder_name', _accountHolderNameController.text);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payment settings saved'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveListingPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('default_starting_bid', _defaultStartingBid);
      await prefs.setInt('default_auction_duration', _defaultAuctionDuration);
      await prefs.setBool('auto_approve_bids', _autoApproveBids);
      await prefs.setBool('require_inspections', _requireInspections);
      await prefs.setBool('allow_counter_offers', _allowCounterOffers);
      await prefs.setString('default_payment_terms', _defaultPaymentTerms);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Listing preferences saved'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving preferences: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTimePickerDialog(String day, String type) {
    showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    ).then((time) {
      if (time != null) {
        setState(() {
          final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          _businessHours[day]![type] = timeStr;
        });
        _saveBusinessHours();
      }
    });
  }
  
  Widget _buildAccountInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
                      style: TextStyle(
                        fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.textMedium : 14.0,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.textMedium : 14.0,
              fontWeight: FontWeight.w500,
              color: kBlackColor,
            ),
          ),
        ),
      ],
    );
  }
  
  String _formatAccountDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) {
      return 'N/A';
    }
    try {
      final date = DateTime.parse(dateStr.toString());
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr.toString();
    }
  }
  
  String _formatRole(dynamic role) {
    if (role == null || role.toString().isEmpty) {
      return 'User';
    }
    final roleStr = role.toString().toLowerCase();
    if (roleStr == 'seller/buyer') {
      return 'Seller/Buyer';
    }
    return roleStr.split('/').map((r) => r[0].toUpperCase() + r.substring(1)).join('/');
  }
}

