import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carauction/utils/app_constants.dart';
import 'package:carauction/utils/preferences_helper.dart';
import 'package:carauction/services/chat_service.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserId;
  final String? currentUserId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserId,
    this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  Map<String, dynamic>? _conversation;
  bool _isLoading = false;
  bool _blockedSelfChat = false;
  Timer? _messagePollTimer; // Timer for real-time message polling
  Timer? _uiRefreshTimer; // Timer to refresh "ago" labels
  int _lastMessageCount = 0; // Track last message count for auto-scroll

  String? _currentUserId; // Store current user ID

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.currentUserId;
    _bootstrapChat();
  }

  Future<void> _bootstrapChat() async {
    await _loadCurrentUserIdIfNeeded();
    final other = widget.otherUserId?.trim();
    final me = _currentUserId?.trim();
    
    // Self-chat prevention
    if (other != null &&
        other.isNotEmpty &&
        me != null &&
        me.isNotEmpty &&
        other == me) {
      if (!mounted) return;
      setState(() {
        _blockedSelfChat = true;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot chat with yourself.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      });
      return;
    }
    
    await _loadMessages();
    _startMessagePolling();
    _startUiRefreshTimer();
  }

  void _startUiRefreshTimer() {
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _messages.isNotEmpty) {
        setState(() {}); // Force rebuild to update "relative" labels
      }
    });
  }

  Future<void> _loadCurrentUserIdIfNeeded() async {
    if (_currentUserId == null) {
      _currentUserId = await PreferencesHelper.getUserId();
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _messagePollTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startMessagePolling() {
    _messagePollTimer?.cancel();
    _messagePollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _pollForNewMessages();
      }
    });
  }

  Future<void> _pollForNewMessages() async {
    try {
      final response = await _chatService.getMessages(widget.conversationId);
      final messages = response['messages'] as List<dynamic>? ?? [];
      if (messages.length != _lastMessageCount) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _lastMessageCount = messages.length;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error polling messages: $e');
    }
  }

  Future<void> _loadMessages({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() => _isLoading = true);
    }
    try {
      final response = await _chatService.getMessages(widget.conversationId);
      final messages = response['messages'] as List<dynamic>? ?? [];
      final conversation = response['conversation'] as Map<String, dynamic>?;
      
      if (mounted) {
        setState(() {
          _messages = messages; 
          _conversation = conversation;
          _isLoading = false;
        });
        _lastMessageCount = _messages.length;
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (!isBackground) _messages = [];
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_blockedSelfChat) return;
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      FocusScope.of(context).unfocus(); // Auto close keyboard
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        message: messageText,
      );
      _loadMessages(isBackground: true); // Update messages without showing spinner
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: ${e.toString()}')),
        );
      }
      _messageController.text = messageText;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showInfoDialog() {
    final otherUser = _conversation?['other_user'] as Map<String, dynamic>?;
    final vehicle = _conversation?['vehicle'] as Map<String, dynamic>?;
    final isVerified = otherUser?['is_verified'] == true || otherUser?['is_verified'] == 1;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Profile Background
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                decoration: BoxDecoration(
                  color: kAccentColor.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: kAccentColor.withOpacity(0.1),
                      backgroundImage: otherUser?['profile_image'] != null 
                        ? NetworkImage(otherUser!['profile_image']) 
                        : null,
                      child: otherUser?['profile_image'] == null
                        ? Text(
                            widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : 'U',
                            style: const TextStyle(color: kAccentColor, fontWeight: FontWeight.bold, fontSize: 32),
                          )
                        : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            widget.otherUserName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Colors.blue, size: 20),
                        ],
                      ],
                    ),
                    if (otherUser?['role'] != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: kAccentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          otherUser!['role'].toString().toUpperCase(),
                          style: const TextStyle(color: kAccentColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CONTACT INFORMATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.email_outlined, 'Email Address', otherUser?['email'] ?? 'N/A'),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.phone_outlined, 'Phone Number', otherUser?['phone'] ?? 'N/A'),
                    
                    if (otherUser?['company_name'] != null && otherUser!['company_name'].toString().isNotEmpty) ...[
                      const Divider(height: 32),
                      const Text('BUSINESS DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.business_outlined, 'Company', otherUser['company_name']),
                      if (otherUser['license_number'] != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.badge_outlined, 'License No.', otherUser['license_number']),
                      ],
                    ],
                    
                    if (otherUser?['address'] != null || otherUser?['city'] != null) ...[
                      const Divider(height: 32),
                      const Text('LOCATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.location_on_outlined, 'Address', [
                        otherUser?['address'],
                        otherUser?['city'],
                        otherUser?['state'],
                        otherUser?['zip_code'],
                      ].where((e) => e != null && e.toString().isNotEmpty).join(', ')),
                    ],
                    
                    if (vehicle != null) ...[
                      const Divider(height: 32),
                      const Text('RE: VEHICLE CONTEXT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.directions_car_outlined, 'Interested In', 
                        '${vehicle['year'] ?? ''} ${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim()),
                      if (vehicle['vin'] != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.tag, 'VIN', vehicle['vin']),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: kAccentColor.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _conversation?['vehicle'] as Map<String, dynamic>?;
    final vehicleName = vehicle != null 
        ? '${vehicle['year'] ?? ''} ${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim()
        : null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: kBlackColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: kAccentColor.withOpacity(0.1),
              child: Text(
                widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                style: const TextStyle(color: kAccentColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kBlackColor),
                  ),
                  if (vehicleName != null && vehicleName.isNotEmpty)
                    Text(
                      vehicleName,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w400),
                    )
                  else
                    const Text(
                      'Online', 
                      style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.grey),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _blockedSelfChat
                ? const SizedBox.shrink()
                : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Start conversation with ${widget.otherUserName}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final sender = message['sender'] as Map<String, dynamic>?;
                          final senderId = sender?['id']?.toString() ?? '';
                          final currentUserId = _currentUserId ?? widget.currentUserId;
                          final isMe = currentUserId != null && senderId == currentUserId;
                          
                          final messageText = message['message']?.toString() ?? '';
                          final showDate = index == 0 || _shouldShowDate(index);
                          
                          return Column(
                            children: [
                              if (showDate) _buildDateHeader(message['sent_at'] ?? message['created_at']),
                              Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isMe ? kAccentColor : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                                      bottomRight: Radius.circular(isMe ? 4 : 16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (messageText.isNotEmpty)
                                        Text(
                                          messageText,
                                          style: TextStyle(
                                            color: isMe ? Colors.white : kBlackColor,
                                            fontSize: 15,
                                            height: 1.4,
                                          ),
                                        ),
                                      if (message['attachment_url'] != null) ...[
                                        if (messageText.isNotEmpty) const SizedBox(height: 8),
                                        _buildAttachment(message, isMe),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            _formatTimeOnly(message['sent_at'] ?? message['created_at']),
                                            style: TextStyle(
                                              color: isMe ? Colors.white70 : Colors.grey[500],
                                              fontSize: 10,
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.done_all,
                                              size: 14,
                                              color: message['is_read'] == true ? Colors.blue[200] : Colors.white60,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  bool _shouldShowDate(int index) {
    if (index == 0) return true;
    try {
      final currentIso = _messages[index]['sent_at'] ?? _messages[index]['created_at'];
      final previousIso = _messages[index - 1]['sent_at'] ?? _messages[index - 1]['created_at'];
      if (currentIso == null || previousIso == null) return false;
      
      final current = DateTime.parse(currentIso);
      final previous = DateTime.parse(previousIso);
      return current.day != previous.day || current.month != previous.month || current.year != previous.year;
    } catch (_) {
      return false;
    }
  }

  Widget _buildDateHeader(String? isoString) {
    if (isoString == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            _formatDateHeader(isoString),
            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachment(dynamic message, bool isMe) {
    return InkWell(
      onTap: () {
        // Attachment view logic
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white12 : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, size: 20, color: isMe ? Colors.white : kAccentColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message['attachment_name'] ?? 'File Attachment',
                style: TextStyle(
                  color: isMe ? Colors.white : kAccentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
            onPressed: () {
              // Attachment selection logic
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type message...',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: kAccentColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateHeader(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toUtc().subtract(const Duration(hours: 5));
      final now = DateTime.now().toUtc().subtract(const Duration(hours: 5));
      
      if (dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year) {
        return 'Today';
      }
      
      final yesterday = now.subtract(const Duration(days: 1));
      if (dateTime.day == yesterday.day && dateTime.month == yesterday.month && dateTime.year == yesterday.year) {
        return 'Yesterday';
      }
      
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (_) { 
      return ''; 
    }
  }

  String _formatTimeOnly(String? isoString) {
    if (isoString == null) return '';
    try {
      final dateRaw = DateTime.parse(isoString);
      final dateUtc = dateRaw.isUtc ? dateRaw : dateRaw.toUtc();
      final date = dateUtc.subtract(const Duration(hours: 5));
      final now = DateTime.now().toUtc().subtract(const Duration(hours: 5));
      final diff = now.difference(date);

      if (diff.inSeconds < 0) return 'Just now'; 
      if (diff.inSeconds < 15) return 'Just now';
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24 && date.day == now.day) return DateFormat('h:mm a').format(date);
      
      return DateFormat('h:mm a').format(date); 
    } catch (_) { 
      return ''; 
    }
  }
}
