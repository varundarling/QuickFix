import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String bookingId;
  final String customerId;
  final String providerId;
  final String serviceName;
  final double rating; // 1.0 to 5.0
  final String review;
  final String customerName;
  final DateTime createdAt;

  RatingModel({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.serviceName,
    required this.rating,
    required this.review,
    required this.customerName,
    required this.createdAt,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RatingModel(
      id: doc.id,
      bookingId: data['bookingId'] ?? '',
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      serviceName: data['serviceName'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      review: data['review'] ?? '',
      customerName: data['customerName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookingId': bookingId,
      'customerId': customerId,
      'providerId': providerId,
      'serviceName': serviceName,
      'rating': rating,
      'review': review,
      'customerName': customerName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
