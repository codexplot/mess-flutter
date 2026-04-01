class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? roomId;
  final String? roomName;
  final String? roomCode;
  final String? phone;
  final String? address;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.roomId,
    this.roomName,
    this.roomCode,
    this.phone,
    this.address,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final room = json['room'];
    String? roomId, roomName, roomCode;
    if (room is Map) {
      roomId = room['_id'];
      roomName = room['name'];
      roomCode = room['roomCode'];
    } else if (room is String) {
      roomId = room;
    }
    return User(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'member',
      roomId: roomId,
      roomName: roomName,
      roomCode: roomCode,
      phone: json['phone'],
      address: json['address'],
    );
  }

  bool get isOwner => role == 'owner';
  bool get isMember => role == 'member';
  bool get isAdmin => role == 'admin';
}
