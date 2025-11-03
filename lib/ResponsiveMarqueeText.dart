import 'package:flutter/material.dart';

import 'package:marquee/marquee.dart';

class ResponsiveMarqueeText extends StatelessWidget {
  final String text;
  final double height;
  final double? width;
  final Color backgroundColor;
  final Color textColor;
  final double velocity;
  final double blankSpace;
  final FontWeight fontWeight;
  final EdgeInsets padding;
  final double heightRatio;
  final Duration pauseAfterRound;
  final Duration accelerationDuration;
  final Curve accelerationCurve;
  final Duration decelerationDuration;
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
    this.accelerationDuration = const Duration(seconds: 1),
    this.accelerationCurve = Curves.linear,
    this.decelerationDuration = const Duration(milliseconds: 500),
    this.decelerationCurve = Curves.easeOut,
    this.baseFontSize = 100.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = this.width ?? MediaQuery.of(context).size.width;
    final targetHeight = height * heightRatio;

    return Container(
      height: height,
      width: width,
      color: backgroundColor,
      padding: padding,
      alignment: Alignment.center,
      child: SizedBox(
        height: targetHeight,
        width: width, // 給定明確寬度
        child: FittedBox(
          fit: BoxFit.fitHeight, // 只按高度縮放
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: baseFontSize,
            width: width, // Marquee 需要明確寬度
            child: Marquee(
              text: text,
              style: TextStyle(
                fontSize: baseFontSize,
                fontWeight: fontWeight,
                color: textColor,
                height: 1.0,
              ),
              scrollAxis: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              blankSpace: blankSpace,
              velocity: velocity,
              pauseAfterRound: pauseAfterRound,
              startPadding: 10.0,
              accelerationDuration: accelerationDuration,
              accelerationCurve: accelerationCurve,
              decelerationDuration: decelerationDuration,
              decelerationCurve: decelerationCurve,
            ),
          ),
        ),
      ),
    );
  }
}

