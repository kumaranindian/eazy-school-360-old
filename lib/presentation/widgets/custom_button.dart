import 'package:flutter/material.dart';

enum ButtonType {
  primary,
  secondary,
  outlined,
  text,
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType buttonType;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.buttonType = ButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(text),
            ],
          );

    switch (buttonType) {
      case ButtonType.primary:
        return SizedBox(
          width: width,
          height: height ?? 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: child,
          ),
        );
      case ButtonType.secondary:
        return SizedBox(
          width: width,
          height: height ?? 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
            ),
            child: child,
          ),
        );
      case ButtonType.outlined:
        return SizedBox(
          width: width,
          height: height ?? 48,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            child: child,
          ),
        );
      case ButtonType.text:
        return SizedBox(
          width: width,
          height: height ?? 48,
          child: TextButton(
            onPressed: isLoading ? null : onPressed,
            child: child,
          ),
        );
    }
  }
}
