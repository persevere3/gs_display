import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:io';
import 'dart:async';

/// 性能監控面板 - 放大測試版（開發時使用）
///
/// 功能：
/// 1. 實時顯示 FPS（幀率）- 每幀更新
/// 2. 顯示記憶體使用量 - 每秒更新
/// 3. 顯示 Widget rebuild 次數 - 累計計數
/// 4. 點擊可展開/收合詳細資訊
///
/// 測試版特性：
/// - 面板尺寸放大 2-3 倍，方便測試時查看
/// - 可能會遮擋主畫面內容（測試用途）
/// - 字體、圖示、間距都放大
///
/// 優化特性：
/// - 使用 RepaintBoundary 隔離重繪，不影響主畫面
/// - 智能採樣計算平均 FPS，避免數值跳動
/// - 根據性能狀況動態變色（綠/橙/紅）
///
/// 使用方式：
/// ```
/// Stack(
///   children: [
///     YourMainWidget(),
///     if (kDebugMode) PerformanceMonitorLarge(),  // 測試版
///   ],
/// )
/// ```
class PerformanceMonitorLarge extends StatefulWidget {
  /// 是否啟用監控（建議綁定 kDebugMode）
  final bool enabled;

  const PerformanceMonitorLarge({
    super.key,
    this.enabled = true,
  });

  @override
  State<PerformanceMonitorLarge> createState() => _PerformanceMonitorLargeState();
}

class _PerformanceMonitorLargeState extends State<PerformanceMonitorLarge> {
  // ==================== 性能數據變數 ====================

  /// 當前 FPS 值（幀率，理想值為 60）
  double _fps = 60.0;

  /// 記憶體使用量（MB）
  int _memoryUsageMB = 0;

  /// Rebuild 次數（累計）
  int _rebuildCount = 0;

  // ==================== UI 狀態變數 ====================

  /// 是否展開詳細資訊（預設展開，方便測試）
  bool _isExpanded = true;

  // ==================== 計時器 ====================

  /// 記憶體更新計時器（每秒觸發一次）
  Timer? _updateTimer;

  // ==================== FPS 計算相關 ====================

  /// 幀時間樣本列表（用於計算平均 FPS）
  /// 儲存最近幀的持續時間，避免單幀波動造成 FPS 劇烈變化
  final List<Duration> _frameDurations = [];

  /// 最大樣本數量（取最近 60 幀計算平均）
  /// 60 幀 = 1 秒的數據（假設 60fps），提供穩定的平均值
  static const int _maxFrameSamples = 60;

  @override
  void initState() {
    super.initState();

    // 如果啟用監控，開始收集數據
    if (widget.enabled) {
      _startMonitoring();
    }
  }

  /// 開始監控性能數據
  void _startMonitoring() {
    // 【關鍵 1】註冊幀時間回調
    // SchedulerBinding 是 Flutter 的幀調度器
    // 每次有新幀繪製完成後，會調用 _onFrameTiming
    SchedulerBinding.instance.addTimingsCallback(_onFrameTiming);

    // 【關鍵 2】啟動定時器，每秒更新記憶體數據
    // Timer.periodic 會持續執行，直到被 cancel
    _updateTimer = Timer.periodic(Duration(seconds: 1), (_) {
      // mounted 檢查：確保 widget 還存在
      // 防止 dispose 後仍在執行造成錯誤
      if (mounted) {
        _updateMemoryUsage();
      }
    });
  }

  /// 處理幀時間回調（每幀都會調用）
  ///
  /// 參數 timings：包含最近完成的幀資訊
  /// 一次回調可能包含多個幀的數據（批次處理）
  void _onFrameTiming(List<FrameTiming> timings) {
    // 遍歷所有新完成的幀
    for (final timing in timings) {
      // 【關鍵 3】獲取幀的總持續時間
      // totalSpan = build + layout + paint + composite 的總時間
      final frameDuration = timing.totalSpan;

      // 添加到樣本列表
      _frameDurations.add(frameDuration);

      // 【關鍵 4】限制樣本數量（FIFO 隊列）
      // 只保留最近 60 幀，移除最舊的
      // 這樣可以計算「最近 1 秒」的平均 FPS
      if (_frameDurations.length > _maxFrameSamples) {
        _frameDurations.removeAt(0);  // 移除最舊的樣本
      }
    }

    // 【關鍵 5】計算並更新 FPS 顯示
    // 只有在有樣本且 widget 存在時才更新
    if (_frameDurations.isNotEmpty && mounted) {
      setState(() {
        _fps = _calculateAverageFPS();
      });
    }
  }

