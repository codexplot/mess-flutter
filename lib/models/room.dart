class MonthlyBills {
  final double rent;
  final double food;
  final double electricity;
  final double water;

  MonthlyBills({
    required this.rent,
    required this.food,
    required this.electricity,
    required this.water,
  });

  factory MonthlyBills.fromJson(Map<String, dynamic> json) => MonthlyBills(
        rent: (json['rent'] ?? 0).toDouble(),
        food: (json['food'] ?? 0).toDouble(),
        electricity: (json['electricity'] ?? 0).toDouble(),
        water: (json['water'] ?? 0).toDouble(),
      );

  double get total => rent + food + electricity + water;
}

class RoomMember {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? address;

  RoomMember({required this.id, required this.name, required this.email, this.phone, this.address});

  factory RoomMember.fromJson(Map<String, dynamic> json) => RoomMember(
        id: json['_id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'],
        address: json['address'],
      );
}

class Room {
  final String id;
  final String name;
  final String roomCode;
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final List<RoomMember> members;
  final List<String> paidMembers;
  final List<String> foodOptOut;
  final MonthlyBills monthlyBills;
  final String billingMonth;

  Room({
    required this.id,
    required this.name,
    required this.roomCode,
    required this.ownerId,
    this.ownerName = '',
    this.ownerEmail = '',
    required this.members,
    required this.paidMembers,
    required this.foodOptOut,
    required this.monthlyBills,
    required this.billingMonth,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    String ownerId = owner is Map ? (owner['_id'] ?? '') : (owner ?? '');
    String ownerName = owner is Map ? (owner['name'] ?? '') : '';
    String ownerEmail = owner is Map ? (owner['email'] ?? '') : '';

    List<RoomMember> members = [];
    if (json['members'] is List) {
      for (var m in json['members']) {
        if (m is Map<String, dynamic>) {
          members.add(RoomMember.fromJson(m));
        } else if (m is Map) {
          members.add(RoomMember.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }

    List<String> paidMembers = [];
    if (json['paidMembers'] is List) {
      for (var p in json['paidMembers']) {
        paidMembers.add(p is Map ? p['_id'] : p.toString());
      }
    }

    List<String> foodOptOut = [];
    if (json['foodOptOut'] is List) {
      for (var f in json['foodOptOut']) {
        foodOptOut.add(f is Map ? f['_id'] : f.toString());
      }
    }

    return Room(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      roomCode: json['roomCode'] ?? '',
      ownerId: ownerId,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      members: members,
      paidMembers: paidMembers,
      foodOptOut: foodOptOut,
      monthlyBills: json['monthlyBills'] != null
          ? MonthlyBills.fromJson(json['monthlyBills'])
          : MonthlyBills(rent: 0, food: 0, electricity: 0, water: 0),
      billingMonth: json['billingMonth'] ?? '',
    );
  }
}
