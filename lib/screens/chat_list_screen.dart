import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carauction/services/chat_service.dart';
import 'package:intl/intl.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/responsive_helper.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:carauction/widgets/safe_scaffold.dart';
import 'package:carauction/screens/chat_screen.dart';
import 'package:carauction/models/car.dart';
import 'package:carauction/services/car_service.dart';
import 'package:carauction/screens/product_details_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final CarService _carService = CarService();

  List<dynamic> _conversations = [];
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;
  Timer? _refreshTimer;
  Timer? _uiRefreshTimer; // Timer to refresh "ago" labels

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadConversations();
    _startRefreshTimer();
    _startUiRefreshTimer();
  }

  void _startUiRefreshTimer() {
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _conversations.isNotEmpty) {
        setState(() {}); // Force rebuild to update "ago" labels
      }
    });
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !_isLoading) {
        _loadConversations(isBackground: true);
      }
    });
  }

  Future<void> _loadCurrentUserId() async {
    _currentUserId = await PreferencesHelper.getUserId();
    print('💬 ChatListScreen: Current User ID: $_currentUserId');
  }

  Future<void> _loadConversations({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await _chatService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = response['conversations'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!isBackground && mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
      print('❌ Error loading conversations: $e');
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'No messages';

    try {
      // Parse and convert to UTC to ensure consistency
      final dateRaw = DateTime.parse(dateString);
      final dateUtc = dateRaw.isUtc ? dateRaw : dateRaw.toUtc();
      
      // Convert to US Eastern Time (UTC-5)
      final date = dateUtc.subtract(const Duration(hours: 5));
      final now = DateTime.now().toUtc().subtract(const Duration(hours: 5));
      final difference = now.difference(date);

      if (difference.inSeconds < 0) return 'Just now';
      if (difference.inSeconds < 15) return 'Just now';
      if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      
      if (difference.inDays == 0) {
        return DateFormat('h:mm a').format(date); // Today
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat('EEEE').format(date); // Within week
      } else {
        return DateFormat('MMM dd, yyyy').format(date); // Older
      }
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _navigateToVehicle(String? vehicleId) async {
    if (vehicleId == null || vehicleId.isEmpty) return;

    try {
      final vehicle = await _carService.getVehicleById(vehicleId);
      if (vehicle != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(car: vehicle),
          ),
        );
      }
    } catch (e) {
      print('⚠️ Error loading vehicle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load vehicle details: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      enableScroll: false,
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConversations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load conversations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadConversations,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _conversations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No Messages Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When buyers contact you about your listings,\nconversations will appear here',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadConversations,
              color: kAccentColor,
              child: ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: _conversations.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                itemBuilder: (context, index) {
                  final conv = _conversations[index];
                  final otherUser = conv['other_user'] as Map<String, dynamic>?;
                  final lastMessage = conv['last_message'] as Map<String, dynamic>?;
                  final unreadCount = conv['unread_count'] as int? ?? 0;
                  final vehicleId = conv['vehicle_id']?.toString();

                  if (otherUser == null) return const SizedBox.shrink();

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: kAccentColor.withOpacity(0.1),
                          child: Text(
                            (otherUser['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: kAccentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: kAccentColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUser['name'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                              color: kBlackColor,
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(lastMessage?['created_at'] as String?),
                          style: TextStyle(
                            fontSize: 12,
                            color: unreadCount > 0 ? kAccentColor : Colors.grey[500],
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage?['message'] as String? ?? 'No messages yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: unreadCount > 0 ? kBlackColor : Colors.grey[600],
                                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (vehicleId != null)
                            Icon(
                              Icons.directions_car_filled,
                              size: 14,
                              color: Colors.blue[300],
                            ),
                        ],
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversationId: conv['id'].toString(),
                            otherUserName: otherUser['name'] ?? 'Unknown',
                            otherUserId: otherUser['id']?.toString(),
                            currentUserId: _currentUserId,
                          ),
                        ),
                      ).then((_) => _loadConversations());
                    },
                  );
                },
              ),
            ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _uiRefreshTimer?.cancel();
    super.dispose();
  }
}