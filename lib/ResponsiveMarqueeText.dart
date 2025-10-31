import 'package:flutter/material.dart';

import 'package:marquee/marquee.dart';

class ResponsiveMarqueeText extends StatefulWidget {
  final String text;
  final double height;
  final double? width;
  final Color backgroundColor;
  final Color textColor;
  final double velocity;
  final double blankSpace;
  final FontWeight fontWeight;
  final EdgeInsets padding;
  final double heightRatio; // 文字高度佔容器高度的比例
  final Duration pauseAfterRound;
  final Duration accelerationDuration;
  final Curve accelerationCurve;
  final Duration decelerationDuration;
  final Curve decelerationCurve;
  final bool lockFontSizeOnce; // 是否首幀量測後鎖定

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
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0),
    this.heightRatio = 0.99, // 文字使用容器85%的高度
    this.pauseAfterRound = const Duration(seconds: 0),
    this.accelerationDuration = const Duration(seconds: 1),
    this.accelerationCurve = Curves.linear,
    this.decelerationDuration = const Duration(milliseconds: 500),
    this.decelerationCurve = Curves.easeOut,
    this.lockFontSizeOnce = true,
  }) : super(key: key);

  @override
  State<ResponsiveMarqueeText> createState() => _ResponsiveMarqueeTextState();
}

class _ResponsiveMarqueeTextState extends State<ResponsiveMarqueeText> {
  double? _frozenFontSize; // 首幀量測後鎖定的字級

  double _measureFontSize({
    required double targetHeight,
    required double textScale,
    required FontWeight weight,
    required String text,
  }) {
    const double minFontSize = 8.0;
    const double maxFontSize = 300.0;
    double left = minFontSize;
    double right = (targetHeight * 0.8).clamp(minFontSize, maxFontSize);
    double best = minFontSize;

    while (right - left > 0.1) {
      final mid = (left + right) / 2;
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: mid, fontWeight: weight)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textScaler: TextScaler.linear(textScale), // 與繪製一致
      );
      tp.layout();
      if (tp.height <= targetHeight) {
        best = mid;
        left = mid;
      } else {
        right = mid;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.of(context).textScaleFactor;
    final width = widget.width ?? MediaQuery.of(context).size.width;
    final targetHeight = (widget.height * widget.heightRatio).floorToDouble();

    return SizedBox(
      height: widget.height,
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 首幀：計算並鎖定字級
          if (widget.lockFontSizeOnce && _frozenFontSize == null) {
            final computed = _measureFontSize(
              targetHeight: targetHeight,
              textScale: textScale,
              weight: widget.fontWeight,
              text: widget.text,
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _frozenFontSize = computed);
            });
          }

          final effectiveFontSize = _frozenFontSize ??
              _measureFontSize( // 若未鎖定或首幀尚未寫回，臨時使用量測值
                targetHeight: targetHeight,
                textScale: textScale,
                weight: widget.fontWeight,
                text: widget.text,
              );

          return Container(
            color: widget.backgroundColor,
            padding: widget.padding,
            alignment: Alignment.center,
            child: Marquee(
              text: widget.text,
              textScaleFactor: textScale, // 量測與繪製縮放一致
              style: TextStyle(
                fontSize: effectiveFontSize,
                fontWeight: widget.fontWeight,
                color: widget.textColor,
              ),
              scrollAxis: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              blankSpace: widget.blankSpace,
              velocity: widget.velocity,
              pauseAfterRound: widget.pauseAfterRound,
              startPadding: 0.0,
              accelerationDuration: widget.accelerationDuration,
              accelerationCurve: widget.accelerationCurve,
              decelerationDuration: widget.decelerationDuration,
              decelerationCurve: widget.decelerationCurve,
            ),
          );
        },
      ),
    );
  }
}

