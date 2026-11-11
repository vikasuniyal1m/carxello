import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:carauction/controllers/notification_controller.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/screens/product_details_screen.dart';
import 'package:carauction/screens/billing_history_screen.dart';
import 'package:carauction/screens/transport_tracking_screen.dart';
import 'package:carauction/screens/my_bids_screen.dart';
import 'package:carauction/screens/seller_bid_management_screen.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/car_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carauction/widgets/empty_state_widget.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationController = Get.find<NotificationController>();
    final isCompact = MediaQuery.of(context).size.width < 380;

    return SafeScaffold(
      backgroundColor: Colors.grey[50],
      enableScroll: false, // Disable scroll wrapper since ListView handles scrolling
      appBar: AppBar(
        backgroundColor: kAccentColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Notifications',
          style: ResponsiveHelper.headingStyle(context).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Obx(() {
            final role = notificationController.currentRole.value;
            if (role.isEmpty) return const SizedBox.shrink();
            final roleLabel = _notificationRoleLabel(role);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.28)),
              ),
              child: Text(
                roleLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
          Obx(() => notificationController.unreadCount.value > 0
              ? isCompact
                  ? IconButton(
                      onPressed: () => notificationController.markAllAsRead(),
                      icon: const Icon(Icons.done_all, color: Colors.white),
                      tooltip: 'Mark all read',
                    )
                  : TextButton.icon(
                      onPressed: () => notificationController.markAllAsRead(),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text(
                        'Mark all read',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
              : const SizedBox.shrink()),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Obx(() {
            final showingUpcoming = notificationController.showUpcomingOnly.value;
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      label: 'All',
                      selected: !showingUpcoming,
                      onTap: () => notificationController.setShowUpcomingOnly(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Upcoming',
                      selected: showingUpcoming,
                      onTap: () => notificationController.setShowUpcomingOnly(true),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
      body: Obx(() {
        if (notificationController.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kAccentColor),
            ),
          );
        }

        final visibleNotifications = notificationController.visibleNotifications;

        if (visibleNotifications.isEmpty) {
          final role = notificationController.currentRole.value;
          final roleMessage = notificationController.showUpcomingOnly.value
              ? 'No upcoming notifications right now.\nNew scheduled updates will appear here.'
              : _roleBasedEmptyMessage(role);
          return EmptyStateWidget(
            type: EmptyStateType.emptyNotifications,
            title: 'No Notifications Yet',
            message: roleMessage,
          );
        }

        return RefreshIndicator(
          onRefresh: () => notificationController.fetchNotifications(),
          color: kAccentColor,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: visibleNotifications.length,
            itemBuilder: (context, index) {
              final notification = visibleNotifications[index];
              final isRead = notification['is_read'] == true;
              final type = notification['type'] as String? ?? 'general';
              final title = notification['title'] as String? ?? 'Notification';
              final message = notification['message'] as String? ?? '';
              final createdAt = notification['created_at'] as String?;
              
              return _buildNotificationCard(
                context,
                notificationController,
                notification,
                isRead,
                type,
                title,
                message,
                createdAt,
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? Colors.white : Colors.white.withOpacity(0.4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  String _roleBasedEmptyMessage(String role) {
    switch (role) {
      case 'buyer':
        return 'Buyer updates will appear here:\noutbid alerts, auction wins, and purchase confirmations.';
      case 'seller':
      case 'dealer':
        return 'Seller updates will appear here:\nnew bids, vehicle sold, and payment updates.';
      case 'inspector':
        return 'Inspector updates will appear here:\ninspection assignments, reschedules, and submissions.';
      case 'transporter':
        return 'Transport updates will appear here:\nassigned pickups, in-transit progress, and delivery updates.';
      // case 'seller/buyer':
      //   return 'Buyer and seller updates will appear here:\nbids, purchases, sold alerts, and payments.';
      default:
        return 'You\'ll see notifications here when you\nreceive role-based updates from the system.';
    }
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationController controller,
    Map<String, dynamic> notification,
    bool isRead,
    String type,
    String title,
    String message,
    String? createdAt,
  ) {
    final iconName = controller.getNotificationIcon(type);
    final notificationId = notification['id'].toString();

    return Dismissible(
      key: Key(notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        controller.deleteNotification(notificationId);
        print('✅ Notification deleted: $notificationId');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? Colors.grey.shade300 : Colors.grey.shade400,
            width: isRead ? 1 : 1.25,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!isRead) {
                controller.markAsRead(notificationId);
              }
              _handleNotificationTap(context, notification);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon with badge
                  Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _getIconFromName(iconName),
                          color: Colors.black87,
                          size: 26,
                        ),
                      ),
                      if (!isRead)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                  color: Colors.black,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'gavel':
        return Icons.gavel;
      case 'trending_down':
        return Icons.trending_down;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'check_circle':
        return Icons.check_circle;
      case 'swap_horiz':
        return Icons.swap_horiz;
      case 'check_circle_outline':
        return Icons.check_circle_outline;
      case 'schedule':
        return Icons.schedule;
      case 'directions_car':
        return Icons.directions_car;
      case 'search':
        return Icons.search;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'assignment':
        return Icons.assignment;
      // Seller notification icons
      case 'cancel':
        return Icons.cancel;
      case 'event_busy':
        return Icons.event_busy;
      case 'event_available':
        return Icons.event_available;
      case 'monetization_on':
        return Icons.monetization_on;
      case 'payment':
        return Icons.payment;
      case 'auction_finalized':
        return Icons.check_circle;
      case 'auction_won':
        return Icons.emoji_events;
      case 'assignment_late':
        return Icons.assignment_late;
      case 'assignment_ind':
        return Icons.assignment_ind;
      case 'fact_check':
        return Icons.fact_check;
      case 'update':
        return Icons.update;
      case 'inventory_2':
        return Icons.inventory_2;
      case 'schedule_send':
        return Icons.schedule_send;
      case 'task_alt':
        return Icons.task_alt;
      case 'cancel_schedule_send':
        return Icons.cancel_schedule_send;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[date.month - 1]} ${date.day}, ${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }

  void _handleNotificationTap(BuildContext context, Map<String, dynamic> notification) async {
    final type = notification['type'] as String? ?? 'general';
    final relatedType = notification['related_type'] as String?;
    final relatedId = notification['related_id'];
    final data = notification['data'] as Map<String, dynamic>?;

    print('🔔 Notification tapped: type=$type, relatedType=$relatedType, relatedId=$relatedId');

    // Handle different notification types
    try {
      // Transport-related notifications
      if (type.contains('transport') || type == 'transport_scheduled' || type == 'transport_update') {
        final vehicleId = data?['vehicle_id']?.toString() ?? relatedId?.toString();
        if (vehicleId != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransportTrackingScreen(vehicleId: vehicleId),
            ),
          );
          return;
        }
        // Fallback to billing history
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BillingHistoryScreen(),
            ),
          );
        }
        return;
      }

      // Purchase/Billing (do not route buyer "buy_now_accepted" here — that opens vehicle below)
      if (type.contains('purchase') || type.contains('payment') || type == 'vehicle_sold') {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BillingHistoryScreen(),
            ),
          );
        }
        return;
      }

      // Won auction — My Bids → Won tab (current user only; list loads via API)
      if (type == 'auction_won') {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyBidsScreen(initialTabIndex: 2),
            ),
          );
        }
        return;
      }

      // Seller-only: new bid on your listing / seller confirmation — NOT buyer "bid accepted"
      if ((type == 'bid_received' ||
              type == 'bid_accepted_seller' ||
              type == 'buy_now_accepted_seller') &&
          relatedType == 'vehicle') {
        final vehicleId = data?['vehicle_id']?.toString() ?? relatedId?.toString();
        if (vehicleId != null) {
          await _navigateToVehicleForBidManagement(context, vehicleId);
          return;
        }
      }

      // Buyer bid activity: open the vehicle with current session (never seller bid-management)
      const buyerVehicleDetailTypes = {
        'bid_accepted',
        'bid_rejected',
        'buy_now_accepted',
        'buy_now_rejected',
        'outbid',
        'bid_placed',
      };
      if (buyerVehicleDetailTypes.contains(type) && relatedType == 'vehicle') {
        final vehicleId = data?['vehicle_id']?.toString() ?? relatedId?.toString();
        if (vehicleId != null) {
          await _navigateToVehicle(context, vehicleId);
          return;
        }
      }

      // Swap offer notifications
      if (type.contains('swap')) {
        final vehicleId = data?['vehicle_id']?.toString() ?? relatedId?.toString();
        if (vehicleId != null) {
          await _navigateToVehicle(context, vehicleId);
          return;
        }
      }

      // Vehicle-related notifications (default)
      if (relatedType == 'vehicle' && relatedId != null) {
        final vehicleId = data?['vehicle_id']?.toString() ?? relatedId.toString();
        await _navigateToVehicle(context, vehicleId);
        return;
      }

      // Bid-related notifications - try to get vehicle ID
      if (relatedType == 'bid' && relatedId != null) {
        final vehicleId = data?['vehicle_id']?.toString();
        if (vehicleId != null) {
          await _navigateToVehicle(context, vehicleId);
          return;
        }
      }

      // My Bids fallback (no vehicle id in payload)
      if (buyerVehicleDetailTypes.contains(type)) {
        if (context.mounted) {
          final tab =
              (type == 'bid_accepted' || type == 'buy_now_accepted') ? 2 : 0;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyBidsScreen(initialTabIndex: tab),
            ),
          );
        }
        return;
      }

      // Default: Show message if no navigation available
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification: ${notification['title'] ?? 'Notification'}'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open notification: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Navigate to vehicle details page
  Future<void> _navigateToVehicle(BuildContext context, String vehicleId) async {
    try {
      final carService = CarService();
      print('🔍 Fetching vehicle by ID: $vehicleId');
      
      final car = await carService.getVehicleById(vehicleId);
      
      if (car != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(car: car),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle not found'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error fetching vehicle: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load vehicle: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Navigate to seller bid management for a vehicle
  Future<void> _navigateToVehicleForBidManagement(BuildContext context, String vehicleId) async {
    try {
      final carService = CarService();
      print('🔍 Fetching vehicle for bid management: $vehicleId');
      
      final car = await carService.getVehicleById(vehicleId);
      
      if (car != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SellerBidManagementScreen(vehicle: car),
          ),
        );
      } else if (context.mounted) {
        // Fallback to vehicle details if bid management not available
        await _navigateToVehicle(context, vehicleId);
      }
    } catch (e) {
      print('❌ Error fetching vehicle for bid management: $e');
      // Fallback to vehicle details
      await _navigateToVehicle(context, vehicleId);
    }
  }
}

/// Badge text for the logged-in role on the notifications screen.
String _notificationRoleLabel(String role) {
  switch (role.toLowerCase().trim()) {
    case 'buyer':
      return 'Buyer';
    case 'seller':
      return 'Seller';
    case 'dealer':
      return 'Dealer';
    // case 'seller/buyer':
    //   return 'Buyer & Seller';
    case 'transporter':
      return 'Transporter';
    case 'inspector':
      return 'Inspector';
    case 'individual':
      return 'Individual';
    default:
      if (role.isEmpty) return '';
      return '${role[0].toUpperCase()}${role.substring(1)}';
  }
}

