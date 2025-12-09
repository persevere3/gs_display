import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'AlertScreen.dart';
import 'ResponsiveMarqueeText.dart';
import 'AdaptiveIconTextBox.dart';
import 'config/tokens.dart';
import 'extensions/widget.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firebase_crash_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseCrashService().init();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Display',
      debugShowCheckedModeBanner: false,

      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),

      home: const HomeScreen(),
    );
  }
}

// 🏠 首頁畫面 ================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController marqueeController = TextEditingController();
  String? selectedTable;

  //
  static const Color _white = Colors.white;
  static const double _baseSize = 412.0;
  static const double _minScale = 0.8;
  static const double _maxScale = 1.4;

  void _goToMain() {
    if (selectedTable == null || marqueeController.text.isEmpty) return;
    final token = TokenConfig.tokenMap[selectedTable]!;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainScreen(
          tableName: selectedTable!,
          token: token,
          marqueeText: marqueeController.text,
        ),
      ),
    );
  }

  // 提取可重用的邊框裝飾方法
  OutlineInputBorder _buildInputBorder(Color color, double width, BorderRadius radius) {
    return OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 計算響應式尺寸
            final shortestSide = constraints.biggest.shortestSide;
            final scaleClamp = (shortestSide / _baseSize).clamp(_minScale, _maxScale);

            final fieldHeight = 80 * scaleClamp;
            final fontMed = 30 * scaleClamp;
            final spacing = 30 * scaleClamp;

            //
            final inputBg = _white.withValues(alpha: 0.1);
            final hintColor = _white.withValues(alpha: 0.4);
            final borderColor = _white.withValues(alpha: 0.4);
            final focusedBorderColor = _white.withValues(alpha: 0.8);
            final borderRadius = BorderRadius.circular(5);

            // 提取通用的文字樣式
            final textStyle = TextStyle(
              fontSize: fontMed,
              fontWeight: FontWeight.w700,
              color: _white,
            );

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing * 4,
                  vertical: spacing * 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Tip
                    TextField(
                      controller: marqueeController,
                      style: textStyle,
                      decoration: InputDecoration(
                        hintText: "Tip",
                        hintStyle: TextStyle(color: hintColor),
                        filled: true,
                        fillColor: inputBg,
                        border: _buildInputBorder(borderColor, 2, borderRadius),
                        focusedBorder: _buildInputBorder(focusedBorderColor, 3, borderRadius),
                      ),
                    ).mb(spacing),

                    // Table
                    Container(
                      height: fieldHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      margin: EdgeInsets.only(bottom: spacing),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: borderRadius,
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedTable,
                          hint: Text(
                            "Table",
                            style: TextStyle(color: hintColor),
                          ),
                          style: textStyle,
                          isExpanded: true,
                          onChanged: (v) => setState(() => selectedTable = v),
                          items: TokenConfig.tokenMap.keys.map((k) => DropdownMenuItem(
                            value: k,
                            child: Text(k),
                          )).toList(),
                        ),
                      ),
                    ),

                    // Setting
                    ElevatedButton(
                      onPressed: _goToMain,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _white,
                        shape: RoundedRectangleBorder(borderRadius: borderRadius),
                        elevation: 8,
                      ),
                      child: Text(
                        "Setting",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: fontMed,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ).wh(double.infinity, fieldHeight)
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// 📺 主畫面 ================================================
class MainScreen extends StatefulWidget {
  final String tableName;
  final String token;
  final String marqueeText;

