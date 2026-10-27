import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_android_tv_queue/helper/device_input.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_focus_frame.dart';

/// ช่องกรอกข้อความที่ใช้กับรีโมท TV ได้
///
/// ปัญหาของ TextField บน TV: พอ focus เข้าไปคีย์บอร์ดเด้งทันที และลูกศรถูกใช้ขยับ cursor
/// ทำให้ผู้ใช้เลื่อนออกจากช่องไม่ได้ จึงแยกเป็น 2 ชั้น:
/// - ชั้นนอก ([focusNode]) — ตัวที่รีโมทเลื่อนผ่าน ยังไม่เปิดคีย์บอร์ด
/// - ชั้นใน (TextField) — เข้าเมื่อกด OK, ออกด้วยลูกศรขึ้น/ลง หรือกดถัดไป/เสร็จบนคีย์บอร์ด
class TvTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputAction textInputAction;

  /// เรียกเมื่อกดถัดไป/เสร็จบนคีย์บอร์ด — ถ้าไม่ส่งมา จะเลื่อน focus ลงไปตัวถัดไป
  final VoidCallback? onSubmitted;

  const TvTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  final _editNode = FocusNode(
    debugLabel: 'TvTextField.edit',
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    _editNode.addListener(_rebuild);
  }

  @override
  void dispose() {
    _editNode
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _startEditing() => _editNode.requestFocus();

  /// กลับไปชั้นนอกก่อน แล้วค่อยเลื่อนตามทิศ — directional traversal คำนวณจาก
  /// primary focus จริง ซึ่งการเปลี่ยน focus มีผลใน microtask ถัดไป
  void _leave(TraversalDirection direction) {
    widget.focusNode.requestFocus();
    Future.microtask(() => widget.focusNode.focusInDirection(direction));
  }

  void _handleSubmitted(String _) {
    if (widget.onSubmitted != null) {
      widget.focusNode.requestFocus();
      widget.onSubmitted!();
    } else {
      _leave(TraversalDirection.down);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TvColors.of(context).mutedText;
    final editing = _editNode.hasFocus;

    return TvFocusFrame(
      scale: editing ? 1 : 1.04,
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _startEditing(),
          ),
        },
        child: Focus(
          focusNode: widget.focusNode,
          child: GestureDetector(
            onTap: _startEditing,
            child: Container(
              height: AppTheme.fieldHeight,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: editing
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(widget.icon, color: muted, size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(theme, muted)),
                  if (editing)
                    Text(
                      'แก้ไขอยู่',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(ThemeData theme, Color muted) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowUp): _LeaveFieldIntent(
          TraversalDirection.up,
        ),
        SingleActivator(LogicalKeyboardKey.arrowDown): _LeaveFieldIntent(
          TraversalDirection.down,
        ),
      },
      child: Actions(
        actions: {
          _LeaveFieldIntent: CallbackAction<_LeaveFieldIntent>(
            onInvoke: (intent) => _leave(intent.direction),
          ),
        },
        child: TextField(
          controller: widget.controller,
          focusNode: _editNode,
          obscureText: widget.obscureText,
          // none = ไม่ขอคีย์บอร์ดบนจอ แต่ยังรับปุ่มจากคีย์บอร์ดจริง (debug บน emulator)
          keyboardType: DeviceInput.hideSoftKeyboard
              ? TextInputType.none
              : null,
          textInputAction: widget.textInputAction,
          onSubmitted: _handleSubmitted,
          // กัน EditableText เลื่อน focus เอง (nextFocus/unfocus) ซ้อนกับ _handleSubmitted
          onEditingComplete: () {},
          style: theme.textTheme.bodyLarge,
          maxLines: 1,
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: widget.hintText,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(color: muted),
          ),
        ),
      ),
    );
  }
}

class _LeaveFieldIntent extends Intent {
  final TraversalDirection direction;

  const _LeaveFieldIntent(this.direction);
}
