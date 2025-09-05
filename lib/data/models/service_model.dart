import 'dart:math' as math;
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
  final String availability;
  final String? providerBusinessName;
  final String? providerName;
  final String? providerEmail;
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool isBooked;
  final String? bookedByUserId;
  final DateTime? bookedAt;
  final String? customerName;
  final String? customerPhone;

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
    this.availability = 'available',
    this.latitude,
    this.longitude,
    this.address,
    this.isBooked = false,
    this.bookedByUserId,
    this.bookedAt,
    this.customerName,
    this.customerPhone,
    this.providerBusinessName,
    this.providerName,
    this.providerEmail,
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
      createdAt: _parseDateTime(data['createdAt']),
      metadata: data['metadata'],
      mobileNumber: data['mobileNumber'] ?? '',
      availability: data['availability'] ?? 'available',
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      address: data['address'],
      // ✅ NEW: Booking field mappings
      isBooked: data['isBooked'] ?? false,
      bookedByUserId: data['bookedByUserId'],
      bookedAt: data['bookedAt'] != null
          ? _parseDateTime(data['bookedAt'])
          : null,
      customerName: data['customerName'],
      customerPhone: data['customerPhone'],
      providerBusinessName: data['providerBusinessName'],
      providerName: data['providerName'],
      providerEmail: data['providerEmail'],
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is Timestamp) {
      return value.toDate();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
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
      'availability': availability,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'isBooked': isBooked,
      'bookedByUserId': bookedByUserId,
      'bookedAt': bookedAt != null ? Timestamp.fromDate(bookedAt!) : null,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'providerBusinessName': providerBusinessName,
      'providerName': providerName,
      'providerEmail': providerEmail,
    };
  }

  // ✅ UPDATED: Enhanced booking status checks
  bool get isAvailableForBooking =>
      isActive && availability == 'available' && !isBooked;
  bool get isInProgress =>
      availability == 'active' || availability == 'in_progress';

  // ✅ NEW: Additional helper methods
  bool isBookedByUser(String userId) => isBooked && bookedByUserId == userId;

  String get bookingStatus {
    if (isBooked) return 'Booked';
    if (isInProgress) return 'In Progress';
    if (isAvailableForBooking) return 'Available';
    return 'Unavailable';
  }

  // ✅ NEW: CopyWith method for updating booking status
  ServiceModel copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    double? basePrice,
    String? imageUrl,
    List<String>? subServices,
    bool? isActive,
    String? providerId,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
    String? mobileNumber,
    String? availability,
    double? latitude,
    double? longitude,
    String? address,
    bool? isBooked,
    String? bookedByUserId,
    DateTime? bookedAt,
    String? customerName,
    String? customerPhone,
    String? providerBusinessName,
    String? providerName,
    String? providerEmail,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      basePrice: basePrice ?? this.basePrice,
      imageUrl: imageUrl ?? this.imageUrl,
      subServices: subServices ?? this.subServices,
      isActive: isActive ?? this.isActive,
      providerId: providerId ?? this.providerId,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      availability: availability ?? this.availability,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      isBooked: isBooked ?? this.isBooked,
      bookedByUserId: bookedByUserId ?? this.bookedByUserId,
      bookedAt: bookedAt ?? this.bookedAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      providerBusinessName: providerBusinessName ?? this.providerBusinessName,
      providerName: providerName ?? this.providerName,
      providerEmail: providerEmail ?? this.providerEmail,
    );
  }

  // Calculate distance from user location
  double? distanceFromUser(double? userLat, double? userLng) {
    if (latitude == null ||
        longitude == null ||
        userLat == null ||
        userLng == null) {
      return null;
    }

    // Haversine formula for distance calculation
    const double earthRadius = 6371; // Earth's radius in km
    final double dLat = _toRadians(latitude! - userLat);
    final double dLng = _toRadians(longitude! - userLng);
    final double a =
        (dLat / 2).sin() * (dLat / 2).sin() +
        userLat.cos() * latitude!.cos() * (dLng / 2).sin() * (dLng / 2).sin();
    final double c = 2 * a.sqrt().asin();
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (3.14159265359 / 180);
  }
}

extension on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double sqrt() => math.sqrt(this);
  double asin() => math.asin(this);
}
