import 'package:flutter/material.dart';

import 'extensions/widget.dart';
import 'AdaptiveIconTextBox.dart';

// ⚠️ Alert 畫面 ================================================
class AlertScreen extends StatelessWidget {
  final List<String> values;
  final String userID;

  const AlertScreen({
    super.key,
    required this.values,
    required this.userID,
  });

  //
  static const Color _bgColor = Colors.black;
  static const Color _userBgColor = Color.fromRGBO(255, 255, 255, 0.1);
  static const Color _white = Colors.white;

  static const double _widthFactor = 1.0;
  static const double _textHeight = 0.8;
  static const double _imagePadding = 10.0;

  //
  static final RegExp _digitPattern = RegExp(r'^[0-9]$');
  static final RegExp _allowedLetterPattern = RegExp(r'^[a-l]$');

  //
  Widget _buildDigitWidget(String value) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Text(
        value,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          height: _textHeight,
          fontWeight: FontWeight.w900,
          color: _white,
        ),
      ).mt(1),
    ).aspectRatio(1).flex(1);
  }

  Widget _buildImageWidget(String imageName) {
    return Image.asset(
      'assets/images/$imageName.png',
      fit: BoxFit.cover,
    ).p(_imagePadding).aspectRatio(1).flex(1);
  }

  @override
  Widget build(BuildContext context) {
    // 在 build 方法內只宣告會變化的局部變數
    final accentColor = "#f1c100".toColor();
    double _userContainerHeight = MediaQuery.of(context).size.height * 0.23;

    return Container(
      color: _bgColor,
      width: double.infinity,
      child: FractionallySizedBox(
        widthFactor: _widthFactor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 用戶資訊
            Container(
                width: double.infinity,
                height: _userContainerHeight,
                color: _userBgColor,
                child:  AdaptiveIconTextBox(
                  textLines: [
                    userID
                  ],
                  textColor: accentColor,
                  fontWeight: FontWeight.w900,

                  icon: Icons.person,
                )
            ),

            // 顯示值
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: values.map((v) {
                // 使用快取的 RegExp
                return _digitPattern.hasMatch(v)
                    ? _buildDigitWidget(v)
                    : _allowedLetterPattern.hasMatch(v)
                    ? _buildImageWidget(v)
                    : Container().aspectRatio(1).flex(1);
              }).toList(),
            ).px(MediaQuery.of(context).size.width * 0.02).flex(),
          ],
        ),
      ),
    );
  }
}