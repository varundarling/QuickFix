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
  final Map<String, bool> availability; //day -> available
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;
  final double? hourlyRate;
  final List<String> portfolioImages;

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
  });

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
      longitude: (data['longtude'] ?? 0.0).toDouble(),
      address: data['address'] ?? '',
      availability: Map<String, bool>.from(data['availability'] ?? {}),
      isVerified: data['isVerified'] ?? false,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      hourlyRate: data['hourlyRate']?.toDouble(),
      portfolioImages: List<String>.from(data['protfolioImages'] ?? []),
    );
  }

  Map<String,dynamic> toFireStore(){
    return{
      'userId':userId,
      'businessName' : businessName,
      'description' : description,
      'servies' : services,
      'rating' : raitng,
      'totalReviews' : totalReviews,
      'certifications' : certifications,
      'latitude' : latitude,
      'longitude' : longitude,
      'address' : address,
      'availability' : availability,
      'isVerified' : isVerified,
      'isActive' : isActive,
      'createdAt' : Timestamp.fromDate(createdAt),
      'hourlyRate' : hourlyRate,
      'protfolioImages' : portfolioImages,
    };
  }
}