  const MainScreen({
    super.key,
    required this.tableName,
    required this.token,
    required this.marqueeText,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // ==================== 靜態常量 ====================
  static const String _hostname = 'live.me3kb78d.com';
  static const int _port = 2087;

  // 重連策略常量（固定延遲）
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 5);
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _alertDuration = Duration(seconds: 5);

  // 時區常量
  static const Duration _gmtPlus8Offset = Duration(hours: 8);
  static const Duration _timeUpdateInterval = Duration(seconds: 1);

  // UI 常量
  static const Color _marqueeContainerBg = Color.fromRGBO(255, 255, 255, 0.1);
  static const double _marqueeBlankSpace = 200.0;
  static const double _marqueeVelocity = 50.0;
  static const double _textFontSize = 200.0;

  // 連線狀態指示器常量
  static const double _indicatorSize = 22.0;
  static const double _indicatorBlurRadius = 10.0;
  static const double _indicatorOpacity = 0.6;
  static const double _indicatorBottom = 10.0;
  static const double _indicatorLeft = 20.0;
  static const double _indicatorSpacing = 8.0;
  static const double _statusFontSize = 18.0;
  static const double _errorFontSize = 16.0;
  static const double _maxIndicatorWidth = 0.6;

  // ==================== Socket 相關變數 ====================
  late WebSocketChannel channel;
  io.WebSocket? rawSocket;
  StreamSubscription? _streamSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  bool isConnected = false;
  String errorText = '';

  // ==================== Socket 接收訊息 ====================
  String userID = '';
  List<String> alertValues = [];
  bool showAlert = false;

  // ==================== 時間相關 ====================
  Timer? _timer;
  String currentDate = '';
  String currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(_timeUpdateInterval, (_) => _updateTime());
    _connectWebSocket();
  }

