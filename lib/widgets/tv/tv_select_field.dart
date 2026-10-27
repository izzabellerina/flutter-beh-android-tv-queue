import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_button.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_focus_frame.dart';

/// ช่องเลือกหน้าตาแบบ dropdown — กด OK แล้วเปิด [showTvSelectSheet]
///
/// ไม่ใช้ DropdownButton เพราะเมนูเล็ก ติดกับช่อง อ่านจากโซฟาไม่ถนัด และรายการยาวเห็นทีละน้อย
class TvSelectField extends StatelessWidget {
  final String label;
  final String? valueText;
  final String placeholder;
  final Widget? leading;

  /// null = ปิดใช้งาน (ยังเลือกตัวก่อนหน้าไม่ครบ) — รีโมทข้ามช่องนี้
  final VoidCallback? onPressed;
  final bool autofocus;
  final double labelWidth;

  const TvSelectField({
    super.key,
    required this.label,
    required this.valueText,
    required this.placeholder,
    required this.onPressed,
    this.leading,
    this.autofocus = false,
    this.labelWidth = 104,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TvColors.of(context).mutedText;
    final enabled = onPressed != null;
    final hasValue = valueText != null && valueText!.isNotEmpty;

    // label อยู่ซ้ายของช่อง (ไม่ใช่ด้านบน) — คิวคู่ 2 ฟอร์มต้องพอดีความสูงจอ 540 dp
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(color: muted),
              ),
            ),
          ),
          Expanded(
            child: TvFocusFrame(
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  autofocus: autofocus && enabled,
                  onTap: onPressed,
                  child: SizedBox(
                    height: AppTheme.fieldHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          if (leading != null) ...[
                            leading!,
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              hasValue ? valueText! : placeholder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: hasValue ? null : muted,
                              ),
                            ),
                          ),
                          Icon(Icons.expand_more, size: 30, color: muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ค่าที่ sheet คืนเมื่อผู้ใช้เลือก — แยกจาก null (= ปิด sheet โดยไม่เลือก)
/// เพื่อให้มีตัวเลือก "ไม่ระบุ" ที่มีค่าเป็น null ได้
class TvSelectResult<T> {
  final T? value;

  const TvSelectResult(this.value);
}

/// แผงรายการเต็มความสูงจอฝั่งขวา ตัวใหญ่ อ่านจากโซฟาได้
///
/// - focus เริ่มที่รายการที่เลือกอยู่ ([isSelected]) ไม่งั้นรายการแรก
/// - [load] ถูกเรียกตอนเปิด และตอนกด "ลองใหม่"
/// - [noneLabel] ไม่ null = มีตัวเลือก "ไม่ระบุ" อยู่บนสุด
/// - Back บนรีโมท = ปิด (คืน null)
Future<TvSelectResult<T>?> showTvSelectSheet<T>({
  required BuildContext context,
  required String title,
  required Future<List<T>> Function() load,
  required String Function(T item) labelOf,
  String? Function(T item)? subtitleOf,
  Widget? Function(T item)? leadingOf,
  bool Function(T item)? isSelected,
  String? noneLabel,
  String emptyText = 'ไม่มีข้อมูล',
}) {
  return showGeneralDialog<TvSelectResult<T>>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(0.15, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: FadeTransition(opacity: animation, child: child),
    ),
    pageBuilder: (context, _, _) => _TvSelectSheet<T>(
      title: title,
      load: load,
      labelOf: labelOf,
      subtitleOf: subtitleOf,
      leadingOf: leadingOf,
      isSelected: isSelected,
      noneLabel: noneLabel,
      emptyText: emptyText,
    ),
  );
}

class _TvSelectSheet<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function() load;
  final String Function(T item) labelOf;
  final String? Function(T item)? subtitleOf;
  final Widget? Function(T item)? leadingOf;
  final bool Function(T item)? isSelected;
  final String? noneLabel;
  final String emptyText;

  const _TvSelectSheet({
    required this.title,
    required this.load,
    required this.labelOf,
    required this.subtitleOf,
    required this.leadingOf,
    required this.isSelected,
    required this.noneLabel,
    required this.emptyText,
  });

  @override
  State<_TvSelectSheet<T>> createState() => _TvSelectSheetState<T>();
}

class _TvSelectSheetState<T> extends State<_TvSelectSheet<T>> {
  static const _itemExtent = 72.0;

  late Future<List<T>> _future = widget.load();

  /// สร้างครั้งเดียวต่อการโหลด (ต้องรู้ตำแหน่งรายการที่เลือกก่อน)
  ScrollController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _retry() {
    _controller?.dispose();
    _controller = null;
    setState(() {
      _future = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 12,
        child: SizedBox(
          width: 440,
          height: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 27, 40, 27),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.title, style: theme.textTheme.headlineSmall),
                Text(
                  'กด OK เพื่อเลือก · Back เพื่อปิด',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: TvColors.of(context).mutedText,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<T>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) return _buildError(theme);
                      return _buildList(theme, snapshot.data ?? []);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 8),
        Text('โหลดข้อมูลไม่สำเร็จ', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        TvButton(text: 'ลองใหม่', autofocus: true, onPressed: _retry),
      ],
    );
  }

  Widget _buildList(ThemeData theme, List<T> items) {
    final hasNone = widget.noneLabel != null;
    final count = items.length + (hasNone ? 1 : 0);

    if (items.isEmpty && !hasNone) {
      return Center(
        child: Text(widget.emptyText, style: theme.textTheme.titleMedium),
      );
    }

    // focus เริ่มที่ค่าที่เลือกอยู่ — เลื่อนให้รายการนั้นถูกสร้าง (ListView.builder สร้างเฉพาะที่เห็น)
    final selectedItem = items.indexWhere(
      (e) => widget.isSelected?.call(e) ?? false,
    );
    final focusIndex = selectedItem < 0 ? 0 : selectedItem + (hasNone ? 1 : 0);
    final controller = _controller ??= ScrollController(
      initialScrollOffset: (focusIndex * _itemExtent - _itemExtent * 2).clamp(
        0,
        double.infinity,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.emptyText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: TvColors.of(context).mutedText,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: controller,
            itemExtent: _itemExtent,
            itemCount: count,
            itemBuilder: (context, index) {
              final autofocus = index == focusIndex;

              if (hasNone && index == 0) {
                return _SheetItem(
                  label: widget.noneLabel!,
                  autofocus: autofocus,
                  onTap: () =>
                      Navigator.of(context).pop(TvSelectResult<T>(null)),
                );
              }

              final item = items[index - (hasNone ? 1 : 0)];
              return _SheetItem(
                label: widget.labelOf(item),
                subtitle: widget.subtitleOf?.call(item),
                leading: widget.leadingOf?.call(item),
                selected: widget.isSelected?.call(item) ?? false,
                autofocus: autofocus,
                onTap: () => Navigator.of(context).pop(TvSelectResult<T>(item)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SheetItem extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  const _SheetItem({
    required this.label,
    required this.autofocus,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: TvFocusFrame(
        scale: 1.02,
        child: Material(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            autofocus: autofocus,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: TvColors.of(context).mutedText,
                              height: 1.1,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
