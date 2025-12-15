import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

/// 響應式跑馬燈元件
class ResponsiveMarqueeText extends StatelessWidget {
  final String text;
  final double height;
  final double? width;
  final Color backgroundColor;
  final Color textColor;

  /// 滾動速度（像素/秒）
  /// 數值越大滾動越快
  /// 預設 50.0
  final double velocity;

  /// 文字之間的空白距離
  /// 當文字滾動完一輪後，重新開始前的間距
  /// 預設 20.0
  final double blankSpace;

  final FontWeight fontWeight;

  final EdgeInsets padding;

  final double heightRatio;

  /// 每輪滾動完成後的暫停時間
  /// 預設不暫停（Duration(seconds: 0)）
  final Duration pauseAfterRound;

  /// 加速動畫持續時間
  /// 跑馬燈啟動時的加速階段
  /// 預設 1 秒
  final Duration accelerationDuration;

  /// 加速曲線
  /// 控制加速過程的速度變化
  /// 預設 Curves.linear（線性加速）
  final Curve accelerationCurve;

  /// 減速動畫持續時間
  /// 跑馬燈停止前的減速階段
  /// 預設 500 毫秒
  final Duration decelerationDuration;

  /// 減速曲線
  /// 控制減速過程的速度變化
  /// 預設 Curves.easeOut（緩出）
  final Curve decelerationCurve;

  final double baseFontSize;

  const ResponsiveMarqueeText({
    Key? key,
    required this.text,
    required this.height,
    this.width,
    this.backgroundColor = Colors.transparent,
    this.textColor = Colors.black,
    this.velocity = 50.0,
    this.blankSpace = 20.0,
    this.fontWeight = FontWeight.bold,
    this.padding = const EdgeInsets.symmetric(horizontal: 0.0),
    this.heightRatio = 0.99,
    this.pauseAfterRound = const Duration(seconds: 0),
    this.baseFontSize = 100.0,
    this.accelerationDuration = const Duration(seconds: 1),
    this.accelerationCurve = Curves.linear,
    this.decelerationDuration = const Duration(milliseconds: 500),
    this.decelerationCurve = Curves.easeOut,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = this.width ?? MediaQuery.of(context).size.width;
    final targetHeight = height * heightRatio;

    // 快取 TextStyle
    final textStyle = TextStyle(
      fontSize: baseFontSize,  // 基礎字體大小（會被 FittedBox 縮放）
      fontWeight: fontWeight,
      color: textColor,
      height: 1.0,  // 行高設為 1.0，減少上下留白
    );

    return Container(
      height: height,
      width: width,
      color: backgroundColor,
      padding: padding,
      alignment: Alignment.center,
      child:
      // 使用 RepaintBoundary 隔離重繪範圍
      RepaintBoundary(
        child: SizedBox(
          height: targetHeight,  // 設定文字顯示區域的高度
          width: width,          // 設定寬度
          child: FittedBox(
            // 使用 FittedBox 自動縮放文字
            // fit: BoxFit.fitHeight - 只按高度縮放，保持文字寬度比例
            // 這樣可以確保文字填滿容器高度，同時保持正常寬度供 Marquee 滾動
            fit: BoxFit.fitHeight,
            alignment: Alignment.centerLeft,  // 文字靠左對齊
            child: SizedBox(
              height: baseFontSize,  // FittedBox 的參考高度
              width: width,          // Marquee 需要明確的寬度才能正常滾動
              child: Marquee(
                // Marquee 執行滾動動畫
                text: text,
                style: textStyle,
                scrollAxis: Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.center,
                blankSpace: blankSpace,
                velocity: velocity,
                pauseAfterRound: pauseAfterRound,
                startPadding: 10.0,

                // 動畫控制參數
                accelerationDuration: accelerationDuration,      // 加速時長
                accelerationCurve: accelerationCurve,            // 加速曲線
                decelerationDuration: decelerationDuration,      // 減速時長
                decelerationCurve: decelerationCurve,            // 減速曲線
              ),
            ),
          ),
        ),
      ),
    );
  }
}