  /// 計算平均 FPS
  ///
  /// 原理：FPS = 1秒 / 平均幀時間
  /// 例如：平均幀時間 16.67ms → FPS = 1000ms / 16.67ms ≈ 60
  double _calculateAverageFPS() {
    // 安全檢查：沒有樣本時返回預設值
    if (_frameDurations.isEmpty) return 60.0;

    // 【關鍵 6】計算平均幀時間（微秒）
    // 1. 將所有幀時間轉換為微秒
    // 2. 累加求和
    // 3. 除以樣本數得到平均值
    final avgMicroseconds = _frameDurations
        .map((d) => d.inMicroseconds)  // 轉換為微秒
        .reduce((a, b) => a + b)       // 累加
        / _frameDurations.length;      // 平均

    // 【關鍵 7】轉換為 FPS
    // 1 秒 = 1,000,000 微秒
    // FPS = 1,000,000 / 平均幀時間（微秒）
    final fps = 1000000 / avgMicroseconds;

    // 【關鍵 8】限制在合理範圍內（0-60）
    // clamp 確保數值不會異常（例如負數或超過螢幕刷新率）
    return fps.clamp(0.0, 60.0);
  }

  /// 更新記憶體使用量
  void _updateMemoryUsage() {
    try {
      // 【關鍵 9】更新狀態
      setState(() {
        // 累加 rebuild 計數
        // 每次調用 setState 就算一次 rebuild
        _rebuildCount++;

        // 【關鍵 10】獲取當前進程的記憶體使用量
        // ProcessInfo.currentRss = Resident Set Size（常駐記憶體）
        // 單位：bytes → 除以 (1024 * 1024) 轉換為 MB
        _memoryUsageMB = (ProcessInfo.currentRss / (1024 * 1024)).round();
      });
    } catch (e) {
      // 忽略錯誤：某些平台可能不支援 ProcessInfo
      // 不影響其他功能正常運行
    }
  }

  @override
  void dispose() {
    // 【關鍵 11】清理資源（必須！）
    // 防止記憶體洩漏和持續執行造成錯誤

    // 取消定時器
    _updateTimer?.cancel();

    // 移除幀時間回調
    // 如果不移除，dispose 後仍會繼續調用造成錯誤
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTiming);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 如果未啟用，返回空 widget（不佔空間）
    if (!widget.enabled) return SizedBox.shrink();

