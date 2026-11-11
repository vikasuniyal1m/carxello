import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../utils/api_config.dart';
import 'auth_service.dart';

/// WebSocket Service for Real-Time Updates
/// 
/// This service provides real-time bidirectional communication with the backend.
/// Falls back to polling if WebSocket connection fails.
class WebSocketService {
  static WebSocketService? _instance;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final AuthService _authService = AuthService();
  
  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  
  // Callbacks
  final Map<String, List<Function(Map<String, dynamic>)>> _listeners = {};
  
  // Reconnection
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  
  // App lifecycle state
  bool _isAppInBackground = false;
  
  WebSocketService._();
  
  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }
  
  /// Check if WebSocket is connected
  bool get isConnected => _isConnected && _channel != null;
  
  /// Set app background state (called from app lifecycle)
  void setAppBackgroundState(bool isInBackground) {
    _isAppInBackground = isInBackground;
    if (isInBackground) {
      // Pause ping timer when app goes to background
      _pingTimer?.cancel();
      print('⏸️ WebSocket: Ping paused (app in background)');
    } else {
      // Resume ping timer when app comes to foreground
      if (_isConnected) {
        _startPingTimer();
        print('▶️ WebSocket: Ping resumed (app in foreground)');
      }
    }
  }
  
  /// Get WebSocket URL from API config
  /// Note: WebSocket usually runs on a different port (6001) than HTTP API (8000)
  /// For production, WebSocket uses wss:// on the same domain (port 443, implicit)
  Uri _getWebSocketUri() {
    final baseUrl = ApiConfig.baseUrl;
    print('🔧 WebSocket: Base URL: $baseUrl');
    
    // Parse the base URL first
    try {
      final baseUri = Uri.parse(baseUrl);
      print('🔧 WebSocket: Parsed URI - scheme: ${baseUri.scheme}, host: ${baseUri.host}, port: ${baseUri.port}, hasPort: ${baseUri.hasPort}, path: ${baseUri.path}');
      
      // Determine WebSocket scheme
      String wsScheme;
      if (baseUri.scheme == 'https') {
        wsScheme = 'wss';
      } else if (baseUri.scheme == 'http') {
        wsScheme = 'ws';
      } else {
        wsScheme = baseUri.scheme;
      }
      
      // Get host
      String host = baseUri.host;
      
      // Determine port
      int? port;
      if (ApiConfig.websocketUseReverseProxy) {
        port = null;
      } else {
        port = ApiConfig.websocketPort;
      }
      
      // Remove /api from path if present
      String path = baseUri.path.replaceAll('/api', '');
      if (path.isEmpty) {
        path = '';
      }
      
      // Construct WebSocket URI
      return Uri(
        scheme: wsScheme,
        host: host,
        port: port,
        path: path.isEmpty ? null : path, // Path should be null if empty
      );
    } catch (e) {
      print('⚠️ WebSocket: Error parsing base URL: $e');
      // Fallback: simple string replacement
      String wsUrl = baseUrl;
      if (wsUrl.startsWith('https://')) {
        wsUrl = wsUrl.replaceFirst('https://', 'wss://');
      } else if (wsUrl.startsWith('http://')) {
        wsUrl = wsUrl.replaceFirst('http://', 'ws://');
      }
      wsUrl = wsUrl.replaceAll('/api', '');
      wsUrl = wsUrl.replaceAll(':8000', ':${ApiConfig.websocketPort}');
      // Remove any :0 port (invalid port)
      wsUrl = wsUrl.replaceAll(':0/', '/').replaceAll(':0?', '?').replaceAll(':0#', '#');
      if (wsUrl.endsWith(':0')) {
        wsUrl = wsUrl.substring(0, wsUrl.length - 2);
      }
      // For wss://, ensure no port is included (uses default 443)
      if (wsUrl.startsWith('wss://') && ApiConfig.websocketUseReverseProxy) {
        final uri = Uri.parse(wsUrl);
        if (uri.hasPort && uri.port == 0) {
          wsUrl = 'wss://${uri.host}${uri.path}${uri.query.isNotEmpty ? '?${uri.query}' : ''}';
        }
      }
      return Uri.parse(wsUrl);
    }
  }
  
  /// Connect to WebSocket server
  Future<bool> connect() async {
    if (_isConnected || _isConnecting) {
      return _isConnected;
    }
    
    _isConnecting = true;
    
    try {
      // Disable WebSocket in production when reverse proxy isn't configured
      if (ApiConfig.environment == 'production' && !ApiConfig.websocketUseReverseProxy) {
        print('⚠️ WebSocket: Disabled in production (no reverse proxy configured). Using polling fallback.');
        _isConnecting = false;
        return false;
      }

      final token = await _authService.getToken();
      if (token == null) {
        print('⚠️ WebSocket: No auth token available');
        _isConnecting = false;
        return false;
      }
      
      // Get WebSocket URI
      final baseWsUri = _getWebSocketUri();
      final wsUri = baseWsUri.replace(
        path: '${baseWsUri.path}/ws',
        queryParameters: {'token': token},
      );
      print('🔌 WebSocket: Connecting to $wsUri');
      
      _channel = WebSocketChannel.connect(wsUri);
      
      // Listen to messages
      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message as String) as Map<String, dynamic>;
            
            // Handle connection confirmation
            if (data['type'] == 'connected') {
              print('✅ WebSocket: Server connection confirmed');
              // Send authentication after connection
              _sendAuthMessage(token);
              return;
            }
            
            // Handle auth success
            if (data['type'] == 'auth_success') {
              print('✅ WebSocket: Authentication successful');
              _isConnected = true;
              _isConnecting = false;
              _reconnectAttempts = 0;
              _startPingTimer();
              return;
            }
            
            // Handle auth failure
            if (data['type'] == 'auth_failed') {
              print('❌ WebSocket: Authentication failed');
              _handleDisconnection();
              return;
            }
            
            _handleMessage(data);
          } catch (e) {
            print('⚠️ WebSocket: Error parsing message: $e');
          }
        },
        onError: (error) {
          print('❌ WebSocket: Error: $error');
          _handleDisconnection();
        },
        onDone: () {
          print('⚠️ WebSocket: Connection closed');
          _handleDisconnection();
        },
        cancelOnError: false,
      );
      
      // Don't set connected yet, wait for auth success
      _isConnecting = false;
      print('✅ WebSocket: Connection established, authenticating...');
      
      return true;
    } catch (e) {
      print('❌ WebSocket: Connection failed: $e');
      _isConnecting = false;
      
      // Check if it's a 404 (backend doesn't have WebSocket endpoint yet)
      final errorStr = e.toString();
      if (errorStr.contains('404') || errorStr.contains('not upgraded to websocket')) {
        print('⚠️ WebSocket: Backend WebSocket endpoint not available (404).');
        print('⚠️ WebSocket: This is expected if backend WebSocket server is not implemented yet.');
        print('⚠️ WebSocket: App will continue using polling for real-time updates.');
        print('📝 To enable WebSocket: Install Laravel WebSockets or Ratchet in backend');
        // Don't attempt reconnection if endpoint doesn't exist
        _reconnectAttempts = _maxReconnectAttempts; // Skip reconnection attempts
        _isConnecting = false;
        return false;
      }
      
      _handleDisconnection();
      return false;
    }
  }
  
  /// Disconnect from WebSocket server
  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close(status.normalClosure);
    _isConnected = false;
    _isConnecting = false;
    _channel = null;
    _subscription = null;
    print('🔌 WebSocket: Disconnected');
  }
  
  /// Handle disconnection and attempt reconnection
  void _handleDisconnection() {
    if (_isConnected) {
      _isConnected = false;
      _pingTimer?.cancel();
      
      // Attempt reconnection if not manually disconnected
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _reconnectAttempts++;
        print('🔄 WebSocket: Attempting reconnection ($_reconnectAttempts/$_maxReconnectAttempts)...');
        _reconnectTimer = Timer(_reconnectDelay, () {
          connect();
        });
      } else {
        print('❌ WebSocket: Max reconnection attempts reached');
      }
    }
  }
  
  /// Handle incoming messages
  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;
    
    // Notify all listeners for this message type
    final listeners = _listeners[type];
    if (listeners != null) {
      for (var listener in listeners) {
        try {
          listener(data);
        } catch (e) {
          print('⚠️ WebSocket: Error in listener: $e');
        }
      }
    }
    
    // Also notify 'all' listeners
    final allListeners = _listeners['all'];
    if (allListeners != null) {
      for (var listener in allListeners) {
        try {
          listener(data);
        } catch (e) {
          print('⚠️ WebSocket: Error in all listener: $e');
        }
      }
    }
  }
  
  /// Subscribe to a specific message type
  void subscribe(String type, Function(Map<String, dynamic>) callback) {
    _listeners.putIfAbsent(type, () => []).add(callback);
    print('📡 WebSocket: Subscribed to $type');
  }
  
  /// Unsubscribe from a message type
  void unsubscribe(String type, Function(Map<String, dynamic>) callback) {
    _listeners[type]?.remove(callback);
    if (_listeners[type]?.isEmpty ?? false) {
      _listeners.remove(type);
    }
  }
  
  /// Send authentication message
  void _sendAuthMessage(String token) {
    send({
      'type': 'auth',
      'token': token,
    });
  }
  
  /// Send message to server
  void send(Map<String, dynamic> data) {
    if (!_isConnected && data['type'] != 'auth') {
      print('⚠️ WebSocket: Cannot send, not connected');
      return;
    }
    
    try {
      _channel?.sink.add(json.encode(data));
    } catch (e) {
      print('❌ WebSocket: Error sending message: $e');
    }
  }
  
  // Ping timer to keep connection alive
  Timer? _pingTimer;
  
  void _startPingTimer() {
    _pingTimer?.cancel();
    // Don't start ping timer if app is in background
    if (_isAppInBackground) {
      return;
    }
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (isConnected && !_isAppInBackground) {
        send({'type': 'ping', 'timestamp': DateTime.now().toIso8601String()});
      } else {
        timer.cancel();
      }
    });
  }
  
  /// Dispose resources
  void dispose() {
    disconnect();
    _listeners.clear();
  }
}

