import 'package:flutter_android_tv_queue/helper/shared_preference_helper.dart';
import 'package:flutter_android_tv_queue/models/queue_slot_selection.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QueueSetupHelper {
  /// ใส่ค่าที่บันทึกไว้ลง provider (จำนวนชุดตามโหมดเสมอ)
  static void apply(WidgetRef ref, SavedQueueSetup saved) {
    ref.read(queueModeProvider.notifier).state = saved.mode;
    ref.read(displayRotationProvider.notifier).state = saved.rotation;
    ref.read(voiceEnabledProvider.notifier).state = saved.voiceEnabled;
    ref.read(queueSlotsProvider.notifier).state = [
      for (var i = 0; i < saved.mode.slotCount; i++)
        i < saved.slots.length ? saved.slots[i] : const QueueSlotSelection(),
    ];
  }

  static SavedQueueSetup current(WidgetRef ref) => (
    mode: ref.read(queueModeProvider),
    slots: ref.read(queueSlotsProvider),
    rotation: ref.read(displayRotationProvider),
    voiceEnabled: ref.read(voiceEnabledProvider),
  );

  /// พร้อมเข้าจอคิวได้เลยไหม (ใช้ตอนเปิดแอปอัตโนมัติ)
  static bool isComplete(SavedQueueSetup saved) =>
      saved.slots.length >= saved.mode.slotCount &&
      saved.slots
          .take(saved.mode.slotCount)
          .every((slot) => slot.validate() == null);
}
