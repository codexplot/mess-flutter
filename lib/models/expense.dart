class BillImage {
  final String url;
  final String publicId;

  BillImage({required this.url, required this.publicId});

  factory BillImage.fromJson(Map<String, dynamic> json) =>
      BillImage(url: json['url'] ?? '', publicId: json['publicId'] ?? '');
}

class Expense {
  final String id;
  final String memberId;
  final String memberName;
  final String roomId;
  final double amount;
  final String shopName;
  final DateTime date;
  final BillImage? billImage;
  final String? comments;
  final String status;
  final String? rejectionNote;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.roomId,
    required this.amount,
    required this.shopName,
    required this.date,
    this.billImage,
    this.comments,
    required this.status,
    this.rejectionNote,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final member = json['member'];
    String memberId = '', memberName = '';
    if (member is Map) {
      memberId = member['_id'] ?? '';
      memberName = member['name'] ?? '';
    } else if (member is String) {
      memberId = member;
    }

    final room = json['room'];
    String roomId = room is Map ? (room['_id'] ?? '') : (room ?? '');

    return Expense(
      id: json['_id'] ?? '',
      memberId: memberId,
      memberName: memberName,
      roomId: roomId,
      amount: (json['amount'] ?? 0).toDouble(),
      shopName: json['shopName'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      billImage: json['billImage'] != null && json['billImage']['url'] != null
          ? BillImage.fromJson(json['billImage'])
          : null,
      comments: json['comments'],
      status: json['status'] ?? 'pending',
      rejectionNote: json['rejectionNote'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
