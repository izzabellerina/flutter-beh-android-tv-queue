import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/helper/queue_date.dart';
import 'package:flutter_android_tv_queue/models/queue_config_call_queue_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_type_model.dart';
import 'package:flutter_android_tv_queue/models/queue_slot_selection.dart';
import 'package:flutter_android_tv_queue/models/response_model.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/service/configuration.dart';
import 'package:flutter_android_tv_queue/service/customer_service.dart';
import 'package:flutter_android_tv_queue/service/general_service.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_checkbox_tile.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_select_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ฟอร์มคิว 1 ชุด: TYPE → STATION → DOCTOR + AUTO ROTATION
/// อ่าน/เขียน `queueSlotsProvider[index]`
class QueueSlotForm extends ConsumerStatefulWidget {
  final int index;
  final String? title;
  final bool autofocus;

  const QueueSlotForm({
    super.key,
    required this.index,
    this.title,
    this.autofocus = false,
  });

  @override
  ConsumerState<QueueSlotForm> createState() => _QueueSlotFormState();
}

class _QueueSlotFormState extends ConsumerState<QueueSlotForm> {
  // cache รายการ — เปิด sheet ซ้ำไม่ต้องโหลดใหม่; โหลดพลาดจะถูกลบออกให้ "ลองใหม่" ได้
  final _types = <int, Future<List<QueueConfigTypeModel>>>{};
  final _stations = <int, Future<List<QueueConfigModel>>>{};

  /// key = "queueType|วันที่ไทย" → ข้ามเที่ยงคืนแล้วโหลดแพทย์ของวันใหม่เอง
  final _doctors = <String, Future<List<ScheduledDoctor>>>{};

  QueueSlotSelection get _slot => ref.read(queueSlotsProvider)[widget.index];

  void _update(QueueSlotSelection Function(QueueSlotSelection slot) change) {
    final notifier = ref.read(queueSlotsProvider.notifier);
    final slots = [...notifier.state];
    slots[widget.index] = change(slots[widget.index]);
    notifier.state = slots;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slot = ref.watch(queueSlotsProvider)[widget.index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              widget.title!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        TvSelectField(
          label: 'TYPE',
          valueText: slot.type == null ? null : typeName(slot.type!),
          placeholder: 'select type',
          autofocus: widget.autofocus,
          onPressed: _pickType,
        ),
        const SizedBox(height: 8),
        TvSelectField(
          label: 'STATION',
          valueText: slot.station == null ? null : stationName(slot.station!),
          placeholder: slot.type == null ? 'เลือก TYPE ก่อน' : 'select station',
          onPressed: slot.type == null ? null : _pickStation,
        ),
        const SizedBox(height: 8),
        TvSelectField(
          label: 'DOCTOR',
          valueText: slot.doctor?.fullnameWithMid,
          placeholder: slot.station == null
              ? 'เลือก STATION ก่อน'
              : 'select doctor',
          leading: slot.doctor == null
              ? null
              : DoctorAvatar(path: slot.doctor!.avatarImagePath, size: 28),
          onPressed: slot.station == null ? null : _pickDoctor,
        ),
        const SizedBox(height: 8),
        TvCheckboxTile(
          value: slot.autoRotation,
          label: 'AUTO ROTATION (วนทุก STATION)',
          onChanged: (value) => _update((s) => s.withAutoRotation(value)),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PICKERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _pickType() async {
    final selectedId = _slot.type?.id;
    final result = await showTvSelectSheet<QueueConfigTypeModel>(
      context: context,
      title: 'เลือก TYPE',
      load: () => _memo(_types, 0, () async {
        return _unwrap(
          await GeneralService.getAllQueueConfigType(
            context,
            client: ref.read(httpClientProvider),
          ),
        );
      }),
      labelOf: typeName,
      isSelected: (t) => t.id == selectedId,
    );

    final type = result?.value;
    if (type != null) _update((s) => s.selectType(type));
  }

  Future<void> _pickStation() async {
    final typeId = _slot.type!.id;
    final selectedQueueType = _slot.station?.queueType;
    final result = await showTvSelectSheet<QueueConfigModel>(
      context: context,
      title: 'เลือก STATION',
      load: () => _memo(_stations, typeId, () async {
        return _unwrap(
          await GeneralService.getAllQueueConfig(
            context,
            queueConfigTypeId: typeId,
            client: ref.read(httpClientProvider),
          ),
        );
      }),
      labelOf: stationName,
      subtitleOf: (s) =>
          s.prefix.isEmpty ? s.queueType : '${s.queueType} · ${s.prefix}',
      isSelected: (s) => s.queueType == selectedQueueType,
      emptyText: 'TYPE นี้ยังไม่มี STATION',
    );

    final station = result?.value;
    if (station != null) _update((s) => s.selectStation(station));
  }

  Future<void> _pickDoctor() async {
    final queueType = _slot.station!.queueType;
    final selectedEmp = _slot.doctor?.emp;
    final date = QueueDate.today();
    final result = await showTvSelectSheet<ScheduledDoctor>(
      context: context,
      title: 'เลือก DOCTOR',
      load: () => _memo(_doctors, '$queueType|$date', () async {
        final response =
            await CustomerService.getOneQueueConfigCallQueueByQueueType(
              context,
              queueType: queueType,
              date: date,
              client: ref.read(httpClientProvider),
            );
        if (response.responseEnum != ResponseEnum.success) {
          throw Exception('getOneQueueConfigCallQueueByQueueType failed');
        }
        return response.data.scheduledDoctors;
      }),
      labelOf: (d) => d.employee.fullnameWithMid,
      subtitleOf: (d) => d.rooms.join(', '),
      leadingOf: (d) => DoctorAvatar(path: d.employee.avatarImagePath),
      isSelected: (d) => d.employee.emp == selectedEmp,
      noneLabel: 'ไม่ระบุแพทย์',
      emptyText: 'ไม่มีแพทย์ออกตรวจวันนี้',
    );

    if (result != null) {
      _update((s) => s.selectDoctor(result.value?.employee));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<V> _memo<K, V>(
    Map<K, Future<V>> cache,
    K key,
    Future<V> Function() create,
  ) {
    final cached = cache[key];
    if (cached != null) return cached;

    final future = create();
    cache[key] = future;
    future.then(
      (_) {},
      onError: (_) {
        cache.remove(key);
      },
    );
    return future;
  }

  List<T> _unwrap<T>(ResponseModel<List<T>> response) {
    if (response.responseEnum != ResponseEnum.success) {
      throw Exception('load failed');
    }
    return response.data;
  }
}

String typeName(QueueConfigTypeModel type) =>
    type.nameTh.isNotEmpty ? type.nameTh : type.nameEn;

String stationName(QueueConfigModel station) =>
    station.description.isNotEmpty ? station.description : station.queueType;

class DoctorAvatar extends StatelessWidget {
  final String? path;
  final double size;

  const DoctorAvatar({super.key, required this.path, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Icon(
      Icons.person,
      size: size * 0.6,
      color: TvColors.of(context).mutedText,
    );

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: theme.colorScheme.outline,
        child: (path == null || path!.isEmpty)
            ? fallback
            : Image.network(
                BehConfig.pathImage(path!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
