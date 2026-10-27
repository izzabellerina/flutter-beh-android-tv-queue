enum QueueMode {
  single(slotCount: 1, label: 'คิวเดี่ยว', description: 'แสดง 1 คิว เต็มจอ'),
  dual(
    slotCount: 2,
    label: 'คิวคู่',
    description: 'แสดง 2 คิว คู่กันบนจอเดียว',
  );

  final int slotCount;
  final String label;
  final String description;

  const QueueMode({
    required this.slotCount,
    required this.label,
    required this.description,
  });
}
