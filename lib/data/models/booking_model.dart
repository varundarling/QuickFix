import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  confirmed,
  paymentPending,
  completed,
  paid,
  cancelled,
  refunded, inProgress,
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
  final DateTime? paymentInitiatedAt;
  final DateTime? paymentVerifiedAt;
  final bool isPaymentVerified;
  final String? paymentVerificationId;
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
  final String? providerName;
  final String? providerPhone;
  final String? providerEmail;
  final DateTime? paymentDate;
  final DateTime? selectedDate;
  DateTime? acceptedAt;
  final String? customerAddressFromProfile;

  BookingModel({
    this.paymentDate,
    this.paymentInitiatedAt,
    this.paymentVerifiedAt,
    this.isPaymentVerified = false,
    this.paymentVerificationId,
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
    this.providerName,
    this.providerPhone,
    this.providerEmail,
    this.selectedDate,
    this.acceptedAt,
    this.customerAddressFromProfile,
  });

  factory BookingModel.fromFireStore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      serviceId: data['serviceId'] ?? '',
      serviceName: data['serviceName'] ?? '',
      scheduledDateTime: _parseDateTime(data['scheduledDateTime']),
      description: data['description'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: bookingStatusFromString(data['status']) ?? BookingStatus.pending,
      customerAddress: data['customerAddress'] ?? '',
      customerLatitude: (data['customerLatitude'] ?? 0.0).toDouble(),
      customerLongitude: (data['customerLongitude'] ?? 0.0).toDouble(),
      createdAt: _parseDateTime(data['createdAt']),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      paymentId: data['paymentId'],
      cancellationReason: data['cancellationReason'],
      metadata: data['metaData'],
      customerName: data['customerName']?.toString(),
      customerEmail: data['customerEmail']?.toString(),
      customerPhone: data['customerPhone']?.toString(),
      selectedDate: data['selectedDate'] != null
          ? (data['selectedDate'] as Timestamp).toDate()
          : null,
      acceptedAt: data['acceptedAt'] != null
          ? (data['acceptedAt'] as Timestamp).toDate()
          : null,
      customerAddressFromProfile: data['customerAddressFromProfile']
          ?.toString(),
      providerName: data['providerName']?.toString(),
      providerPhone: data['providerPhone']?.toString(),
      providerEmail: data['providerEmail']?.toString(),
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
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'selectedDate': selectedDate != null
          ? Timestamp.fromDate(selectedDate!)
          : null,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'customerAddressFromProfile': customerAddressFromProfile,
      'providerName': providerName,
      'providerPhone': providerPhone,
      'providerEmail': providerEmail,
    };
  }

  String get statusDisplay {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed'; // ✅ This is now "Active" for both customer and provider
      // ✅ REMOVED: inProgress case
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

extension BookingStatusExtension on BookingStatus {
  String get statusDisplay {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed - Payment Required';
      case BookingStatus.paymentPending:
        return 'Payment Verification Pending';
      case BookingStatus.paid:
        return 'Paid';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.refunded:
        return 'Refunded';
    }
  }
}

extension BookingModelCopyWith on BookingModel {
  BookingModel copyWith({
    DateTime? paymentInitiatedAt,
    DateTime? paymentVerifiedAt,
    bool? isPaymentVerified,
    String? paymentVerificationId,
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
    String? providerName,
    String? providerPhone,
    String? providerEmail,
    DateTime? paymentDate,
    DateTime? selectedDate,
    DateTime? acceptedAt,
    String? customerAddressFromProfile,
  }) {
    return BookingModel(
      paymentInitiatedAt: paymentInitiatedAt ?? this.paymentInitiatedAt,
      paymentVerifiedAt: paymentVerifiedAt ?? this.paymentVerifiedAt,
      isPaymentVerified: isPaymentVerified ?? this.isPaymentVerified,
      paymentVerificationId:
          paymentVerificationId ?? this.paymentVerificationId,
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
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      providerName: providerName ?? this.providerName,
      providerPhone: providerPhone ?? this.providerPhone,
      providerEmail: providerEmail ?? this.providerEmail,
      paymentDate: paymentDate ?? this.paymentDate,
      selectedDate: selectedDate ?? this.selectedDate,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      customerAddressFromProfile:
          customerAddressFromProfile ?? this.customerAddressFromProfile,
    );
  }
}
