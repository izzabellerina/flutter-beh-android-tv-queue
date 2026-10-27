import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/enum/queue_mode.dart';
import 'package:flutter_android_tv_queue/helper/queue_setup_helper.dart';
import 'package:flutter_android_tv_queue/helper/session_helper.dart';
import 'package:flutter_android_tv_queue/helper/shared_preference_helper.dart';
import 'package:flutter_android_tv_queue/models/queue_slot_selection.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/routes/router_path.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_button.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_focus_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// หน้าเลือกระบบคิว (รูป 1) — Back / Go Back = ออกจากระบบ
class QueueModePage extends ConsumerStatefulWidget {
  const QueueModePage({super.key});

  @override
  ConsumerState<QueueModePage> createState() => _QueueModePageState();
}

class _QueueModePageState extends ConsumerState<QueueModePage> {
  final _modeFocus = {
    for (final mode in QueueMode.values)
      mode: FocusNode(debugLabel: 'mode-${mode.name}'),
  };

  @override
  void initState() {
    super.initState();
    _loadSavedSetup();
  }

  @override
  void dispose() {
    for (final node in _modeFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// เติมค่าที่เคยเลือก + focus โหมดเดิม (กด OK ครั้งเดียวไปต่อได้)
  Future<void> _loadSavedSetup() async {
    final saved = await SharedPreferenceHelper.getQueueSetup();
    if (!mounted) return;

    if (saved != null) QueueSetupHelper.apply(ref, saved);
    _modeFocus[ref.read(queueModeProvider)]!.requestFocus();
  }

  void _select(QueueMode mode) {
    ref.read(queueModeProvider.notifier).state = mode;

    // ปรับจำนวนชุดตามโหมด — เก็บค่าชุดที่มีอยู่ไว้
    final slots = ref.read(queueSlotsProvider);
    ref.read(queueSlotsProvider.notifier).state = [
      for (var i = 0; i < mode.slotCount; i++)
        i < slots.length ? slots[i] : const QueueSlotSelection(),
    ];

    context.push(RouterPath.queueSetup);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SessionHelper.logout(context, ref);
      },
      child: Scaffold(
        body: Padding(
          padding: AppTheme.overscanPadding,
          child: Column(
            children: [
              Text('เลือกระบบคิว', style: theme.textTheme.headlineMedium),
              Text(
                'เลือกรูปแบบการแสดงคิวบนจอนี้',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: TvColors.of(context).mutedText,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final mode in QueueMode.values) ...[
                        if (mode != QueueMode.values.first)
                          const SizedBox(width: 40),
                        _ModeCard(
                          mode: mode,
                          focusNode: _modeFocus[mode]!,
                          onPressed: () => _select(mode),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: TvBackButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final QueueMode mode;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  const _ModeCard({
    required this.mode,
    required this.focusNode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TvFocusFrame(
      scale: 1.06,
      borderRadius: BorderRadius.circular(26),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          focusNode: focusNode,
          onTap: onPressed,
          child: SizedBox(
            width: 300,
            height: 250,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ScreenPreview(slots: mode.slotCount),
                const SizedBox(height: 20),
                Text(mode.label, style: theme.textTheme.headlineSmall),
                Text(
                  mode.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: TvColors.of(context).mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ภาพจอทีวีจำลอง แบ่งเป็น 1 หรือ 2 ช่อง
class _ScreenPreview extends StatelessWidget {
  final int slots;

  const _ScreenPreview({required this.slots});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 150,
      height: 86,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline, width: 3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (var i = 0; i < slots; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
