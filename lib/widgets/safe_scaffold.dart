import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:carauction/utils/responsive_helper.dart';

/// A safe scaffold that automatically handles overflow and responsive design
/// Works perfectly on both Android and iOS
class SafeScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool enableScroll;

  const SafeScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.enableScroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    
    // iOS-specific SafeArea handling
    final safeAreaChild = isIOS
        ? SafeArea(
            top: true,
            bottom: true,
            left: true,
            right: true,
            child: enableScroll
                ? ResponsiveHelper.safeScrollable(
                    context: context,
                    child: body,
                  )
                : body,
          )
        : SafeArea(
            child: enableScroll
                ? ResponsiveHelper.safeScrollable(
                    context: context,
                    child: body,
                  )
                : body,
          );

    // Use CupertinoPageScaffold for iOS, Material Scaffold for Android
    if (isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor ?? CupertinoColors.systemBackground,
        navigationBar: appBar != null
            ? CupertinoNavigationBar(
                middle: appBar is AppBar ? (appBar as AppBar).title : null,
                backgroundColor: backgroundColor ?? CupertinoColors.systemBackground,
              )
            : null,
        child: Scaffold(
          backgroundColor: Colors.transparent, // Make it transparent
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          body: Material( // <--- Added Material widget here
            color: Colors.transparent, // Make it transparent to avoid visual changes
            child: safeAreaChild,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.white,
      appBar: appBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButton != null 
          ? FloatingActionButtonLocation.endFloat 
          : null,
      bottomNavigationBar: bottomNavigationBar,
      body: safeAreaChild,
    );
  }
}

/// A safe container that prevents overflow
/// Works perfectly on both Android and iOS
class SafeContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double? width;
  final double? height;
  final double? borderRadius;
  final BoxDecoration? decoration;
  final Alignment? alignment;

  const SafeContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.width,
    this.height,
    this.borderRadius,
    this.decoration,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    
    // iOS uses different border radius style
    final borderRadiusValue = borderRadius ?? 
        (isIOS ? 8.0 : ResponsiveHelper.borderRadius(context));
    
    Widget container = Container(
      width: width != null && width != double.infinity ? width : null,
      height: height,
      padding: padding ?? ResponsiveHelper.safePadding(context),
      margin: margin ?? ResponsiveHelper.safeMargin(context),
      alignment: alignment,
      decoration: decoration ??
          (color != null || borderRadius != null
              ? BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(borderRadiusValue),
                )
              : null),
      child: child,
    );
    
    // If width is explicitly set to infinity, wrap with ConstrainedBox to handle unbounded constraints
    if (width == double.infinity) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 0, maxWidth: double.infinity),
        child: container,
      );
    }
    
    return container;
  }
}

/// A responsive column that prevents overflow
class SafeColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const SafeColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SafeContainer(
      padding: padding,
      margin: margin,
      child: Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children.map((child) {
          // Only wrap in Flexible if child doesn't already have flex properties
          // Check if child is Expanded, Flexible, or Spacer
          if (child is Expanded || child is Flexible || child is Spacer) {
            return child; // Don't wrap, use as-is
          }
          // Wrap other children to prevent overflow
          return Flexible(
            fit: FlexFit.loose, // Use loose fit to allow children to size themselves
            child: child,
          );
        }).toList(),
      ),
    );
  }
}

/// A responsive row that prevents overflow
class SafeRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const SafeRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.min,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SafeContainer(
      padding: padding,
      margin: margin,
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children.map((child) {
          // Only wrap in Flexible if child doesn't already have flex properties
          // Check if child is Expanded, Flexible, or Spacer
          if (child is Expanded || child is Flexible || child is Spacer) {
            return child; // Don't wrap, use as-is
          }
          // Wrap other children to prevent overflow
          return Flexible(
            fit: FlexFit.loose, // Use loose fit to allow children to size themselves
            child: child,
          );
        }).toList(),
      ),
    );
  }
}

