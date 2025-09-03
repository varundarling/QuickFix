import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum BookingStatus {
  pending,
  confirmed,
  paymentPending,
  completed,
  inProgress,
  paid,
  cancelled,
  refunded,
}

BookingStatus? bookingStatusFromString(String value) {
  try {
    final cleanValue = value.toLowerCase().trim();
    debugPrint('🔍 [STATUS PARSING] Input: "$value" → Clean: "$cleanValue"');

    // ✅ CRITICAL: Handle all possible status values
    switch (cleanValue) {
      case 'pending':
        return BookingStatus.pending;
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'inprogress':
      case 'in_progress':
      case 'in-progress':
        debugPrint('✅ [STATUS PARSING] Matched inProgress');
        return BookingStatus.inProgress;
      case 'completed':
        return BookingStatus.completed;
      case 'paid':
        return BookingStatus.paid;
      case 'cancelled':
      case 'canceled':
        return BookingStatus.cancelled;
      case 'refunded':
        return BookingStatus.refunded;
      case 'paymentpending':
      case 'payment_pending':
      case 'payment-pending':
        return BookingStatus.paymentPending;
      default:
        debugPrint(
          '❌ [STATUS PARSING] Unknown status: "$cleanValue" - defaulting to pending',
        );
        return BookingStatus.pending;
    }
  } catch (e) {
    debugPrint('❌ [STATUS PARSING] Error parsing "$value": $e');
    return BookingStatus.pending;
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
  final String? customerAddress;
  final double? customerLatitude;
  final double? customerLongitude;
  final DateTime createdAt;
  final DateTime? bookedDate;
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
  final bool otpVerified;
  final DateTime? otpVerifiedAt;
  final DateTime? serviceStartedAt;
  final bool paymentConfirmed;
  final String? paymentMethod;
  final DateTime? paymentConfirmedAt;
  final bool? realTimePayment;

  final DateTime? workStartTime;
  final DateTime? workEndTime;
  final double workProgress; // 0.0 to 1.0
  final bool isWorkInProgress;

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
    this.customerAddress,
    this.customerLatitude,
    this.customerLongitude,
    this.bookedDate,
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
    this.paymentConfirmed = false,
    this.paymentMethod,
    this.paymentConfirmedAt,
    this.realTimePayment,
    this.otpVerified = false,
    this.otpVerifiedAt,
    this.serviceStartedAt,
    this.workStartTime,
    this.workEndTime,
    this.workProgress = 0.0,
    this.isWorkInProgress = false,
  });

  factory BookingModel.fromFireStore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final statusString = data['status']?.toString() ?? 'pending';
    final parsedStatus = bookingStatusFromString(statusString);
    return BookingModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      providerId: data['providerId'] ?? '',
      serviceId: data['serviceId'] ?? '',
      serviceName: data['serviceName'] ?? '',
      scheduledDateTime: _parseDateTime(data['scheduledDateTime']),
      description: data['description'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: parsedStatus ?? BookingStatus.pending,
      customerAddress: data['customerAddress']?.toString(),
      customerLatitude: (data['customerLatitude'] as num?)?.toDouble(),
      customerLongitude: (data['customerLongitude'] as num?)?.toDouble(),
      bookedDate: (data['bookedDate'] as Timestamp?)?.toDate(),
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

      // ✅ NEW: Real-time payment fields from Firestore
      paymentConfirmed: data['paymentConfirmed'] ?? false,
      paymentMethod: data['paymentMethod']?.toString(),
      paymentConfirmedAt: data['paymentConfirmedAt'] != null
          ? (data['paymentConfirmedAt'] as Timestamp).toDate()
          : null,
      realTimePayment: data['realTimePayment'],
      otpVerified: data['otpVerified'] ?? false,
      otpVerifiedAt: data['otpVerifiedAt'] != null
          ? (data['otpVerifiedAt'] as Timestamp).toDate()
          : null,
      serviceStartedAt: data['serviceStartedAt'] != null
          ? (data['serviceStartedAt'] as Timestamp).toDate()
          : null,
      workStartTime: data['workStartTime'] != null
          ? (data['workStartTime'] as Timestamp).toDate()
          : null,
      workEndTime: data['workEndTime'] != null
          ? (data['workEndTime'] as Timestamp).toDate()
          : null,
      workProgress: (data['workProgress'] ?? 0.0).toDouble(),
      isWorkInProgress: data['isWorkInProgress'] ?? false,
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
      'bookedDate': bookedDate != null ? Timestamp.fromDate(bookedDate!) : null,
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

      // ✅ NEW: Real-time payment fields to Firestore
      'paymentConfirmed': paymentConfirmed,
      'paymentMethod': paymentMethod,
      'paymentConfirmedAt': paymentConfirmedAt != null
          ? Timestamp.fromDate(paymentConfirmedAt!)
          : null,
      'realTimePayment': realTimePayment,
      'otpVerified': otpVerified,
      'otpVerifiedAt': otpVerifiedAt != null
          ? Timestamp.fromDate(otpVerifiedAt!)
          : null,
      'serviceStartedAt': serviceStartedAt != null
          ? Timestamp.fromDate(serviceStartedAt!)
          : null,
      'workStartTime': workStartTime != null
          ? Timestamp.fromDate(workStartTime!)
          : null,
      'workEndTime': workEndTime != null
          ? Timestamp.fromDate(workEndTime!)
          : null,
      'workProgress': workProgress,
      'isWorkInProgress': isWorkInProgress,
    };
  }

  String get statusDisplay {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed'; // ✅ This is now "Active" for both customer and provider
      case BookingStatus.inProgress:
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
    DateTime? bookedDate,
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
    bool? paymentConfirmed,
    String? paymentMethod,
    DateTime? paymentConfirmedAt,
    bool? realTimePayment,
    bool? otpVerified,
    DateTime? otpVerifiedAt,
    DateTime? serviceStartedAt,
    DateTime? workStartTime,
    DateTime? workEndTime,
    double? workProgress,
    bool? isWorkInProgress,
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
      bookedDate: bookedDate ?? this.bookedDate,
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
      // ✅ NEW: Real-time payment copyWith assignments
      paymentConfirmed: paymentConfirmed ?? this.paymentConfirmed,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentConfirmedAt: paymentConfirmedAt ?? this.paymentConfirmedAt,
      realTimePayment: realTimePayment ?? this.realTimePayment,
      otpVerified: otpVerified ?? this.otpVerified,
      otpVerifiedAt: otpVerifiedAt ?? this.otpVerifiedAt,
      serviceStartedAt: serviceStartedAt ?? this.serviceStartedAt,
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      workProgress: workProgress ?? this.workProgress,
      isWorkInProgress: isWorkInProgress ?? this.isWorkInProgress,
    );
  }
}

// ✅ OPTIONAL: Add helpful getters for payment logic
extension BookingModelPaymentExtension on BookingModel {
  /// Returns true if payment has been confirmed through real-time payment or status is paid
  bool get isPaymentCompleted {
    return paymentConfirmed || status == BookingStatus.paid;
  }

  /// Returns true if booking is completed but payment is still pending
  bool get isPaymentPending {
    return status == BookingStatus.completed && !isPaymentCompleted;
  }

  /// Returns true if real-time payment can be made
  bool get canMakeRealTimePayment {
    return status == BookingStatus.completed && !isPaymentCompleted;
  }

  /// Returns the appropriate payment status message
  String get paymentStatusMessage {
    if (isPaymentCompleted) {
      return 'Payment Completed';
    } else if (isPaymentPending) {
      return 'Payment Required';
    } else {
      return 'Payment Not Required Yet';
    }
  }
}
