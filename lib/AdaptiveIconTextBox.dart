import 'package:flutter/material.dart';
import 'extensions/widget.dart';

/// 原本的功能 class：以 FittedBox 等比縮放 Icon+Text 組合，至少一邊貼齊外框，
/// 若高度未滿可用 alignY 控制垂直位置；文字使用 TightText 取消上下行高領空。
class AdaptiveIconTextBox extends StatelessWidget {
  const AdaptiveIconTextBox({
    super.key,
    this.icon,
    this.textLines,  // 改為 textLines
    this.textColor,
    this.fontWeight = FontWeight.w600,
    this.backgroundColor = Colors.transparent,
    this.gap = 8.0,
    this.lineSpacing = 0,  // 新增：行與行之間的間距
    this.alignY = 0.0,
    this.baseFontSize = 100.0,
    this.baseIconSize = 100.0,
  }) : assert(icon != null || (textLines != null && textLines.length > 0),
  'icon 與 textLines 至少提供其中之一');

  final IconData? icon;
  final List<String>? textLines;  // 改為 List<String>
  final Color? textColor;
  final FontWeight fontWeight;
  final Color backgroundColor;
  final double gap;
  final double lineSpacing;  // 新增參數
  final double alignY;
  final double baseFontSize;
  final double baseIconSize;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (icon != null) {
      children.add(Icon(
        icon,
        size: baseIconSize,
        color: textColor,
      ));
    }

    if (icon != null && textLines != null && textLines!.isNotEmpty) {
      children.add(SizedBox(width: gap));
    }

    if (textLines != null && textLines!.isNotEmpty) {
      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,  // 最小化高度
          crossAxisAlignment: CrossAxisAlignment.center,  // 文字靠左對齊
          children: [
            for (int i = 0; i < textLines!.length; i++) ...[
              Text(
                textLines![i],
                style: TextStyle(
                  fontSize: baseFontSize,
                  fontWeight: fontWeight,
                  height: 1.1,
                  color: textColor,
                ),
              ),
              if (i < textLines!.length - 1)  // 最後一行不加間距
                SizedBox(height: lineSpacing),
            ],
          ],
        ),
      );
    }

    return SizedBox.expand(
      child: Container(
        color: backgroundColor,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment(0, alignY.clamp(-1.0, 1.0)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}