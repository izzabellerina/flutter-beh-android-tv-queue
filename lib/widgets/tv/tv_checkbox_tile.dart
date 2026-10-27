import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_focus_frame.dart';

/// แถว checkbox ทั้งแถวเป็นจุด focus เดียว — กด OK = สลับค่า
class TvCheckboxTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final FocusNode? focusNode;

  const TvCheckboxTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TvFocusFrame(
      scale: 1.02,
      child: InkWell(
        focusNode: focusNode,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // ExcludeFocus: ไม่ต้องกดลงไปที่ checkbox อีกชั้น
              ExcludeFocus(
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                ),
              ),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
