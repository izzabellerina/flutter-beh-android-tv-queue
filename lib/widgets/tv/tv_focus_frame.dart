import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';

/// กรอบ + ขยายเล็กน้อยเมื่อ widget ข้างใน (หรือลูกหลาน) ถูกรีโมทเลือกอยู่
///
/// ไม่รับ focus เอง — ห่อ widget ที่ focus ได้อยู่แล้ว เช่น ปุ่ม, InkWell, TvTextField
class TvFocusFrame extends StatefulWidget {
  final Widget child;
  final double scale;
  final BorderRadius borderRadius;

  const TvFocusFrame({
    super.key,
    required this.child,
    this.scale = 1.04,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppTheme.radius + AppTheme.focusRingWidth),
    ),
  });

  @override
  State<TvFocusFrame> createState() => _TvFocusFrameState();
}

class _TvFocusFrameState extends State<TvFocusFrame> {
  bool _focused = false;

  static const _duration = Duration(milliseconds: 140);

  @override
  Widget build(BuildContext context) {
    final ring = TvColors.of(context).focusRing;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: AnimatedScale(
        scale: _focused ? widget.scale : 1,
        duration: _duration,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: _duration,
          padding: const EdgeInsets.all(AppTheme.focusRingWidth),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              width: AppTheme.focusRingWidth,
              color: _focused ? ring : Colors.transparent,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: ring.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
