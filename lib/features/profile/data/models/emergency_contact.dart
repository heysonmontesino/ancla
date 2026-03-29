import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final DateTime createdAt;

  factory EmergencyContact.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final timestamp = data['created_at'] as Timestamp?;
    return EmergencyContact(
      id: doc.id,
      name: data['name'] as String,
      phone: data['phone'] as String,
      createdAt: (timestamp ?? Timestamp.now()).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
