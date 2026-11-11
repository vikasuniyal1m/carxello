import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:carauction/utils/app_constants.dart';

enum EmptyStateType {
  emptyCars,
  emptyBids,
  emptyNotifications,
  emptyListings,
  emptyInventory,
  pending,
  loading,
  emptyPurchaseHistory,
  emptyWonVehicles,
  emptySavedSearches,
  emptyWatchlist,
  emptyTransport,
  emptyInspection,
}

class EmptyStateWidget extends StatelessWidget {
  final EmptyStateType type;
  final String title;
  final String? message;
  final Widget? actionButton;

  const EmptyStateWidget({
    super.key,
    required this.type,
    required this.title,
    this.message,
    this.actionButton,
  });

  String _getLottiePath() {
    switch (type) {
      case EmptyStateType.emptyCars:
        return 'assets/lottie/empty_cars.json';
      case EmptyStateType.emptyBids:
        return 'assets/lottie/empty_bids.json';
      case EmptyStateType.emptyNotifications:
        return 'assets/lottie/empty_notifications.json';
      case EmptyStateType.emptyListings:
        return 'assets/lottie/empty_listings.json';
      case EmptyStateType.emptyInventory:
        return 'assets/lottie/empty_inventory.json';
      case EmptyStateType.pending:
        return 'assets/lottie/pending.json';
      case EmptyStateType.loading:
        return 'assets/lottie/loading.json';
      case EmptyStateType.emptyPurchaseHistory:
        return 'assets/lottie/empty_purchase_history.json';
      case EmptyStateType.emptyWonVehicles:
        return 'assets/lottie/empty_won_vehicles.json';
      case EmptyStateType.emptySavedSearches:
        return 'assets/lottie/empty_saved_searches.json';
      case EmptyStateType.emptyWatchlist:
        return 'assets/lottie/empty_watchlist.json';
      case EmptyStateType.emptyTransport:
        return 'assets/lottie/empty_transport.json';
      case EmptyStateType.emptyInspection:
        return 'assets/lottie/empty_inspection.json';
    }
  }

  IconData _getFallbackIcon() {
    switch (type) {
      case EmptyStateType.emptyCars:
        return Icons.directions_car_outlined;
      case EmptyStateType.emptyWonVehicles:
        return Icons.emoji_events;
      case EmptyStateType.emptyPurchaseHistory:
        return Icons.shopping_bag;
      case EmptyStateType.emptyBids:
        return Icons.gavel;
      case EmptyStateType.emptyNotifications:
        return Icons.notifications_none_rounded;
      case EmptyStateType.emptyListings:
        return Icons.description_outlined;
      case EmptyStateType.emptySavedSearches:
        return Icons.search;
      case EmptyStateType.emptyWatchlist:
        return Icons.favorite_border;
      case EmptyStateType.emptyTransport:
        return Icons.local_shipping_outlined;
      case EmptyStateType.emptyInspection:
        return Icons.search_outlined;
      case EmptyStateType.emptyInventory:
        return Icons.inventory_2_outlined;
      case EmptyStateType.pending:
        return Icons.hourglass_empty;
      case EmptyStateType.loading:
        return Icons.refresh;
    }
  }

  Color _getIconColor() {
    switch (type) {
      case EmptyStateType.pending:
        return Colors.orange;
      case EmptyStateType.loading:
        return kAccentColor;
      case EmptyStateType.emptyWonVehicles:
        return kAccentColor;
      case EmptyStateType.emptyPurchaseHistory:
        return kAccentColor;
      case EmptyStateType.emptySavedSearches:
        return kAccentColor;
      case EmptyStateType.emptyWatchlist:
        return Colors.red;
      case EmptyStateType.emptyTransport:
        return Colors.blue;
      default:
        return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Container with Gradient Background
            // Container(
            //   height: 100,
            //   width: 100,
            //   decoration: BoxDecoration(
            //     shape: BoxShape.circle,
            //     gradient: RadialGradient(
            //       colors: [
            //         kAccentColor.withOpacity(0.2),
            //         kAccentColor.withOpacity(0.05),
            //         Colors.transparent,
            //       ],
            //       stops: const [0.0, 0.7, 1.0],
            //     ),
            //   ),
            //   child: Stack(
            //     alignment: Alignment.center,
            //     children: [
            //       // Lottie Animation
            //       SizedBox(
            //         height: 200,
            //         width: 200,
            //         child: Lottie.asset(
            //           _getLottiePath(),
            //           fit: BoxFit.contain,
            //           repeat: true,
            //           errorBuilder: (context, error, stackTrace) {
            //             // Enhanced fallback with theme colors
            //             return Container(
            //               padding: const EdgeInsets.all(32),
            //               decoration: BoxDecoration(
            //                 gradient: RadialGradient(
            //                   colors: [
            //                     _getIconColor().withOpacity(0.2),
            //                     _getIconColor().withOpacity(0.05),
            //                   ],
            //                 ),
            //                 shape: BoxShape.circle,
            //                 border: Border.all(
            //                   color: _getIconColor().withOpacity(0.3),
            //                   width: 2,
            //                 ),
            //               ),
            //               child: Icon(
            //                 _getFallbackIcon(),
            //                 size: 72,
            //                 color: _getIconColor(),
            //               ),
            //             );
            //           },
            //         ),
            //       ),
            //       // Pulsing ring effect for loading/pending states
            //       if (type == EmptyStateType.loading || type == EmptyStateType.pending)
            //         _PulsingRing(),
            //     ],
            //   ),
            // ),
            const SizedBox(height: 24),
            // Title with gradient text effect
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  kAccentColor,
                  kAccentColor.withOpacity(0.7),
                  Colors.grey[800]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // Message
            if (message != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kAccentColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                  ),
                ),
              ),
            ],
            // Action Button
            if (actionButton != null) ...[
              const SizedBox(height: 20),
              actionButton!,
            ],
          ],
        ),
      ),
    );
  }
}

class _PulsingRing extends StatefulWidget {
  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: 200 + (_animation.value * 30),
          width: 200 + (_animation.value * 30),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: kAccentColor.withOpacity(0.3 * (1 - _animation.value)),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

