import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_focus_frame.dart';

/// ปุ่มหลักขนาด TV — กด OK บนรีโมท (select/enter) = กดปุ่ม
class TvButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool loading;

  const TvButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TvFocusFrame(
      child: SizedBox(
        width: double.infinity,
        height: AppTheme.buttonHeight,
        child: FilledButton(
          focusNode: focusNode,
          autofocus: autofocus,
          // ระหว่าง loading ยังให้ focus อยู่ที่ปุ่ม แต่กดซ้ำไม่ได้
          onPressed: loading ? () {} : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontFamily: AppTheme.fontFamily,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
          ),
          child: loading
              ? SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Text(text),
        ),
      ),
    );
  }
}

/// ปุ่ม Go Back — ทำงานเหมือนปุ่ม Back บนรีโมท (หน้าไหนดัก Back ด้วย PopScope ก็ได้ผลเดียวกัน)
class TvBackButton extends StatelessWidget {
  const TvBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TvTextButton(
      icon: Icons.chevron_left,
      text: 'Go Back',
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

/// ปุ่มรอง (ไอคอน + ข้อความ) เช่น สลับธีม, แสดงรหัส
class TvTextButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  const TvTextButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onPressed,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TvFocusFrame(
      child: TextButton.icon(
        focusNode: focusNode,
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(text),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontFamily: AppTheme.fontFamily,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
        ),
      ),
    );
  }
}
