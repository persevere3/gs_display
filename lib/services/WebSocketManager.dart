import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

/// WebSocket 連接管理器
class WebSocketManager {
  // ==================== 配置常量 ====================
  final String hostname;
  final int port;
  final String token;

  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 5);
  static const Duration _connectionTimeout = Duration(seconds: 10);

  // ==================== 內部變數 ====================
  IOWebSocketChannel? _channel;
  io.WebSocket? _rawSocket;
  StreamSubscription? _streamSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  bool _isDisposed = false;
  bool _shouldReconnect = true;

  // ==================== 狀態流 ====================
  /// 連接狀態流（true = 已連接，false = 已斷開）
  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionStateController.stream;

  /// 錯誤訊息流
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  /// 接收訊息流（已解析為 Map）
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// 當前連接狀態
  bool get isConnected => _connectionStateController.isClosed
      ? false
      : (_channel != null && _rawSocket != null);

  // ==================== Constructor ====================
  WebSocketManager({
    required this.hostname,
    required this.port,
    required this.token,
  });

  // ==================== 公開方法 ====================

  /// 連接到 WebSocket 伺服器
  Future<void> connect() async {
    if (_isDisposed) {
      print('⚠️ WebSocketManager 已被釋放，無法連接');
      return;
    }

    await _cleanupConnection();

    final uri = Uri.parse('wss://$hostname:$port/$token');

    print('🔗 ==================== WebSocket 連接 ====================');
    print('🔗 URI: $uri');
    print('🔗 Platform: ${io.Platform.operatingSystem}');
    print('🔗 ====================================================');

    try {
      _rawSocket = await io.WebSocket.connect(
        uri.toString(),
        headers: {
          'Host': uri.host,
          'Origin': 'https://$hostname',
          'User-Agent': 'GS_Display/1.0',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Accept': '*/*',
          'Accept-Encoding': 'gzip, deflate, br',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Sec-WebSocket-Version': '13',
          'Sec-WebSocket-Extensions': 'permessage-deflate',
          'Connection': 'Upgrade',
          'Upgrade': 'websocket',
        },
      ).timeout(_connectionTimeout);

      _channel = IOWebSocketChannel(_rawSocket!);

      // 監聽訊息
      _streamSubscription = _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: _handleError,
        cancelOnError: false,
      );

      // 發送連接成功狀態
      _connectionStateController.add(true);

      // 啟動心跳
      _startHeartbeat();

      print('✅ WebSocket 連接成功');
    } catch (e, stackTrace) {
      print('❌ ==================== 連接失敗 ====================');
      print('❌ 錯誤: $e');
      print('❌ Type: ${e.runtimeType}');
      print('❌ Stack: $stackTrace');
      print('❌ =================================================');

      _connectionStateController.add(false);
      _errorController.add('Connection failed: ${e.toString()}');

      _scheduleReconnect();
    }
  }

  /// 斷開連接（不會自動重連）
  Future<void> disconnect() async {
    print('🛑 主動斷開 WebSocket 連接');
    _shouldReconnect = false;
    await _cleanupConnection();
  }

  /// 釋放資源（在 dispose 中調用）
  Future<void> dispose() async {
    print('🧹 WebSocketManager 釋放資源');
    _isDisposed = true;
    _shouldReconnect = false;

    await _cleanupConnection();

    await _connectionStateController.close();
    await _errorController.close();
    await _messageController.close();
  }

  // ==================== 內部方法 ====================

  /// 清理連接資源
  Future<void> _cleanupConnection() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    await _streamSubscription?.cancel();
    _streamSubscription = null;

    try {
      await _rawSocket?.close(status.goingAway);
    } catch (_) {
      // 忽略關閉錯誤
    }

    _rawSocket = null;
    _channel = null;
  }

  /// 處理接收到的訊息
  void _handleMessage(dynamic message) {
    if (message == null || message == '') return;

    // 如果之前是斷開狀態，更新為連接
    if (!isConnected) {
      _connectionStateController.add(true);
    }

    print('📩 收到訊息: $message');

    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      _messageController.add(data);
    } catch (e) {
      print('❌ 訊息解析錯誤: $e');
      _errorController.add('Message parse error: $e');
    }
  }

  /// 處理連接斷開
  void _handleDisconnect() {
    print('⚠️ ==================== 連接關閉 ====================');
    print('⚠️ Close Code: ${_rawSocket?.closeCode}');
    print('⚠️ Close Reason: ${_rawSocket?.closeReason}');
    print('⚠️ =================================================');

    _connectionStateController.add(false);
    _errorController.add(
      'Connection closed: Code ${_rawSocket?.closeCode}, Reason: ${_rawSocket?.closeReason}',
    );

    _scheduleReconnect();
  }

  /// 處理連接錯誤
  void _handleError(dynamic e) {
    print('❌ ==================== 連接錯誤 ====================');
    print('❌ WebSocket 錯誤: $e');
    print('❌ =================================================');

    _connectionStateController.add(false);
    _errorController.add(e.toString());

    _scheduleReconnect();
  }

  /// 啟動心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (isConnected && !_isDisposed) {
        try {
          final heartbeat = jsonEncode({
            'action': 'ping',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          _channel?.sink.add(heartbeat);
          print('💓 Heartbeat sent');
        } catch (e) {
          print('❌ Heartbeat failed: $e');
          _connectionStateController.add(false);
          _errorController.add('Heartbeat failed: $e');
          _scheduleReconnect();
        }
      }
    });
  }

  /// 安排重連
  void _scheduleReconnect() {
    if (_isDisposed || !_shouldReconnect) return;

    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    print('🔁 ${_reconnectDelay.inSeconds}秒後重新連線...');

    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!_isDisposed && _shouldReconnect) {
        print('🔁 開始重新連線...');
        connect();
      }
    });
  }
}