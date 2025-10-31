import 'package:flutter/material.dart';
import 'dart:math' as math;

class ResponsiveTextRow extends StatelessWidget {
  final String text;
  final Color textColor;
  final FontWeight fontWeight;
  final TextAlign textAlign;
  final Alignment alignment;
  final int maxLines;
  final TextOverflow overflow;
  final Color? backgroundColor;
  final EdgeInsets padding;
  final bool showDebugBorder;
  final double widthMargin; // 寬度保留邊距比例

  // Icon 相關
  final IconData? icon;
  final Color iconColor;
  final double iconSpacing; // Icon 與文字的間距
  final bool iconOnLeft;    // Icon 是否在左側

  const ResponsiveTextRow({
    Key? key,
    required this.text,
    this.textColor = Colors.black,
    this.fontWeight = FontWeight.normal,
    this.textAlign = TextAlign.center,
    this.alignment = Alignment.center,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 4.0),
    this.showDebugBorder = false,
    this.widthMargin = 0.02,
    // Icon 預設
    this.icon,
    this.iconColor = Colors.black,
    this.iconSpacing = 6.0,
    this.iconOnLeft = true,
  }) : super(key: key);

  ({double fontSize, double iconSize}) _calcFontAndIconSize({
    required String text,
    required double availableHeight,
    required double availableWidth,
    required double widthMargin,
    required FontWeight weight,
    required int maxLines,
    required double textScale,
    required bool hasIcon,
    required double iconSpacing,
  }) {
    const double minFont = 8.0;
    const double maxFont = 300.0;

    double left = minFont;
    double right = math.min(availableHeight * 0.95, maxFont);
    double bestFont = minFont;
    double bestIcon = 0;

    final targetWidth = availableWidth * (1.0 - widthMargin);

    while (right - left > 0.2) {
      final mid = (left + right) / 2.0;

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: mid,
            fontWeight: weight,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        textScaler: TextScaler.linear(textScale), // 與顯示一致
      );
      tp.layout(maxWidth: double.infinity);

      double iconSize = 0;
      if (hasIcon) {
        // 以文字行高為基準，並受限於可用高度
        iconSize = math.min(tp.height, availableHeight * 0.95);
      }

      final totalWidth = tp.width + (hasIcon ? (iconSize + iconSpacing) : 0);
      final heightFits = math.max(tp.height, iconSize) <= availableHeight * 0.95;
      final widthFits = totalWidth <= targetWidth;

      if (heightFits && widthFits) {
        bestFont = mid;
        bestIcon = iconSize;
        left = mid; // 放大嘗試
      } else {
        right = mid; // 縮小嘗試
      }
    }

    return (fontSize: bestFont, iconSize: bestIcon);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.of(context).textScaleFactor;
        final availableWidth = constraints.maxWidth - padding.horizontal;
        final availableHeight = constraints.maxHeight - padding.vertical;

        final res = _calcFontAndIconSize(
          text: text,
          availableHeight: availableHeight,
          availableWidth: availableWidth,
          widthMargin: widthMargin,
          weight: fontWeight,
          maxLines: maxLines,
          textScale: textScale,
          hasIcon: icon != null,
          iconSpacing: iconSpacing,
        );

        final fontSize = res.fontSize;
        final iconSize = res.iconSize;

        final rootStyle = TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.0,
          color: textColor,
        );

        InlineSpan textSpan = TextSpan(text: text);

        InlineSpan? iconSpan = icon == null
            ? null
            : WidgetSpan(
          alignment: PlaceholderAlignment.middle, // 垂直置中
          child: Icon(icon, size: iconSize, color: iconColor),
        );

        final children = <InlineSpan>[];
        if (iconSpan != null && iconOnLeft) {
          children.add(iconSpan);
          if (iconSpacing > 0) {
            children.add(const WidgetSpan(child: SizedBox(width: 6)));
          }
          children.add(textSpan);
        } else if (iconSpan != null) {
          children.add(textSpan);
          if (iconSpacing > 0) {
            children.add(const WidgetSpan(child: SizedBox(width: 6)));
          }
          children.add(iconSpan);
        } else {
          children.add(textSpan);
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: backgroundColor,
          padding: padding,
          decoration: showDebugBorder
              ? BoxDecoration(border: Border.all(color: Colors.red, width: 1))
              : null,
          child: Align(
            alignment: alignment,
            child: Text.rich(
              TextSpan(style: rootStyle, children: children),
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: overflow,
              textScaler: TextScaler.linear(textScale), // 與量測一致
              // 鎖定行高：讓 middle 對齊的參考行框穩定
              strutStyle: StrutStyle(
                fontSize: fontSize,
                height: 1.0,
                forceStrutHeight: true,
              ),
            ),
          ),
        );
      },
    );
  }
}