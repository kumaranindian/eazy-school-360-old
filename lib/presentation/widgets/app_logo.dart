import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double? size;
  final Color? color;
  final bool? useImage;

  const AppLogo({
    Key? key,
    this.size,
    this.color,
    this.useImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/images/eazyschool.png',
        width: size ?? 120,
        height: size ?? 120,
        fit: BoxFit.contain,
      ),
    );
  }
}
