import 'package:flutter/widgets.dart';

/// การเลื่อน focus ด้วยลูกศรรีโมท ตามตำแหน่งบนจออย่างเดียว
///
/// policy ปกติของ Flutter "จำทางเดิม" — ลงจาก A ไป B แล้วกดขึ้นจะกระโดดกลับ A
/// แม้ระหว่างนั้น focus ถูกย้ายด้วยโค้ด (เช่น กดถัดไปบนคีย์บอร์ด) ทำให้รีโมทไปผิดช่อง
class TvTraversalPolicy extends ReadingOrderTraversalPolicy {
  TvTraversalPolicy({super.requestFocusCallback});

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final scope = currentNode.nearestScope;
    if (scope != null) invalidateScopeData(scope);
    return super.inDirection(currentNode, direction);
  }

  /// ใช้กับ `MaterialApp.builder` — ครอบทั้งแอป
  static Widget builder(BuildContext context, Widget? child) {
    return FocusTraversalGroup(
      policy: TvTraversalPolicy(),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
