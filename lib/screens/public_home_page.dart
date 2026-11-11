import 'package:flutter/material.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';

class PublicHomePage extends StatefulWidget {
  const PublicHomePage({super.key});

  @override
  State<PublicHomePage> createState() => _PublicHomePageState();
}

class _PublicHomePageState extends State<PublicHomePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      backgroundColor: Colors.white,
      enableScroll: true,
      appBar: AppBar(
        toolbarHeight: ResponsiveHelper.appBarHeight(context),
        title: Text(
          'Car Auction (Public)',
          style: ResponsiveHelper.headingStyle(context).copyWith(
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: ResponsiveHelper.safePadding(
            context,
            horizontal: 16,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recommended For You',
                    style: ResponsiveHelper.subheadingStyle(context).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Scroll to show all recommended items
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    child: Text(
                      'See all >',
                      style: ResponsiveHelper.bodyStyle(context).copyWith(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              ResponsiveHelper.sizedBoxHeight(context, 16),
              SizedBox(
                height: ResponsiveHelper.safeHeight(
                  context,
                  mobile: 200,
                  tablet: 240,
                  desktop: 280,
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5, // Placeholder for now
                  itemBuilder: (context, index) {
                    return _buildRecommendedCard(context, index);
                  },
                ),
              ),
              // Add more sections here if needed
              ResponsiveHelper.sizedBoxHeight(context, 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Padding(
                      padding: ResponsiveHelper.padding(context, right: 8),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement filter functionality
                        },
                        icon: Icon(
                          Icons.filter_list,
                          size: ResponsiveHelper.iconSize(context),
                        ),
                        label: Text(
                          'Filter',
                          style: ResponsiveHelper.bodyStyle(context),
                        ),
                        style: ResponsiveHelper.adaptiveButtonStyle(context),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: ResponsiveHelper.padding(context, left: 8),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement sort functionality
                        },
                        icon: Icon(
                          Icons.sort,
                          size: ResponsiveHelper.iconSize(context),
                        ),
                        label: Text(
                          'Sort',
                          style: ResponsiveHelper.bodyStyle(context),
                        ),
                        style: ResponsiveHelper.adaptiveButtonStyle(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedCard(BuildContext context, int index) {
    // Placeholder data for demonstration
    final List<Map<String, String>> categories = [
      {'title': 'SUV', 'items': '493 items', 'image': 'assets/images/suv.jpg'},
      {'title': 'Sports Car', 'items': '947 items', 'image': 'assets/images/sports_car.jpg'},
      {'title': 'Hatchback', 'items': '385 items', 'image': 'assets/images/hatchback.jpg'},
      {'title': 'Sedan', 'items': '600 items', 'image': 'assets/images/sedan.jpg'},
      {'title': 'Truck', 'items': '250 items', 'image': 'assets/images/truck.jpg'},
    ];

    final category = categories[index];

    return Card(
      margin: ResponsiveHelper.safeMargin(
        context,
        right: 16,
        top: 8,
        bottom: 8,
      ),
      elevation: ResponsiveHelper.elevation(context, mobile: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
        ),
      ),
      child: Container(
        width: ResponsiveHelper.safeWidth(
          context,
          mobile: 150,
          tablet: 180,
          desktop: 200,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16),
          ),
          image: DecorationImage(
            image: AssetImage(category['image']!),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(102), // Darken the image
              BlendMode.darken,
            ),
          ),
        ),
        child: Padding(
          padding: ResponsiveHelper.padding(context, all: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category['title']!,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ResponsiveHelper.sizedBoxHeight(context, 4),
              Text(
                category['items']!,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(
                    context,
                    mobile: 14,
                    tablet: 15,
                    desktop: 16,
                  ),
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}