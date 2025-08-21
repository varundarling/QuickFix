import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  confirmed,
  inProgress,
  completed,
  cancelled,
  refunded,
}

BookingStatus? bookingStatusFromString(String value) {
  try {
    return BookingStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
    );
  } catch (e) {
    return null; // Return null if no match found
  }
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
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;

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
    this.customerName,
    this.customerPhone,
    this.customerEmail,
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
      status: bookingStatusFromString(data['status']) ?? BookingStatus.pending,
      customerAddress: data['customerAddress'] ?? '',
      customerLatitude: (data['customerLatitude'] ?? 0.0).toDouble(),
      customerLongitude: (data['customerLongitude'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      paymentId: data['paymentId'],
      cancellationReason: data['cancellationReason'],
      metadata: data['metaData'],
      customerName: data['customerName'],
      customerEmail: data['customerEmail'],
      customerPhone: data['customerPhone'],
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
      'status': status.name,
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
      'customerName': customerName ?? customerName,
      'customerPhone': customerPhone ?? customerPhone,
      'customerEmail': customerEmail ?? customerEmail,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'providerId': providerId,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'description': description,
      'scheduledDateTime': scheduledDateTime.millisecondsSinceEpoch,
      'customerAddress': customerAddress,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
      'totalAmount': totalAmount,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  String get statusDisplay {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.inProgress:
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

extension BookingStatusExtension on BookingStatus {
  String get statusDisplay {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.inProgress: // ✅ Fixed: was "inProgresss"
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.refunded:
        return 'Refunded';
      default:
        return 'Unknown';
    }
  }
}

extension BookingModelCopyWith on BookingModel {
  BookingModel copyWith({
    String? id,
    String? customerId,
    String? providerId,
    String? serviceId,
    String? serviceName,
    DateTime? scheduledDateTime,
    String? description,
    double? totalAmount,
    BookingStatus? status,
    String? customerAddress,
    double? customerLatitude,
    double? customerLongitude,
    DateTime? createdAt,
    DateTime? completedAt,
    String? paymentId,
    String? cancellationReason,
    Map<String, dynamic>? metadata,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
  }) {
    return BookingModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      providerId: providerId ?? this.providerId,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      customerAddress: customerAddress ?? this.customerAddress,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      paymentId: paymentId ?? this.paymentId,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      metadata: metadata ?? this.metadata,
    );
  }
}
