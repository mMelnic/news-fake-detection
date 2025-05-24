// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/html.dart';

// class WebSocketService {
//   WebSocketChannel? _channel;
//   final StreamController<List<dynamic>> _articlesController = StreamController<List<dynamic>>.broadcast();
//   final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
//   Timer? _reconnectTimer;
//   Timer? _heartbeatTimer;
//   String? _url;
//   bool _isConnected = false;
//   bool _manualClose = false;

//   // Public streams that UI can listen to
//   Stream<List<dynamic>> get articlesStream => _articlesController.stream;
//   Stream<bool> get connectionStream => _connectionController.stream;
//   bool get isConnected => _isConnected;

//   void connect(String url) {
//     if (_channel != null) {
//       _manualClose = true;
//       _channel!.sink.close();
//     }
    
//     _url = url;
//     _manualClose = false;
//     _connectToWebSocket(url);
    
//     // Setup heartbeat to keep connection alive
//     _heartbeatTimer?.cancel();
//     _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
//       if (_isConnected) {
//         sendMessage({'type': 'heartbeat'});
//       }
//     });
//   }

//   void _connectToWebSocket(String url) {
//     try {
//       debugPrint('Connecting to WebSocket: $url');
      
//       if (kIsWeb) {
//         _channel = HtmlWebSocketChannel.connect(url);
//       } else {
//         _channel = IOWebSocketChannel.connect(url);
//       }
      
//       _isConnected = true;
//       _connectionController.add(true);
      
//       _channel!.stream.listen(
//         (dynamic message) {
//           _handleMessage(message);
//         },
//         onDone: () {
//           debugPrint('WebSocket connection closed');
//           _isConnected = false;
//           _connectionController.add(false);
//           if (!_manualClose) {
//             _scheduleReconnect();
//           }
//         },
//         onError: (error) {
//           debugPrint('WebSocket error: $error');
//           _isConnected = false;
//           _connectionController.add(false);
//           if (!_manualClose) {
//             _scheduleReconnect();
//           }
//         },
//       );
      
//       // Request immediate updates
//       sendMessage({'type': 'get_updates'});
      
//     } catch (e) {
//       debugPrint('WebSocket connection error: $e');
//       _isConnected = false;
//       _connectionController.add(false);
//       _scheduleReconnect();
//     }
//   }

//   void _scheduleReconnect() {
//     if (_manualClose) return;
    
//     _reconnectTimer?.cancel();
//     _reconnectTimer = Timer(const Duration(seconds: 5), () {
//       if (_url != null && !_isConnected && !_manualClose) {
//         _connectToWebSocket(_url!);
//       }
//     });
//   }

//   void _handleMessage(dynamic message) {
//     try {
//       final data = jsonDecode(message);
      
//       if (data['type'] == 'article_update') {
//         // Single article update
//         _articlesController.add([data['article']]);
//       } else if (data['type'] == 'batch_update') {
//         // Multiple articles update
//         _articlesController.add(data['articles']);
//       } else if (data['type'] == 'article_updates') {
//         // Response to get_updates request
//         _articlesController.add(data['articles']);
//       }
//     } catch (e) {
//       debugPrint('Error handling WebSocket message: $e');
//     }
//   }

//   void sendMessage(Map<String, dynamic> message) {
//     if (_channel != null && _isConnected) {
//       _channel!.sink.add(jsonEncode(message));
//     }
//   }

//   void disconnect() {
//     _manualClose = true;
//     _reconnectTimer?.cancel();
//     _heartbeatTimer?.cancel();
//     _channel?.sink.close();
//     _isConnected = false;
//     _connectionController.add(false);
//   }

//   void dispose() {
//     disconnect();
//     _articlesController.close();
//     _connectionController.close();
//   }
// }