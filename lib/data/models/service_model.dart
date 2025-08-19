import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final double basePrice;
  final String imageUrl;
  final List<String> subServices;
  final bool isActive;
  final String providerId;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final String mobileNumber;
  final String availability; // ✅ Add this field

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.basePrice,
    required this.imageUrl,
    required this.subServices,
    this.isActive = true,
    required this.providerId,
    required this.createdAt,
    this.metadata,
    this.mobileNumber = '',
    this.availability = 'available', // ✅ Add this with default value
  });

  factory ServiceModel.fromFireStore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    if (data == null) {
      throw Exception('Document data is null');
    }
    return ServiceModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      basePrice: (data['basePrice'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      subServices: List<String>.from(data['subServices'] ?? []),
      isActive: data['isActive'] ?? true,
      providerId: data['providerId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      metadata: data['metadata'],
      mobileNumber: data['mobileNumber'] ?? '',
      availability: data['availability'] ?? 'available', // ✅ Add this
    );
  }

  Map<String, dynamic> toFireStore() {
    return {
      "name": name,
      "description": description,
      'category': category,
      'basePrice': basePrice,
      'imageUrl': imageUrl,
      'subServices': subServices,
      'isActive': isActive,
      'providerId': providerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
      'mobileNumber': mobileNumber,
      'availability': availability, // ✅ Add this
    };
  }

  // ✅ Add helper methods
  bool get isAvailableForBooking => isActive && availability == 'available';
  bool get isBooked => availability == 'booked';
  bool get isInProgress => availability == 'active';
}
