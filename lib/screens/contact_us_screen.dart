import 'package:carauction/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/screen_size.dart';
import 'package:carauction/screens/home_page.dart';
import 'package:carauction/screens/about_us_screen.dart';
import 'package:carauction/screens/login_screen.dart';
import 'package:carauction/screens/inspector_dashboard_screen.dart';
import 'package:carauction/screens/transporter_dashboard_screen.dart';
import 'package:carauction/services/auth_service.dart';
import 'package:carauction/services/contact_service.dart';
import 'package:carauction/utils/drawer_menu.dart';
import 'package:carauction/controllers/home_page_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(text: '+1 012 3456 789');
  final _messageController = TextEditingController();
  String _selectedSubject = 'General Inquiry';
  bool _isSubmitting = false;
  final ContactService _contactService = ContactService();
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

  Future<void> _handleSubmitContactForm() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _contactService.sendContactForm(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        subject: _selectedSubject,
        message: _messageController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Message sent successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Clear form
        _firstNameController.clear();
        _lastNameController.clear();
        _emailController.clear();
        _phoneController.text = '+1 012 3456 789';
        _messageController.clear();
        setState(() {
          _selectedSubject = 'General Inquiry';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
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
          'Contact Us',
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
        selectedIndex: 0, // Home is selected by default when on Contact Us
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
                  height: MediaQuery.of(context).size.height * 0.35,
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
                    'Contact CarXello',
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
                  // How Can we Help You Section
                  Text(
                    'How Can we Help You ?',
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
                        child: _buildHelpCard(
                          icon: Icons.email,
                          text: 'Message Us Directly',
                        ),
                      ),
                      SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingSmall : 8.0),
                      Expanded(
                        child: _buildHelpCard(
                          icon: Icons.help_outline,
                          text: 'Help Center (FAQ)',
                        ),
                      ),
                      SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingSmall : 8.0),
                      Expanded(
                        child: _buildHelpCard(
                          icon: Icons.phone,
                          text: 'Call Hotline',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingExtraLarge : 40.0),
                  // Contact Information Section
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular((ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.borderRadiusLarge : 16.0),
                        child: Container(
                          height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? 320.0 : 280.0,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/car2.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.6),
                                  Colors.black.withValues(alpha: 0.9),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all((ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.paddingMedium : 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contact Information',
                              style: TextStyle(
                                color: kWhiteColor,
                                fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.headingSmall : 20.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingLarge : 24.0),
                            _buildContactInfoRow(Icons.phone, '+1 012 3456 789'),
                            SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                            _buildContactInfoRow(Icons.email, 'demo@gmail.com'),
                            SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                            _buildContactInfoRow(
                              Icons.location_on,
                              '132 Dartmouth Street Boston, Massachusetts 02156 United States',
                            ),
                            SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingLarge : 24.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSocialIcon(Icons.chat_bubble_outline, Colors.yellow),
                                SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                                _buildSocialIcon(Icons.camera_alt, Colors.white),
                                SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                                _buildSocialIcon(Icons.chat, Colors.yellow),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingExtraLarge : 40.0),
                  // Contact Form Section
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormTextField(
                          label: 'First Name',
                          controller: _firstNameController,
                          hint: 'John',
                        ),
                        SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                        _buildFormTextField(
                          label: 'Last Name',
                          controller: _lastNameController,
                          hint: 'Doe',
                        ),
                        SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                        _buildFormTextField(
                          label: 'Email',
                          controller: _emailController,
                          hint: 'email@example.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 16.0),
                        _buildFormTextField(
                          label: 'Phone Number',
                          controller: _phoneController,
                          hint: '+1 012 3456 789',
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingLarge : 24.0),
                        Text(
                          'Select Subject?',
                          style: TextStyle(
                            fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.headingSmall : 18.0,
                            fontWeight: FontWeight.bold,
                            color: kBlackColor,
                          ),
                        ),
                        SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 12.0),
                        Wrap(
                          spacing: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 12.0,
                          runSpacing: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 12.0,
                          children: [
                            _buildRadioOption('General Inquiry', 'General Inquiry'),
                            _buildRadioOption('Support', 'Support'),
                            _buildRadioOption('Sales', 'Sales'),
                            _buildRadioOption('Other', 'Other'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildFormTextField(
                          label: 'Message',
                          controller: _messageController,
                          hint: 'Write your message..',
                          maxLines: 4,
                        ),
                        SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingExtraLarge : 32.0),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                await _handleSubmitContactForm();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OnboardingScreen.accentYellow,
                              foregroundColor: kWhiteColor,
                              padding: EdgeInsets.symmetric(vertical: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.paddingMedium : 16.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular((ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.borderRadiusMedium : 12.0),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Send Message',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildHelpCard({required IconData icon, required String text}) {
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
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kWhiteColor, size: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconSmall : 20.0),
        SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingMedium : 12.0),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: kWhiteColor,
              fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.textMedium : 14.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, Color bgColor) {
    return Container(
      width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconLarge : 40.0,
      height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconLarge : 40.0,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: bgColor == Colors.white ? Border.all(color: Colors.grey, width: 1) : null,
      ),
      child: Icon(
        icon,
        color: bgColor == Colors.white ? kBlackColor : kWhiteColor,
        size: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconSmall : 20.0,
      ),
    );
  }

  Widget _buildFormTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.textMedium : 14.0,
            fontWeight: FontWeight.w600,
            color: kBlackColor,
          ),
        ),
        SizedBox(height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingSmall : 8.0),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: kLightGreyColor),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: kLightGreyColor),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: kAccentColor),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRadioOption(String value, String label) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubject = value;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconSmall : 20.0,
            height: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconSmall : 20.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _selectedSubject == value ? kAccentColor : Colors.grey,
                width: 2,
              ),
              color: _selectedSubject == value ? kAccentColor : Colors.transparent,
            ),
            child: _selectedSubject == value
                ? Icon(Icons.check, size: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.iconSmall * 0.7 : 14.0, color: kWhiteColor)
                : null,
          ),
          SizedBox(width: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.spacingSmall : 8.0),
          Text(
            label,
            style: TextStyle(
              fontSize: (ScreenSize.isLargeTablet || ScreenSize.isSmallTablet) ? ScreenSize.textMedium : 14.0,
              color: kBlackColor,
            ),
          ),
        ],
      ),
    );
  }

}