  void _updateTime() {
    final now = DateTime.now().toUtc().add(_gmtPlus8Offset);
    if (mounted) {
      setState(() {
        currentDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _connectWebSocket() async {
    if (!mounted) return;

    // 在建立新連線前，先安全地取消舊的訂閱和關閉舊的 Socket
    print('🧹 清理舊的連線資源...');
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    // 嘗試關閉，忽略過程中可能發生的錯誤
    try {
      await rawSocket?.close();
    } catch (_) {
      // 忽略關閉舊 Socket 時可能發生的錯誤，因為我們正要建立新的
    }
    rawSocket = null;

    final uri = Uri.parse('wss://$_hostname:$_port/${widget.token}');

    print('🔗 ==================== 連線資訊 ====================');
    print('🔗 URI: $uri');
    print('🔗 Platform: ${io.Platform.operatingSystem}');
    print('🔗 Table: ${widget.tableName}');
    print('🔗 ================================================');

    try {
      rawSocket = await io.WebSocket.connect(
        uri.toString(),
        headers: {
          'Host': uri.host,
          'Origin': 'https://$_hostname',

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
        }
      ).timeout(_connectionTimeout);

      channel = IOWebSocketChannel(rawSocket!);

      // 設置訊息監聽
      _streamSubscription = channel.stream.listen(
            (message) => _handleMessage(message),
        onDone: () => _handleDisconnect(),
        onError: (e) => _handleError(e),
        cancelOnError: false,
      );

      // 啟動心跳
      _startHeartbeat();

    } catch (e, stackTrace) {
      print('❌ ==================== 連線失敗 ====================');
      print('❌ 錯誤: $e');
      print('❌ Type: ${e.runtimeType}');
      print('❌ Stack: $stackTrace');
      print('❌ ================================================');

      await FirebaseCrashService().recordSocketError(e);

      if (mounted) {
        setState(() {
          isConnected = false;
          errorText = 'Connection failed: ${e.toString()}';
        });
      }

      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    if(message == '') return;
    if (!isConnected && mounted) {
      setState(() {
        isConnected = true;
        errorText = '';
      });
    }

    print('📩 收到訊息: $message');

    try {
      final data = jsonDecode(message);

      if (data['action'] == 'SwapResponse') {
        final userid = (data['userid'] as String);
        final values = (data['value'] as String).split(',');
        final status = (data['status'] as bool);

        if(!status) return;

        if (mounted) {
          setState(() {
            userID = userid;
            alertValues = values;
            showAlert = true;
          });

          // 5秒後自動隱藏提醒
          Future.delayed(_alertDuration, () {
            if (mounted) setState(() => showAlert = false);
          });
        }
      }
    } catch (e) {
      print('❌ 訊息解析錯誤: $e');
    }
  }

  void _handleDisconnect() {
    print('⚠️ ==================== 連線關閉 ====================');
    print('⚠️ Close Code: ${rawSocket?.closeCode}');
    print('⚠️ Close Reason: ${rawSocket?.closeReason}');
    print('⚠️ ================================================');

    if (mounted) {
      setState(() {
        isConnected = false;
        errorText = 'Connection closed: ErrCode: ${rawSocket?.closeCode}, ErrReason: ${rawSocket?.closeReason}';
      });
    }

    _scheduleReconnect();
  }

  void _handleError(dynamic e) {
    print('❌ ==================== 連線錯誤 ====================');
    print('❌ WebSocket 錯誤: $e');
    print('❌ ================================================');

    if (mounted) {
      setState(() {
        isConnected = false;
        errorText = e.toString();
      });
    }

    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (isConnected && mounted) {
        try {
          final heartbeat = jsonEncode({
            'action': 'ping',
            'timestamp': DateTime.now().millisecondsSinceEpoch
          });
          channel.sink.add(heartbeat);
          print('💓 Heartbeat sent');
        } catch (e) {
          print('❌ Heartbeat failed: $e');

          if (mounted) {
            setState(() {
              isConnected = false;
              errorText = 'Heartbeat failed: $e';
            });
          }
          _scheduleReconnect();
        }
      }
    });
  }

  void _scheduleReconnect() {
    if (!mounted) return;

    // 取消現有的計時器
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    print('🔁 ${_reconnectDelay.inSeconds}秒後重新連線...');
    print('🔁 原因: $errorText');

    if (mounted) {
      setState(() {
        isConnected = false;
      });
    }

    _reconnectTimer = Timer(_reconnectDelay, () {
      if (mounted) {
        print('🔁 開始重新連線...');
        _connectWebSocket();
      }
    });
  }

  @override
  void dispose() {
    print('🛑 MainScreen Dispose: 正在清理所有資源...');
    _streamSubscription?.cancel(); //
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    rawSocket?.close(status.goingAway);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 在 build 中只保留需要運行時計算的變數
    final marqueeColor = "#f1c100".toColor();
    final dateTimeColor = "#02dac5".toColor();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // AlertScreen(values: ['1', 'a', 'd', 'f'], userID: 'testAccount'),
            showAlert
                ? AlertScreen(values: alertValues, userID: userID)
                : _buildMainScreen(marqueeColor, dateTimeColor),

            // 連線狀態指示器（左下角）
            _buildConnectionIndicator(context),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator(BuildContext context) {
    final indicatorColor = isConnected ? Colors.greenAccent : Colors.redAccent;
    // final statusText = isConnected ? "Connected" : "Disconnected";

    return Positioned(
      bottom: _indicatorBottom,
      left: _indicatorLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * _maxIndicatorWidth,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _indicatorSize,
              height: _indicatorSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: indicatorColor,
                boxShadow: [
                  BoxShadow(
                    color: indicatorColor.withValues(alpha: _indicatorOpacity),
                    blurRadius: _indicatorBlurRadius,
                  )
                ],
              ),
            ).mr(_indicatorSpacing),
          ],
        ),
      ),
    );
  }

  Widget _buildMainScreen(Color marqueeColor, Color dateTimeColor) {
    // 提取桌號處理邏輯
    String tableNumber = widget.tableName.replaceAll('Table', '');
    tableNumber = tableNumber.length == 1 ? '0$tableNumber' : tableNumber;

    double _marqueeHeight = MediaQuery.of(context).size.height * 0.2;

    final FontWeight dateTimeFontWeight = FontWeight.w900;

    return Column(
      children: [
        // 跑馬燈區域
        ResponsiveMarqueeText(
          text: widget.marqueeText,
          width: MediaQuery.of(context).size.width,
          height: _marqueeHeight,
          padding: EdgeInsets.all(0),
          textColor: marqueeColor,
          blankSpace: _marqueeBlankSpace,
          velocity: _marqueeVelocity,
            fontWeight: dateTimeFontWeight
        ),

        // 主要顯示區域
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左側：桌號
            AdaptiveIconTextBox(
              textLines: [
                tableNumber
              ],
              textColor: '#ffffff'.toColor(),
              fontWeight: FontWeight.w300,
            ).flex(30),

            // 右側：時間
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AdaptiveIconTextBox(
                  textLines: [
                    currentDate,
                    currentTime,
                    'GMT+8'
                  ],
                  textColor: dateTimeColor,
                  fontWeight: dateTimeFontWeight,
                ).flex()
              ],
            ).ml(MediaQuery.of(context).size.width * 0.02).flex(70),
          ],
        ).px(MediaQuery.of(context).size.width * 0.02).flex(),
      ],
    );
  }
}
