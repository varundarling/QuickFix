import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  confirmed,
  inProgresss,
  completed,
  cancelled,
  refunded,
}

class BookingModel {
  final String id;
  final String customerId;
  final String providerId;
  final String serviceId;
  final String serviceName;
  final DateTime scheduledDateTime;
  final String description;
  final double totalAmount;
  final BookingStatus status;
  final String customerAddress;
  final double customerLatitude;
  final double customerLongitude;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? paymentId;
  final String? cancellationReason;
  final Map<String, dynamic>? metadata;

  BookingModel({
    required this.id,
    required this.customerId,
    required this.providerId,
    required this.serviceId,
    required this.serviceName,
    required this.scheduledDateTime,
    required this.description,
    required this.totalAmount,
    required this.status,
    required this.customerAddress,
    required this.customerLatitude,
    required this.customerLongitude,
    required this.createdAt,
    this.completedAt,
    this.paymentId,
    this.cancellationReason,
    this.metadata,
  });

  factory BookingModel.fromFireStore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      serviceId: data['serviceId'] ?? '',
      serviceName: data['serviceName'] ?? '',
      scheduledDateTime: (data['scheduledDateTime'] as Timestamp).toDate(),
      description: data['description'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: BookingStatus.values.firstWhere(
        (e) => e.toString() == 'Booking Status.${data['status']}',
        orElse: () => BookingStatus.pending,
      ),
      customerAddress: data['customerAddress'] ?? '',
      customerLatitude: (data['customerLatitude'] ?? 0.0).toDouble(),
      customerLongitude: (data['customerLongitude'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['compeletedAt'] as Timestamp).toDate()
          : null,
      paymentId: data['paymentId'],
      cancellationReason: data['cancellationReason'],
      metadata: data['metaData'],
    );
  }

  Map<String, dynamic> toFireStore() {
    return {
      'customerId': customerId,
      'providerId': providerId,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'scheduledDateTime': Timestamp.fromDate(scheduledDateTime),
      "description": description,
      'totalAmount': totalAmount,
      'status': status.toString().split('.').last,
      'customerAddress': customerAddress,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'paymentId': paymentId,
      'cancellationReason': cancellationReason,
      'metadata': metadata,
    };
  }

  String get statusDisplay {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.inProgresss:
        return 'inProgress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.refunded:
        return 'Refunded';
    }
  }
}
