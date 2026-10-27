/// การวางจอของหน้าจอคิว — กล่อง Android TV ส่งภาพแนวนอนเสมอ
/// ทีวีที่ติดตั้งแนวตั้งต้องหมุนภาพในแอป (เฉพาะหน้าจอคิว)
enum DisplayRotation {
  landscape(quarterTurns: 0, label: 'แนวนอน'),
  portraitRight(quarterTurns: 1, label: 'แนวตั้ง · หมุนภาพขวา'),
  portraitLeft(quarterTurns: 3, label: 'แนวตั้ง · หมุนภาพซ้าย');

  final int quarterTurns;
  final String label;

  const DisplayRotation({required this.quarterTurns, required this.label});

  bool get isPortrait => quarterTurns.isOdd;
}
