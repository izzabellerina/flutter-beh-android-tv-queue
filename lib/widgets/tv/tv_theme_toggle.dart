import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/helper/shared_preference_helper.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_button.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_focus_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ปุ่มสลับโหมดสว่าง/มืด — ใช้ทุกหน้า, บันทึกค่าไว้ใช้ตอนเปิดแอปครั้งถัดไป
class TvThemeToggle extends ConsumerWidget {
  final FocusNode? focusNode;

  /// ไอคอนอย่างเดียว — หน้าที่แถวบนเต็ม (หน้าเลือกคิว)
  final bool compact;

  const TvThemeToggle({super.key, this.focusNode, this.compact = false});

  static Future<void> toggle(WidgetRef ref) async {
    final notifier = ref.read(themeModeProvider.notifier);
    final next = notifier.state == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    notifier.state = next;
    await SharedPreferenceHelper.setThemeMode(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final icon = isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined;
    final label = isDark ? 'โหมดสว่าง' : 'โหมดมืด';

    if (compact) {
      return TvFocusFrame(
        child: IconButton(
          focusNode: focusNode,
          tooltip: label,
          onPressed: () => toggle(ref),
          icon: Icon(icon, size: 26),
          color: Theme.of(context).colorScheme.onSurface,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
          ),
        ),
      );
    }

    return TvTextButton(
      focusNode: focusNode,
      icon: icon,
      text: label,
      onPressed: () => toggle(ref),
    );
  }
}
