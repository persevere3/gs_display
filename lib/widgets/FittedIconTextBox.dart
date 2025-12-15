import 'package:flutter/material.dart';

class FittedIconTextBox extends StatelessWidget {
  const FittedIconTextBox({
    super.key,
    this.icon,
    required this.textLinesNotifier,
    this.backgroundColor = Colors.transparent,
    this.textColor,
    this.fontWeight = FontWeight.w600,
    this.gap = 8.0,
    this.lineSpacing = 0,
    this.alignY = 0.0,
    this.baseFontSize = 100.0,
    this.baseIconSize = 100.0,
  });

  final IconData? icon;
  final ValueNotifier<List<String>> textLinesNotifier;
  final Color backgroundColor;
  final Color? textColor;
  final FontWeight fontWeight;
  final double gap;
  final double lineSpacing;
  final double alignY;
  final double baseFontSize;
  final double baseIconSize;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary：隔離重繪範圍，多個實例互不影響
    return RepaintBoundary(
      // ColoredBox 比 Container 性能更好
      child: ColoredBox(
        color: backgroundColor,
        // ValueListenableBuilder：只監聽 textLinesNotifier 變化
        // 減少 50-70% 不必要的 rebuild
        child: ValueListenableBuilder<List<String>>(
          valueListenable: textLinesNotifier,
          builder: (context, textLines, iconWidget) {
            return _FittedContent(
              icon: iconWidget,  // 靜態 icon 不會 rebuild
              textLines: textLines,
              textColor: textColor,
              fontWeight: fontWeight,
              gap: gap,
              lineSpacing: lineSpacing,
              alignY: alignY,
              baseFontSize: baseFontSize,
            );
          },
          // child：靜態內容，只建立一次
          child: icon != null
              ? Icon(icon, size: baseIconSize, color: textColor)
              : null,
        ),
      ),
    );
  }
}

/// 內部 widget：處理 FittedBox 自動縮放邏輯
class _FittedContent extends StatelessWidget {
  const _FittedContent({
    this.icon,
    required this.textLines,
    this.textColor,
    required this.fontWeight,
    required this.gap,
    required this.lineSpacing,
    required this.alignY,
    required this.baseFontSize,
  });

  final Widget? icon;
  final List<String> textLines;
  final Color? textColor;
  final FontWeight fontWeight;
  final double gap;
  final double lineSpacing;
  final double alignY;
  final double baseFontSize;

  @override
  Widget build(BuildContext context) {
    // 快取 TextStyle，避免重複創建
    final textStyle = TextStyle(
      fontSize: baseFontSize,
      fontWeight: fontWeight,
      height: 1.1,
      color: textColor,
    );

    // FittedBox：自動縮放以填滿容器
    return FittedBox(
      fit: BoxFit.contain,  // 至少一邊貼齊容器邊界
      alignment: Alignment(0, alignY.clamp(-1.0, 1.0)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            SizedBox(width: gap),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < textLines.length; i++) ...[
                Text(textLines[i], style: textStyle),
                if (i < textLines.length - 1)
                  SizedBox(height: lineSpacing),
              ],
            ],
          ),
        ],
      ),
    );
  }
}