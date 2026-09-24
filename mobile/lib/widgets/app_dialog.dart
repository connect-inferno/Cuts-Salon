import 'package:flutter/material.dart';
import '../theme.dart';

/// Shared modal shell for every dialog in the app - an icon badge + title
/// header, scrollable form body, and a full-width two-button footer
/// (secondary outlined + primary filled) instead of the cramped top-right
/// text-link actions a bare AlertDialog defaults to.
class AppDialog extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackground;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget actions;
  final double maxWidth;

  const AppDialog({
    super.key,
    required this.icon,
    this.iconColor,
    this.iconBackground,
    required this.title,
    this.subtitle,
    required this.child,
    required this.actions,
    this.maxWidth = 440,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBackground ?? AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor ?? AppTheme.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.slateDark)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppTheme.slateLight)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(child: SingleChildScrollView(child: child)),
              const SizedBox(height: 22),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard footer for [AppDialog]: a secondary outlined button beside a
/// primary filled one, both full-width-shared so neither reads as an
/// afterthought the way default AlertDialog text-button actions do.
class AppDialogActions extends StatelessWidget {
  final String cancelLabel;
  final VoidCallback? onCancel;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final bool submitting;
  final Color? submitColor;

  const AppDialogActions({
    super.key,
    this.cancelLabel = 'Cancel',
    required this.onCancel,
    required this.submitLabel,
    required this.onSubmit,
    this.submitting = false,
    this.submitColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: submitting ? null : onCancel,
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: submitting ? null : onSubmit,
            style: submitColor == null ? null : ElevatedButton.styleFrom(backgroundColor: submitColor),
            child: submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(submitLabel),
          ),
        ),
      ],
    );
  }
}

/// Prefix-iconed field decoration matching the login screen's inputs -
/// the theme already fills/rounds every TextField, this just adds the
/// leading icon so dialog forms read as designed rather than bare labels.
InputDecoration appDialogFieldDecoration({required String label, String? hint, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 19),
  );
}
