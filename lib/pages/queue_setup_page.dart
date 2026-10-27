import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/enum/display_rotation.dart';
import 'package:flutter_android_tv_queue/enum/queue_mode.dart';
import 'package:flutter_android_tv_queue/controller/queue_voice_announcer.dart';
import 'package:flutter_android_tv_queue/helper/queue_setup_helper.dart';
import 'package:flutter_android_tv_queue/helper/queue_voice_helper.dart';
import 'package:flutter_android_tv_queue/helper/shared_preference_helper.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/routes/router_path.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/queue_slot_form.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_button.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_select_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// หน้าตั้งค่าคิว — คิวเดี่ยว 1 ฟอร์ม (รูป 2), คิวคู่ 2 ฟอร์มซ้าย–ขวา (รูป 3)
class QueueSetupPage extends ConsumerStatefulWidget {
  const QueueSetupPage({super.key});

  @override
  ConsumerState<QueueSetupPage> createState() => _QueueSetupPageState();
}

class _QueueSetupPageState extends ConsumerState<QueueSetupPage>
    with QueueVoiceMixin {
  final _startFocus = FocusNode(debugLabel: 'start');
  String? _errorText;

  /// ข้อความสถานะทั่วไป (ไม่ใช่ error) เช่น ผลทดสอบเสียง
  String? _statusText;
  QueueVoiceAnnouncer? _testAnnouncer;

  @override
  void dispose() {
    _startFocus.dispose();
    _testAnnouncer?.dispose();
    super.dispose();
  }

  void _toggleVoice() {
    final notifier = ref.read(voiceEnabledProvider.notifier);
    notifier.state = !notifier.state;
  }

  /// เรียก get-voice จริงด้วยคิวตัวอย่าง — ให้คนติดตั้งเช็คลำโพง/ระดับเสียงหน้างาน
  static const _voiceLoading = 'กำลังโหลดเสียงทดสอบ…';
  static const _voicePlaying = 'กำลังเล่นเสียงทดสอบ…';

  void _testVoice() {
    final announcer = _testAnnouncer ??= _createTestAnnouncer();
    setState(() => _statusText = _voiceLoading);
    announcer.announce(
      VoiceAnnouncement(
        // ไม่ให้กันซ้ำเมื่อกดทดสอบติดกัน
        bookNo: 'test-${DateTime.now().microsecondsSinceEpoch}',
        publicQueue: 'A001',
        nameTh: 'ช่อง 1',
        nameEn: 'Channel 1',
      ),
    );
  }

  /// สถานะตามจริง: โหลด → เล่น → เสร็จ / ไม่สำเร็จ
  QueueVoiceAnnouncer _createTestAnnouncer() {
    final announcer = createVoiceAnnouncer(prefixes: () => const {});
    announcer.onError = (_) {
      if (mounted) setState(() => _statusText = 'ทดสอบเสียงไม่สำเร็จ');
    };
    announcer.announcing.addListener(() {
      if (!mounted) return;
      if (announcer.announcing.value != null) {
        setState(() => _statusText = _voicePlaying);
      } else if (_statusText == _voicePlaying) {
        setState(() => _statusText = 'เล่นเสียงทดสอบเสร็จแล้ว');
      }
    });
    return announcer;
  }

  Future<void> _start() async {
    final mode = ref.read(queueModeProvider);
    final slots = ref.read(queueSlotsProvider);

    for (var i = 0; i < slots.length; i++) {
      final error = slots[i].validate();
      if (error != null) {
        setState(() {
          _errorText = mode == QueueMode.dual
              ? 'คิวที่ ${i + 1}: $error'
              : error;
        });
        return;
      }
    }

    setState(() => _errorText = null);
    await SharedPreferenceHelper.setQueueSetup(QueueSetupHelper.current(ref));
    if (!mounted) return;
    context.push(RouterPath.queueDisplay);
  }

  Future<void> _pickRotation() async {
    final selected = ref.read(displayRotationProvider);
    final result = await showTvSelectSheet<DisplayRotation>(
      context: context,
      title: 'การวางจอ',
      load: () async => DisplayRotation.values,
      labelOf: (r) => r.label,
      subtitleOf: (r) => r.isPortrait
          ? 'ทีวีติดตั้งแนวตั้ง — ลองข้างไหนก็ได้ที่ภาพตั้งตรง'
          : 'ทีวีติดตั้งแนวนอน',
      isSelected: (r) => r == selected,
    );

    final rotation = result?.value;
    if (rotation != null) {
      ref.read(displayRotationProvider.notifier).state = rotation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = ref.watch(queueModeProvider);
    final voiceEnabled = ref.watch(voiceEnabledProvider);

    return Scaffold(
      body: Padding(
        padding: AppTheme.overscanPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Go Back อยู่บน (ไม่ใช่ล่างซ้ายตามรูป) — ไม่งั้นกดลงจากคอลัมน์ซ้าย
            // focus จะไปโดน Go Back แทนปุ่ม "เริ่มแสดงคิว"
            Row(
              children: [
                const TvBackButton(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'เลือกคิว · ${mode.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                TvTextButton(
                  icon: voiceEnabled ? Icons.volume_up : Icons.volume_off,
                  text: voiceEnabled ? 'เสียง: เปิด' : 'เสียง: ปิด',
                  onPressed: _toggleVoice,
                ),
                const SizedBox(width: 8),
                TvTextButton(
                  icon: Icons.campaign_outlined,
                  text: 'ทดสอบเสียง',
                  onPressed: _testVoice,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: mode == QueueMode.single
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 480,
                          child: _FormCard(
                            child: const QueueSlotForm(
                              index: 0,
                              autofocus: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // คิวเดี่ยว = ทีวีแนวตั้ง (คิวคู่แนวนอนเสมอ)
                        SizedBox(
                          width: 320,
                          child: TvSelectField(
                            label: 'จอ',
                            labelWidth: 48,
                            valueText: ref.watch(displayRotationProvider).label,
                            placeholder: '',
                            onPressed: _pickRotation,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _FormCard(
                            child: const QueueSlotForm(
                              index: 0,
                              title: 'คิวที่ 1',
                              autofocus: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _FormCard(
                            child: const QueueSlotForm(
                              index: 1,
                              title: 'คิวที่ 2',
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _buildBottomBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _errorText == null
              ? Text(
                  _statusText ?? '',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: TvColors.of(context).mutedText,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _errorText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 260,
          child: TvButton(
            text: 'เริ่มแสดงคิว',
            focusNode: _startFocus,
            onPressed: _start,
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      // scroll เผื่อจอเล็ก/ตัวใหญ่ — เลื่อน focus แล้ว Flutter เลื่อนให้เห็นเอง
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: child,
      ),
    );
  }
}
