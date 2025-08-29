import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderModel {
  final String id;
  final String userId;
  final String businessName;
  final String description;
  final List<String> services;
  final double raitng;
  final int totalReviews;
  final List<String> certifications;
  final double latitude;
  final double longitude;
  final String address;
  final Map<String, bool> availability; // day -> available
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;
  final double? hourlyRate;
  final List<String> portfolioImages;
  final String mobileNumber;
  final String? experience;

  ProviderModel({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.description,
    required this.services,
    this.raitng = 0.0,
    this.totalReviews = 0,
    required this.certifications,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.availability,
    this.isVerified = false,
    this.isActive = true,
    required this.createdAt,
    this.hourlyRate,
    required this.portfolioImages,
    this.mobileNumber = '',
    this.experience,
  });

  // ✅ FIXED: Corrected all typos and improved null handling
  factory ProviderModel.fromFireStore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProviderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      businessName: data['businessName'] ?? '',
      description: data['description'] ?? '',
      services: List<String>.from(data['services'] ?? []),
      raitng: (data['rating'] ?? 0.0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      certifications: List<String>.from(data['certifications'] ?? []),
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0)
          .toDouble(), // ✅ FIXED: was 'longtude'
      address: data['address'] ?? '',
      availability: Map<String, bool>.from(data['availability'] ?? {}),
      isVerified: data['isVerified'] ?? false,
      isActive: data['isActive'] ?? true,
      createdAt: _parseDateTime(data['createdAt']),
      hourlyRate: data['hourlyRate'] != null
          ? (data['hourlyRate'] as num).toDouble()
          : null, // ✅ IMPROVED: safe casting
      portfolioImages: List<String>.from(
        data['portfolioImages'] ?? [],
      ), // ✅ FIXED: was 'protfolioImages'
      mobileNumber: data['mobileNumber'] ?? '', // ✅ ADDED: was missing
      experience: data['experience']?.toString(),
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

  // ✅ FIXED: Corrected all typos and added missing field
  Map<String, dynamic> toFireStore() {
    return {
      'userId': userId,
      'businessName': businessName,
      'description': description,
      'services': services, // ✅ FIXED: was 'servies'
      'rating': raitng,
      'totalReviews': totalReviews,
      'certifications': certifications,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'availability': availability,
      'isVerified': isVerified,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'hourlyRate': hourlyRate,
      'portfolioImages': portfolioImages, // ✅ FIXED: was 'protfolioImages'
      'mobileNumber': mobileNumber, // ✅ ADDED: was missing
      'experience': experience,
    };
  }

  // ✅ ADDED: Useful copyWith method for updates
  ProviderModel copyWith({
    String? id,
    String? userId,
    String? businessName,
    String? description,
    List<String>? services,
    double? raitng,
    int? totalReviews,
    List<String>? certifications,
    double? latitude,
    double? longitude,
    String? address,
    Map<String, bool>? availability,
    bool? isVerified,
    bool? isActive,
    DateTime? createdAt,
    double? hourlyRate,
    List<String>? portfolioImages,
    String? mobileNumber,
    String? experience,
  }) {
    return ProviderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      businessName: businessName ?? this.businessName,
      description: description ?? this.description,
      services: services ?? this.services,
      raitng: raitng ?? this.raitng,
      totalReviews: totalReviews ?? this.totalReviews,
      certifications: certifications ?? this.certifications,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      availability: availability ?? this.availability,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      portfolioImages: portfolioImages ?? this.portfolioImages,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      experience: experience ?? this.experience,
    );
  }

  // ✅ ADDED: toString method for debugging
  @override
  String toString() {
    return 'ProviderModel(id: $id, businessName: $businessName, address: $address, experience: $experience)';
  }
}
