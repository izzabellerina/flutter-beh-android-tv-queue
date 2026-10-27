import 'package:flutter_android_tv_queue/controller/queue_voice_announcer.dart';
import 'package:flutter_android_tv_queue/models/response_model.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/service/general_service.dart';
import 'package:flutter_android_tv_queue/service/voice_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// สร้างตัวประกาศเสียงที่เรียก API ด้วย context/token ของหน้านั้น
/// ใช้ทั้งหน้าจอคิว และปุ่ม "ทดสอบเสียง" ในหน้าตั้งค่า
mixin QueueVoiceMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  QueueVoiceAnnouncer createVoiceAnnouncer({
    required Set<String> Function() prefixes,
  }) {
    final client = ref.read(httpClientProvider);
    final playerFactory =
        ref.read(voicePlayerFactoryProvider) ?? AudioplayersVoicePlayer.new;

    return QueueVoiceAnnouncer(
      prefixes: prefixes,
      player: playerFactory(),
      fetchTemplate: () async {
        if (!mounted) throw StateError('page disposed');
        final response = await GeneralService.getLastOneQueueCallingVoiceText(
          context,
          client: client,
        );
        if (response.responseEnum != ResponseEnum.success) {
          throw Exception('getLastOneQueueCallingVoiceText failed');
        }
        return response.data;
      },
      fetchVoice: ({required textTh, required textEn}) async {
        if (!mounted) throw StateError('page disposed');
        final response = await GeneralService.getVoice(
          context,
          textTh: textTh,
          textEn: textEn,
          speakingRate: QueueVoiceAnnouncer.speakingRate,
          client: client,
        );
        if (response.responseEnum != ResponseEnum.success) {
          throw Exception('getVoice failed');
        }
        return response.data;
      },
    );
  }
}
