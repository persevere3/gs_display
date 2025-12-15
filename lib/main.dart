import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gs_display/widgets/PerformanceMonitorLarge.dart';
import 'package:gs_display/services/WebSocketManager.dart';

import 'screens/AlertScreen.dart';
import 'widgets/ResponsiveMarqueeText.dart';
import 'widgets/FittedIconTextBox.dart';
import 'config/tokens.dart';
import 'extensions/widget.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;


// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
// import 'services/firebase_crash_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
  // await FirebaseCrashService().init();

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

  // 常量定義
  static const Color _white = Colors.white;
  static const double _baseSize = 412.0;
  static const double _minScale = 0.8;
  static const double _maxScale = 1.4;

  // dispose，防止記憶體洩漏
  @override
  void dispose() {
    marqueeController.dispose();  // 釋放 TextEditingController
    super.dispose();
  }

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

            // 顏色計算
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
                    // Tip 輸入框
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

                    // Table 下拉選單
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
                          items: TokenConfig.tokenMap.keys
                              .map((k) => DropdownMenuItem(
                            value: k,
                            child: Text(k),
                          ))
                              .toList(),
                        ),
                      ),
                    ),

                    // Setting 按鈕
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
  static const Duration _gmtPlus8Offset = Duration(hours: 8);
  static const Duration _alertDuration = Duration(seconds: 5);
  static const double _marqueeBlankSpace = 200.0;
  static const double _marqueeVelocity = 50.0;

  // 連線狀態指示器常量
  static const double _indicatorSize = 22.0;
  static const double _indicatorBlurRadius = 10.0;
  static const double _indicatorOpacity = 0.6;
  static const double _indicatorBottom = 10.0;
  static const double _indicatorLeft = 20.0;
  static const double _maxIndicatorWidth = 0.6;

  // ==================== WebSocket Manager ====================
  late final WebSocketManager _wsManager;

  // ==================== 狀態變數 ====================
  bool isConnected = false;
  String errorText = '';

  // Socket 接收訊息
  String userID = '';
  List<String> alertValues = [];
  bool showAlert = false;

  // ==================== 時間相關（使用 ValueNotifier 避免整個畫面 rebuild）====================
  /// 使用 ValueNotifier 管理時間
  /// 只有時間顯示區域會 rebuild，其他部分不受影響
  late final ValueNotifier<List<String>> _timeNotifier;
  late final ValueNotifier<List<String>> _tableNotifier;
  Timer? _timer;

  // ==================== 快取的顏色（避免每次 build 都轉換）====================
  /// 在 initState 中預先計算顏色
  late final Color _marqueeColor;
  late final Color _dateTimeColor;
  late final Color _tableColor;

  @override
  void initState() {
    super.initState();

    // 初始化顏色（只計算一次）
    _marqueeColor = "#f1c100".toColor();
    _dateTimeColor = "#02dac5".toColor();
    _tableColor = '#ffffff'.toColor();

    // 初始化桌號（只處理一次）
    String tableNumber = widget.tableName.replaceAll('Table', '');
    tableNumber = tableNumber.length == 1 ? '0$tableNumber' : tableNumber;
    _tableNotifier = ValueNotifier([tableNumber]);

    // 初始化時間
    _timeNotifier = ValueNotifier(_getCurrentTimeList());
    _timer = Timer.periodic(Duration(seconds: 1), (_) => _updateTime());

    // 初始化 WebSocket
    _wsManager = WebSocketManager(
      hostname: _hostname,
      port: _port,
      token: widget.token,
    );

    // 監聽連接狀態
    _wsManager.connectionState.listen((connected) {
      if (mounted) {
        setState(() {
          isConnected = connected;
          if (connected) errorText = '';
        });
      }
    });

    // 監聽錯誤
    _wsManager.errorStream.listen((error) {
      if (mounted) {
        setState(() => errorText = error);
      }
    });

    // 監聽訊息
    _wsManager.messageStream.listen(_handleWebSocketMessage);

    // 開始連接
    _wsManager.connect();
  }

  /// 獲取當前時間列表
  List<String> _getCurrentTimeList() {
    final now = DateTime.now().toUtc().add(_gmtPlus8Offset);
    return [
      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
      "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}",
      'GMT+8',
    ];
  }

  /// 更新時間：只更新 ValueNotifier，不調用 setState
  /// 這樣只有 FittedIconTextBox 會 rebuild，其他部分不受影響
  void _updateTime() {
    if (mounted) {
      _timeNotifier.value = _getCurrentTimeList();
    }
  }

  /// 處理 WebSocket 訊息
  void _handleWebSocketMessage(Map<String, dynamic> data) {
    if (data['action'] == 'SwapResponse') {
      final userid = data['userid'] as String;
      final values = (data['value'] as String).split(',');
      final status = data['status'] as bool;

      if (!status) return;

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
  }

  @override
  void dispose() {
    print('🛑 MainScreen Dispose: 正在清理所有資源...');
    _timer?.cancel();
    _timeNotifier.dispose();
    _tableNotifier.dispose();
    _wsManager.dispose();  // 釋放 WebSocket 資源
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 主畫面或提醒畫面
            showAlert
                ? AlertScreen(values: alertValues, userID: userID)
                : _buildMainScreen(),

            // 連線狀態指示器（左下角）
            _buildConnectionIndicator(context),

            // 性能監控面板 (右下角)
            PerformanceMonitorLarge()
          ],
        ),
      ),
    );
  }

  /// 連接狀態指示器
  Widget _buildConnectionIndicator(BuildContext context) {
    final indicatorColor = isConnected ? Colors.greenAccent : Colors.redAccent;

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
            ),
          ],
        ),
      ),
    );
  }

  /// 主畫面構建
  Widget _buildMainScreen() {
    final screenWidth = MediaQuery.of(context).size.width;
    final marqueeHeight = MediaQuery.of(context).size.height * 0.2;
    final dateTimeFontWeight = FontWeight.w900;

    return Column(
      children: [
        // 跑馬燈區域
        ResponsiveMarqueeText(
          text: widget.marqueeText,
          width: screenWidth,
          height: marqueeHeight,
          padding: EdgeInsets.zero,
          textColor: _marqueeColor,  // 使用快取的顏色
          blankSpace: _marqueeBlankSpace,
          velocity: _marqueeVelocity,
          fontWeight: dateTimeFontWeight,
        ),

        // 主要顯示區域
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左側：桌號
            FittedIconTextBox(
              textLinesNotifier: _tableNotifier,  // 使用預先初始化的 ValueNotifier
              textColor: _tableColor,
              fontWeight: FontWeight.w300,
            ).flex(30),

            // 右側：時間
            FittedIconTextBox(
              textLinesNotifier: _timeNotifier,  // 使用 ValueNotifier
              textColor: _dateTimeColor,
              fontWeight: dateTimeFontWeight,
            ).ml(screenWidth * 0.02).flex(70),
          ],
        ).px(screenWidth * 0.02).flex(),
      ],
    );
  }
}
