import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carauction/utils/responsive_helper.dart';

class AuctionCountdownWidget extends StatefulWidget {
  final DateTime auctionEndTime;
  final bool isCompact;
  final String? prefixText;
  final bool showIcon;

  const AuctionCountdownWidget({
    super.key,
    required this.auctionEndTime,
    this.isCompact = false,
    this.prefixText,
    this.showIcon = true,
  });

  @override
  State<AuctionCountdownWidget> createState() => _AuctionCountdownWidgetState();
}

class _AuctionCountdownWidgetState extends State<AuctionCountdownWidget> {
  Timer? _timer;
  String _timeRemaining = '';

  @override
  void initState() {
    super.initState();
    _updateTimeRemaining();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateTimeRemaining();
        });
      }
    });
  }

  void _updateTimeRemaining() {
    final difference = widget.auctionEndTime.difference(DateTime.now());
    if (difference.isNegative) {
      _timeRemaining = 'Ended';
    } else {
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;
      
      if (widget.isCompact) {
        // Compact format for cards
        if (days > 0) {
          _timeRemaining = '${days}d ${hours}h';
        } else if (hours > 0) {
          _timeRemaining = '${hours}h ${minutes}m';
        } else if (minutes > 0) {
          _timeRemaining = '${minutes}m ${seconds}s';
        } else {
          _timeRemaining = '${seconds}s';
        }
      } else {
        // Full format
        if (days > 0) {
          _timeRemaining = '${days}d ${hours}h ${minutes}m ${seconds}s';
        } else if (hours > 0) {
          _timeRemaining = '${hours}h ${minutes}m ${seconds}s';
        } else if (minutes > 0) {
          _timeRemaining = '${minutes}m ${seconds}s';
        } else {
          _timeRemaining = '${seconds}s';
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveHelper.isTabletOrIPad(context);
    
    if (widget.isCompact) {
      final children = <Widget>[];
      
      if (widget.showIcon) {
        children.add(
          Icon(
            Icons.timelapse,
            size: isTablet 
              ? ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, iPad: 18, largeTablet: 20)
              : ResponsiveHelper.iconSize(context, mobile: 14),
            color: Colors.orange[700],
          ),
        );
        children.add(SizedBox(width: isTablet ? 6 : 4));
      }
      
      if (widget.prefixText != null) {
        children.add(
          Text(
            widget.prefixText!,
            style: ResponsiveHelper.captionStyle(context).copyWith(
              fontSize: isTablet 
                ? ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, iPad: 12, largeTablet: 13)
                : ResponsiveHelper.fontSize(context, mobile: 10),
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        );
      }
      
      children.add(
        Text(
          _timeRemaining,
          style: ResponsiveHelper.captionStyle(context).copyWith(
            fontSize: isTablet 
              ? ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, iPad: 12, largeTablet: 13)
              : ResponsiveHelper.fontSize(context, mobile: 10),
            fontWeight: FontWeight.w600,
            color: widget.prefixText != null ? Colors.orange[300] : Colors.orange[700],
          ),
        ),
      );
      
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    } else {
      return Text(
        _timeRemaining,
        style: ResponsiveHelper.textStyle(
          context,
          fontSize: ResponsiveHelper.fontSize(
            context,
            mobile: 18,
            tablet: 20,
            iPad: 20,
            largeTablet: 22,
            desktop: 22,
          ),
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      );
    }
  }
}


