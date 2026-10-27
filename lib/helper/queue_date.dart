import 'package:intl/intl.dart';

class QueueDate {
  static const bangkokOffset = Duration(hours: 7);

  static final _apiDateFormat = DateFormat('yyyy-MM-dd');

  /// วันที่ตามเวลาไทย (UTC+7) สำหรับ API — e.g. "2026-10-27"
  ///
  /// คำนวณจากเวลาปัจจุบันทุกครั้งที่เรียก → พอเลยเที่ยงคืนเวลาไทยจะได้วันใหม่ทันที
  /// ไม่ขึ้นกับ timezone ที่ตั้งไว้ในทีวี
  static String today({DateTime? now}) {
    final bangkok = (now ?? DateTime.now()).toUtc().add(bangkokOffset);
    return _apiDateFormat.format(bangkok);
  }

  /// เวลาที่เหลือถึงเที่ยงคืนเวลาไทยครั้งถัดไป (+ เผื่อ [margin] ให้ server เปลี่ยนวันแน่ ๆ)
  static Duration untilNextDay({
    DateTime? now,
    Duration margin = const Duration(seconds: 5),
  }) {
    final bangkok = (now ?? DateTime.now()).toUtc().add(bangkokOffset);
    final nextMidnight = DateTime.utc(
      bangkok.year,
      bangkok.month,
      bangkok.day + 1,
    );
    return nextMidnight.difference(bangkok) + margin;
  }
}
