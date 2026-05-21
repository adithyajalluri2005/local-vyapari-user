import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomSnackBar {
  static void show({
    required BuildContext context,
    required String message,
    String? title,
    Color backgroundColor = const Color(0xFF1E293B),
    Color accentColor = AppTheme.primaryColor,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: accentColor, width: 6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title ?? 'Notification',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
                child: const Icon(
                  Icons.close,
                  color: Colors.white54,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showError({
    required BuildContext context,
    required String message,
    String title = 'Error',
  }) {
    show(
      context: context,
      message: message,
      title: title,
      accentColor: AppTheme.errorColor,
      icon: Icons.error_outline,
    );
  }

  static void showSuccess({
    required BuildContext context,
    required String message,
    String title = 'Success',
  }) {
    show(
      context: context,
      message: message,
      title: title,
      accentColor: AppTheme.successColor,
      icon: Icons.check_circle_outline,
    );
  }

  static void showInfo({
    required BuildContext context,
    required String message,
    String title = 'Info',
  }) {
    show(
      context: context,
      message: message,
      title: title,
      accentColor: AppTheme.primaryColor,
      icon: Icons.info_outline,
    );
  }

  static void showWarning({
    required BuildContext context,
    required String message,
    String title = 'Warning',
  }) {
    show(
      context: context,
      message: message,
      title: title,
      accentColor: Colors.amber,
      icon: Icons.warning_amber_outlined,
    );
  }
}
