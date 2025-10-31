import 'package:flutter/material.dart';

// ------------------ Padding Extensions ------------------
extension PaddingExtensions on Widget {
  Widget p(double value) => Padding(padding: EdgeInsets.all(value), child: this);
  Widget px(double value) => Padding(padding: EdgeInsets.symmetric(horizontal: value), child: this);
  Widget py(double value) => Padding(padding: EdgeInsets.symmetric(vertical: value), child: this);
  Widget pt(double value) => Padding(padding: EdgeInsets.only(top: value), child: this);
  Widget pb(double value) => Padding(padding: EdgeInsets.only(bottom: value), child: this);
  Widget pl(double value) => Padding(padding: EdgeInsets.only(left: value), child: this);
  Widget pr(double value) => Padding(padding: EdgeInsets.only(right: value), child: this);
}

// ------------------ Margin Extensions ------------------
extension MarginExtensions on Widget {
  Widget m(double value) => Container(margin: EdgeInsets.all(value), child: this);
  Widget mx(double value) => Container(margin: EdgeInsets.symmetric(horizontal: value), child: this);
  Widget my(double value) => Container(margin: EdgeInsets.symmetric(vertical: value), child: this);
  Widget mt(double value) => Container(margin: EdgeInsets.only(top: value), child: this);
  Widget mb(double value) => Container(margin: EdgeInsets.only(bottom: value), child: this);
  Widget ml(double value) => Container(margin: EdgeInsets.only(left: value), child: this);
  Widget mr(double value) => Container(margin: EdgeInsets.only(right: value), child: this);
}

// ------------------ Size Extensions ------------------
extension SizeExtensions on Widget {
  Widget w(double width) => SizedBox(width: width, child: this);
  Widget h(double height) => SizedBox(height: height, child: this);
  Widget wh(double width, double height) => SizedBox(width: width, height: height, child: this);
  Widget fullWidth() => SizedBox(width: double.infinity, child: this);
  Widget fullHeight() => SizedBox(height: double.infinity, child: this);
  Widget square(double size) => SizedBox(width: size, height: size, child: this);
}

// ------------------ Align Extensions ------------------
extension AlignExtensions on Widget {
  Widget align(Alignment alignment) => Align(alignment: alignment, child: this);
  Widget center() => Center(child: this);
  Widget alignTopLeft() => align(Alignment.topLeft);
  Widget alignTopRight() => align(Alignment.topRight);
  Widget alignBottomLeft() => align(Alignment.bottomLeft);
  Widget alignBottomRight() => align(Alignment.bottomRight);
  Widget alignCenterLeft() => align(Alignment.centerLeft);
  Widget alignCenterRight() => align(Alignment.centerRight);
  Widget alignTopCenter() => align(Alignment.topCenter);
  Widget alignBottomCenter() => align(Alignment.bottomCenter);
}

// ------------------ Decoration Extensions ------------------
extension DecorationExtensions on Widget {
  Widget bg(Color color) => Container(color: color, child: this);
  Widget rounded([double radius = 8]) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: this,
  );
  Widget shadowSm([double radius = 8, double elevation = 2]) => Material(
    elevation: elevation,
    borderRadius: BorderRadius.circular(radius),
    child: this,
  );
  Widget withBorder({Color color = Colors.black54, double width = 1.0}) => Container(
    decoration: BoxDecoration(border: Border.all(color: color, width: width)),
    child: this,
  );
}

// ------------------ Flex Extensions ------------------
extension FlexExtensions on Widget {
  Widget flex([int flex = 1]) => Expanded(flex: flex, child: this);
  Widget flexible([int flex = 1]) => Flexible(flex: flex, child: this);
}

// ------------------ Gesture Extensions ------------------
extension GestureExtensions on Widget {
  Widget onTap(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: this,
  );

  Widget onLongPress(VoidCallback onLongPress) => GestureDetector(
    onLongPress: onLongPress,
    behavior: HitTestBehavior.opaque,
    child: this,
  );
}

// ------------------ Visibility Extensions ------------------
extension VisibilityExtensions on Widget {
  Widget visible(bool visible) => visible ? this : const SizedBox.shrink();
  Widget invisible(bool invisible) => invisible ? const SizedBox.shrink() : this;
  Widget show(bool condition, {Widget? fallback}) => condition ? this : (fallback ?? const SizedBox.shrink());
}

// ------------------ Misc Extensions ------------------
extension MiscExtensions on Widget {
  Widget opacity(double opacity) => Opacity(opacity: opacity, child: this);
  Widget constrained({double? maxWidth, double? minWidth, double? maxHeight, double? minHeight}) =>
      ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? double.infinity,
          minWidth: minWidth ?? 0,
          maxHeight: maxHeight ?? double.infinity,
          minHeight: minHeight ?? 0,
        ),
        child: this,
      );
  Widget safeArea({bool top = true, bool bottom = true}) =>
      SafeArea(top: top, bottom: bottom, child: this);
  Widget scrollable({Axis axis = Axis.vertical}) =>
      SingleChildScrollView(scrollDirection: axis, child: this);
}

// ------------------ AspectRatio Extensions ------------------
extension AspectRatioExtension on Widget {
  Widget aspectRatio(double ratio) => AspectRatio(aspectRatio: ratio, child: this);
}

// ------------------ BuildContext Extensions ------------------
extension ContextExtensions on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  bool get isTablet => screenWidth >= 600;
  bool get isDesktop => screenWidth >= 1024;
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  NavigatorState get navigator => Navigator.of(this);
  void pop<T extends Object?>([T? result]) => navigator.pop(result);
  void push(Widget page) => navigator.push(MaterialPageRoute(builder: (_) => page));
}

// ------------------ TextStyle Extensions ------------------
extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  TextStyle textSize(double size) => copyWith(fontSize: size);
  TextStyle textColor(Color color) => copyWith(color: color);
  TextStyle letterSpacing(double spacing) => copyWith(letterSpacing: spacing);
  TextStyle height(double lineHeight) => copyWith(height: lineHeight);
}

// ------------------ ThemeData Extensions ------------------
// extension ThemeDataExtensions on ThemeData {
//   TextStyle get heading => textTheme.headline6!.bold;
//   TextStyle get subheading => textTheme.subtitle1!.semiBold;
//   TextStyle get body => textTheme.bodyText2!;
//   TextStyle get caption => textTheme.caption!;
// }

// ------------------ Color Extensions ------------------
extension HexColor on String {
  Color toColor() {
    String hex = this.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF' + hex; // 加上不透明的 alpha 頭
    }
    return Color(int.parse(hex, radix: 16));
  }
}

extension ColorUtils on Color {
  Color lighten([double amount = 0.1]) {
    final hsl = HSLColor.fromColor(this);
    final lightened = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lightened.toColor();
  }

  Color darken([double amount = 0.1]) {
    final hsl = HSLColor.fromColor(this);
    final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }
}

// ------------------ End ------------------