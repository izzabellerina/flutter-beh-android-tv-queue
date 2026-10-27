import 'package:intl/intl.dart';

/// ต้องเรียก `initializeDateFormatting('th')` ใน main() ก่อนใช้
class FormatDate {
  /// HH:mm — e.g. 14:30
  static final timeHHmmFormat = DateFormat('HH:mm');

  static String time(DateTime date) => timeHHmmFormat.format(date);

  /// e.g. "วันจันทร์ที่ 26 ตุลาคม 2569" (พ.ศ.)
  static String thaiFullDate(DateTime date) {
    final weekday = DateFormat('EEEE', 'th').format(date);
    final thaiMonth = DateFormat('MMMM', 'th').format(date);
    final buddhistYear = date.year + 543;

    return '$weekdayที่ ${date.day} $thaiMonth $buddhistYear';
  }
}