    // 【測試版調整 1】使用 Center 讓面板更顯眼
    // 位置：右下角，但尺寸放大
    return Positioned(
      bottom: 20,   // 增加底部距離
      right: 20,    // 增加右側距離
      // 【關鍵 12】RepaintBoundary 隔離重繪（最重要！）
      //
      // 為什麼必須用？
      // 1. PerformanceMonitor 每幀都在更新（60次/秒）
      // 2. 如果不隔離，主畫面會跟著重繪
      // 3. 性能監控工具反而拖累性能（觀察者效應）
      //
      // 效果：
      // - 只有監控面板內部重繪
      // - 主畫面完全不受影響
      // - 確保測量準確性
      child: RepaintBoundary(
        child: GestureDetector(
          // 點擊切換展開/收合
          onTap: () {
            setState(() => _isExpanded = !_isExpanded);
          },
          // 【關鍵 13】使用 AnimatedContainer 提供平滑過渡動畫
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),  // 300ms 的展開/收合動畫
            // 【測試版調整 2】放大內邊距（原本 12,8 → 現在 24,16）
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              // 【關鍵 14】根據 FPS 動態變色
              // 提供直觀的性能狀態反饋
              color: _getBackgroundColor(),
              // 【測試版調整 3】增大圓角
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  // 【測試版調整 4】增大陰影
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
              ],
              // 【測試版調整 5】添加邊框，更顯眼
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            // 根據展開狀態顯示不同內容
            child: _isExpanded ? _buildExpandedView() : _buildCompactView(),
          ),
        ),
      ),
    );
  }

  /// 根據 FPS 決定背景顏色
  ///
  /// 顏色映射：
  /// - FPS < 30: 紅色（卡頓，需要優化）
  /// - FPS 30-50: 橙色（一般，可以接受）
  /// - FPS > 50: 綠色（流暢，性能良好）
  Color _getBackgroundColor() {
    if (_fps < 30) {
      return Colors.red.withOpacity(0.95);  // 測試版：增加不透明度
    } else if (_fps < 50) {
      return Colors.orange.withOpacity(0.95);
    } else {
      return Colors.green.withOpacity(0.95);
    }
  }

  /// 簡潔視圖（收合狀態）
  ///
  /// 只顯示核心資訊：圖示 + FPS
  Widget _buildCompactView() {
    return Row(
      mainAxisSize: MainAxisSize.min,  // 不佔用多餘空間
      children: [
        // 【測試版調整 6】放大圖示（20 → 40）
        Icon(Icons.speed, color: Colors.white, size: 40),
        SizedBox(width: 12),  // 增加間距
        // FPS 數值
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 【測試版調整 7】放大字體（14 → 32）
            Text(
              '${_fps.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            Text(
              'FPS',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 詳細視圖（展開狀態）
  ///
  /// 顯示所有監控資訊：FPS + 記憶體 + Rebuild 次數
  Widget _buildExpandedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 【測試版調整 8】添加標題
        Text(
          '性能監控',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),

        // 【測試版調整 9】增加分隔線
        Container(
          margin: EdgeInsets.symmetric(vertical: 12),
          height: 2,
          width: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.5),
                Colors.white.withOpacity(0.1),
              ],
            ),
          ),
        ),

        // FPS 資訊行
        _buildInfoRow(
          Icons.speed,                        // 圖示
          'FPS',                              // 標籤
          '${_fps.toStringAsFixed(1)}',       // 數值（保留 1 位小數）
          _getFPSStatus(),                    // 狀態描述
        ),

        // 【測試版調整 10】增加行間距（8 → 16）
        SizedBox(height: 16),

        // 記憶體資訊行
        _buildInfoRow(
          Icons.memory,
          'Memory',
          '${_memoryUsageMB} MB',
          _getMemoryStatus(),
        ),

        SizedBox(height: 16),

        // Rebuild 次數行
        _buildInfoRow(
          Icons.refresh,
          'Rebuilds',
          '$_rebuildCount',
          '',  // 沒有狀態描述
        ),

        SizedBox(height: 16),

        // 【測試版調整 11】增加更新頻率資訊
        _buildInfoRow(
          Icons.timer,
          'Update',
          '60/s',  // 每秒 60 次
          'Real-time',
        ),

        SizedBox(height: 16),

        // 分隔線
        Container(
          height: 1,
          width: 200,
          color: Colors.white.withOpacity(0.3),
        ),

        SizedBox(height: 12),

        // 提示文字
        Center(
          child: Text(
            '點擊收合面板',  // 點擊收合
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  /// 構建單行資訊顯示
  ///
  /// 參數：
  /// - icon: 圖示
  /// - label: 標籤（例如 "FPS"）
  /// - value: 數值（例如 "60.0"）
  /// - status: 狀態描述（例如 "流暢"）
  Widget _buildInfoRow(IconData icon, String label, String value, String status) {
    return Container(
      // 【測試版調整 12】添加背景，區分每一行
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 【測試版調整 13】放大圖示（18 → 32）
          Icon(icon, color: Colors.white, size: 32),
          SizedBox(width: 12),  // 增加間距
          // 標籤和數值
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標籤（小字灰色）
              Text(
                label,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,  // 放大字體（10 → 14）
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              // 數值和狀態
              Row(
                children: [
                  // 【測試版調整 14】放大數值（16 → 28）
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // 狀態描述（如果有的話）
                  if (status.isNotEmpty) ...[
                    SizedBox(width: 8),
                    // 【測試版調整 15】放大狀態文字（10 → 14）
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 獲取 FPS 狀態描述
  String _getFPSStatus() {
    if (_fps >= 55) return '流暢';   // 接近 60fps，非常流暢
    if (_fps >= 45) return '良好';   // 45-55fps，可以接受
    if (_fps >= 30) return '一般';   // 30-45fps，有點卡頓
    return '卡頓';                   // < 30fps，需要優化
  }

  /// 獲取記憶體狀態描述
  String _getMemoryStatus() {
    if (_memoryUsageMB < 100) return '正常';   // < 100MB，正常
    if (_memoryUsageMB < 200) return '中等';   // 100-200MB，中等
    return '偏高';                             // > 200MB，偏高，可能有問題
  }
}