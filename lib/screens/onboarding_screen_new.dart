import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/diagonal_clipper.dart';

class OnboardingScreenNew extends StatelessWidget {
  const OnboardingScreenNew({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: kPrimaryColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Car image covering the top 48% of the screen
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.48,
              child: Image.asset(
                'assets/images/onboarding_car_interior.png',
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            // Yellow diagonal strip with main heading text
            Positioned(
              top: screenHeight * 0.4, // Starts at 40% from the top
              left: 0,
              right: 0,
              height: screenHeight * 0.3, // Height of the yellow strip
              child: ClipPath(
                clipper: DiagonalClipper(),
                child: Container(
                  color: kAccentColor, // Yellow strip color
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Fast, Easy, And\nReliable Car Auctions!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kWhiteColor, // Text color white for visibility on yellow
                          fontSize: getResponsiveFontSize(context, baseFontSize: kHeadingFontSize * 1.4),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom section with descriptive text, button, and sign-in text
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.3, // Bottom 30% of the screen
              child: Container(
                decoration: BoxDecoration(
                  color: kPrimaryColor, // Black background for this section
                  image: const DecorationImage(
                    image: AssetImage('assets/images/arrows_pattern.png'), // Background pattern
                    fit: BoxFit.cover,
                    opacity: 0.1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: kSizedBoxHeight * 2), // Spacing from the top of this section
                    Expanded(
                      child: Text(
                        'Get Behind The Wheel In Minutes With\nOur Seamless Booking Process',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kWhiteColor.withValues(alpha: 0.7), // White text for visibility on black
                          fontSize: getResponsiveFontSize(context, baseFontSize: kBodyFontSize),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: kSizedBoxHeight * 4), // Spacing before button
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to the next screen (e.g., login/registration)
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor, // Yellow button background
                        padding: const EdgeInsets.symmetric(horizontal: kPadding * 4, vertical: kPadding),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kBorderRadius),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Get Started App',
                            style: TextStyle(
                              color: kBlackColor, // Black text for visibility on yellow
                              fontSize: getResponsiveFontSize(context, baseFontSize: kSubHeadingFontSize),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: kPadding / 2),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: kBlackColor, // Black icon for visibility on yellow
                            size: getResponsiveFontSize(context, baseFontSize: kSubHeadingFontSize),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: kSizedBoxHeight),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: kPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have account?',
                            style: TextStyle(
                              color: kWhiteColor.withValues(alpha: 0.7), // White text for visibility on black
                              fontSize: getResponsiveFontSize(context, baseFontSize: kBodyFontSize),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // TODO: Navigate to sign in screen
                            },
                            child: Text(
                              'Sign in',
                              style: TextStyle(
                                color: kAccentColor, // Yellow text for "Sign in"
                                fontSize: getResponsiveFontSize(context, baseFontSize: kBodyFontSize),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}