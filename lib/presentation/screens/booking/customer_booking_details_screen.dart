// ignore_for_file: prefer_conditional_assignment, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/data/models/rating_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/presentation/providers/rating_providers.dart';
import 'package:quickfix/presentation/screens/booking/customer_otp_screen.dart';
import 'package:quickfix/presentation/screens/home/customer_rating_screen.dart';
import 'package:quickfix/presentation/screens/payment/real_time_payment_screen.dart';
import 'package:quickfix/presentation/widgets/rating/rating_display_widget.dart';

class CustomerBookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const CustomerBookingDetailScreen({super.key, required this.bookingId});

  @override
  State<CustomerBookingDetailScreen> createState() =>
      _CustomerBookingDetailScreenState();
}

class _CustomerBookingDetailScreenState
    extends State<CustomerBookingDetailScreen> {
  BookingModel? booking;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  // Enhanced _loadBooking method with proper provider data handling
  Future<void> _loadBooking() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final bookingProvider = context.read<BookingProvider>();

      // First try to find booking in existing list
      final existingBooking =
          bookingProvider.userBookings
              .where((b) => b.id == widget.bookingId)
              .isNotEmpty
          ? bookingProvider.userBookings.firstWhere(
              (b) => b.id == widget.bookingId,
            )
          : null;

      BookingModel? bookingToProcess = existingBooking;

      // If not found, fetch from database
      bookingToProcess ??= await bookingProvider.getBookingById(
        widget.bookingId,
      );

      if (bookingToProcess == null) {
        setState(() {
          errorMessage = 'Booking not found';
          isLoading = false;
        });
        return;
      }

      // debugPrint(
      //   '🔍 [CUSTOMER DETAIL] Processing booking: ${bookingToProcess.serviceName}',
      // );
      // debugPrint(
      //   '🔍 [CUSTOMER DETAIL] Provider ID: ${bookingToProcess.providerId}',
      // );
      // debugPrint(
      //   '🔍 [CUSTOMER DETAIL] Existing provider phone: ${bookingToProcess.providerPhone}',
      // );

      // ✅ CRITICAL: Try multiple methods to get provider details
      Map<String, dynamic>? providerDetails;

      // Method 1: Use existing booking provider data if available
      if (bookingToProcess.providerPhone?.isNotEmpty == true) {
        // debugPrint('✅ [CUSTOMER DETAIL] Using existing booking provider data');
        providerDetails = {
          'name': bookingToProcess.providerName ?? 'Service Provider',
          'businessName': bookingToProcess.providerName ?? 'Service Provider',
          'phone': bookingToProcess.providerPhone!,
          'mobileNumber': bookingToProcess.providerPhone!,
          'email': bookingToProcess.providerEmail ?? '',
        };
      } else {
        // Method 2: Fetch from service data
        // debugPrint(
        //   '🔄 [CUSTOMER DETAIL] Fetching provider data from service...',
        // );
        try {
          final serviceDoc = await FirebaseFirestore.instance
              .collection('services')
              .doc(bookingToProcess.serviceId)
              .get();

          if (serviceDoc.exists && serviceDoc.data() != null) {
            final serviceData = serviceDoc.data()!;
            final serviceMobile = serviceData['mobileNumber'] as String?;
            final serviceProviderName =
                serviceData['providerBusinessName'] as String? ??
                serviceData['providerName'] as String?;

            if (serviceMobile?.isNotEmpty == true) {
              // debugPrint(
              //   '✅ [CUSTOMER DETAIL] Provider data from service: $serviceMobile',
              // );
              providerDetails = {
                'name': serviceProviderName ?? 'Service Provider',
                'businessName': serviceProviderName ?? 'Service Provider',
                'phone': serviceMobile!,
                'mobileNumber': serviceMobile,
                'email': serviceData['providerEmail'] ?? '',
              };
            }
          }
        } catch (e) {
          //debugPrint('⚠️ [CUSTOMER DETAIL] Service data fetch error: $e');
        }

        // Method 3: Fallback to provider profile data
        if (providerDetails == null) {
          // debugPrint('🔄 [CUSTOMER DETAIL] Fetching from provider profile...');
          providerDetails = await _fetchProviderDetails(
            bookingToProcess.providerId,
          );
        }
      }

      // debugPrint(
      //   '🔍 [CUSTOMER DETAIL] Final provider details: $providerDetails',
      // );

      BookingModel updatedBooking;

      if (providerDetails != null) {
        final providerName =
            providerDetails['businessName']?.toString() ??
            providerDetails['name']?.toString() ??
            'Unknown Provider';

        final providerPhone =
            providerDetails['phone']?.toString() ??
            providerDetails['mobileNumber']?.toString() ??
            '';

        final providerEmail = providerDetails['email']?.toString() ?? '';

        // debugPrint('✅ [CUSTOMER DETAIL] Final mapped provider data:');
        // debugPrint('   - Name: $providerName');
        // debugPrint('   - Phone: $providerPhone');
        // debugPrint('   - Email: $providerEmail');

        updatedBooking = bookingToProcess.copyWith(
          providerName: providerName,
          providerPhone: providerPhone,
          providerEmail: providerEmail,
        );
      } else {
        // debugPrint(
        //   '⚠️ [CUSTOMER DETAIL] No provider details found, using fallback',
        // );
        updatedBooking = bookingToProcess.copyWith(
          providerName: 'Provider information unavailable',
          providerPhone: '',
          providerEmail: '',
        );
      }

      setState(() {
        booking = updatedBooking;
        isLoading = false;
      });

      // debugPrint(
      //   '✅ [CUSTOMER DETAIL] Booking loaded with provider phone: ${updatedBooking.providerPhone}',
      // );
    } catch (e) {
      // debugPrint('❌ [CUSTOMER DETAIL] Error loading booking: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load booking: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading booking details...'),
          ],
        ),
      );
    }

    if (errorMessage != null || booking == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'Booking not found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBooking,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return _buildBookingDetails(booking!);
  }

  Future<BookingModel> getBookingWithProfileAddress(String bookingId) async {
    var bookingDoc = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .get();
    var booking = BookingModel.fromFireStore(
      bookingDoc.data()! as DocumentSnapshot<Object?>,
    );

    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(booking.customerId)
        .get();
    var customerProfileAddress = userDoc.data()?['address'] ?? '';

    return booking.copyWith(customerAddressFromProfile: customerProfileAddress);
  }

  Widget _buildBookingDetails(BookingModel booking) {
    Helpers.getStatusColor(booking.status.toString());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Details
          _buildDetailCard(
            title: 'Service Details',
            icon: Icons.build_circle,
            children: [
              _buildDetailRow('Service', booking.serviceName),
              _buildDetailRow(
                'Description',
                booking.description.isNotEmpty
                    ? booking.description
                    : 'No description provided',
              ),
              _buildDetailRow(
                'Booked Date',
                Helpers.formatDateTime(booking.createdAt),
              ),
              _buildDetailRow(
                'Scheduled Date',
                Helpers.formatDateTime(booking.scheduledDateTime),
              ),
              _buildDetailRow(
                'Amount',
                Helpers.formatCurrency(booking.totalAmount),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ NEW: OTP Section (shows when confirmed and OTP not used)
          _buildOTPSection(booking),

          // ✅ NEW: Real-time Payment Section (shows when completed)
          // _buildRealTimePaymentSection(booking),

          // Provider Details
          _buildDetailCard(
            title: 'Service Provider',
            icon: Icons.person,
            children: [
              // Provider Name - Always show
              if (booking.providerName == null || booking.providerName!.isEmpty)
                _buildLoadingRow('Name', 'Loading provider details...')
              else
                _buildDetailRow('Name', booking.providerName!),

              // ✅ ENHANCED: Debug info for troubleshooting (can be removed in production)
              if (booking.providerPhone == null ||
                  booking.providerPhone!.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info,
                            size: 16,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Fetching Provider Data:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Provider ID: ${booking.providerId}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        'Service ID: ${booking.serviceId}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        'Provider Name: ${booking.providerName ?? "null"}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        'Provider Phone: ${booking.providerPhone ?? "null"}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: () {
                          // debugPrint(
                          //   '🔄 [CUSTOMER DETAIL] Manual provider data refresh',
                          // );
                          _loadBooking();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          minimumSize: const Size(double.infinity, 32),
                        ),
                        child: const Text(
                          'Reload Provider Data',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ✅ CRITICAL: Enhanced Privacy Logic
              if (booking.status == BookingStatus.completed ||
                  booking.status == BookingStatus.paid ||
                  booking.status == BookingStatus.cancelled ||
                  booking.status == BookingStatus.refunded) ...[
                // Privacy Notice Banner
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getProviderPrivacyColor(booking.status),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getProviderPrivacyBorderColor(booking.status),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.privacy_tip,
                        size: 16,
                        color: _getProviderPrivacyTextColor(booking.status),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getProviderPrivacyMessage(booking.status),
                          style: TextStyle(
                            fontSize: 13,
                            color: _getProviderPrivacyTextColor(booking.status),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // ✅ Show contact details for ACTIVE bookings (pending, confirmed, inProgress)
                if (booking.providerPhone != null &&
                    booking.providerPhone!.isNotEmpty) ...[
                  _buildDetailRowWithAction(
                    'Mobile Number',
                    booking.providerPhone!,
                    Icons.phone,
                    () {
                      // debugPrint(
                      //   '📞 [CUSTOMER DETAIL] Calling provider: ${booking.providerPhone}',
                      // );
                      Helpers.launchPhone(booking.providerPhone!);
                    },
                  ),
                ] else ...[
                  // ✅ Enhanced fallback with service data option
                  _buildDetailRow('Contact', 'Phone number not available'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Contact details will be available once the provider accepts your booking.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Email if available
                if (booking.providerEmail?.isNotEmpty == true)
                  _buildDetailRow('Email', booking.providerEmail!),
              ],
            ],
          ),

          const SizedBox(height: 16),

          _buildProgressSection(booking),

          // Legacy OTP Card (keep for backward compatibility but hide if new OTP section is shown)
          if (booking.status == BookingStatus.confirmed) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.security, color: Colors.orange, size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'Service Accepted!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your service provider will ask for a verification code to start the work.',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CustomerOTPScreen(booking: booking),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.code),
                      label: const Text('View Verification Code'),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Timeline
          _buildDetailCard(
            title: 'Booking Timeline',
            icon: Icons.timeline,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bookings')
                    .doc(booking.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Use live data if available
                  Map<String, dynamic>? liveData;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    liveData = snapshot.data!.data() as Map<String, dynamic>?;
                  }

                  final currentStatus = liveData?['status'] as String?;
                  final workStartTime =
                      liveData?['workStartTime'] as Timestamp?;
                  final completedAt = liveData?['completedAt'] as Timestamp?;
                  final acceptedAt =
                      liveData?['acceptedAt'] as Timestamp? ??
                      (booking.acceptedAt != null
                          ? Timestamp.fromDate(booking.acceptedAt!)
                          : null);
                  final paymentDate =
                      liveData?['paymentConfirmedAt'] as Timestamp? ??
                      liveData?['paymentDate'] as Timestamp?;

                  return Column(
                    children: [
                      // Created On
                      _buildSimpleTimelineRow(
                        Icons.calendar_today,
                        'Booked Date',
                        Helpers.formatDateTime(
                          booking.bookedDate ?? booking.createdAt,
                        ),
                        Colors.blue,
                      ),

                      // Scheduled Date
                      _buildSimpleTimelineRow(
                        Icons.access_time,
                        'Scheduled Date',
                        Helpers.formatDateTime(booking.scheduledDateTime),
                        Colors.orange,
                      ),

                      // Accepted On (if accepted)
                      if (acceptedAt != null)
                        _buildSimpleTimelineRow(
                          Icons.thumb_up,
                          'Accepted On',
                          Helpers.formatDateTime(acceptedAt.toDate()),
                          Colors.green,
                        ),

                      // Work Started (if started)
                      if (workStartTime != null)
                        _buildSimpleTimelineRow(
                          Icons.construction,
                          'Work Started',
                          Helpers.formatDateTime(workStartTime.toDate()),
                          AppColors.primary,
                        ),

                      // Completed Date (if completed)
                      if (completedAt != null)
                        _buildSimpleTimelineRow(
                          Icons.check_circle,
                          'Completed On',
                          Helpers.formatDateTime(completedAt.toDate()),
                          Colors.green,
                        ),

                      if (paymentDate != null)
                        _buildSimpleTimelineRow(
                          Icons.payment,
                          'Payment Completed',
                          Helpers.formatDateTime(paymentDate.toDate()),
                          Colors.purple,
                        )
                      else if (currentStatus == 'completed')
                        _buildSimpleTimelineRow(
                          Icons.payment,
                          'Payment Status',
                          'Payment required',
                          Colors.orange,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildRatingSection(booking),

          const SizedBox(height: 16),

          // Action Buttons (Updated to handle real-time payment)
          if (booking.status == BookingStatus.completed &&
              !booking.paymentConfirmed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RealTimePaymentScreen(booking: booking),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.payment, size: 20),
                label: const Text(
                  'Pay Now - Real Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else if (booking.status == BookingStatus.completed &&
              booking.paymentConfirmed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Payment Completed!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Thank you for using our service!',
                    style: TextStyle(color: Colors.green, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (booking.status == BookingStatus.pending)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelBooking(booking),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Cancel Booking',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(BookingModel booking) {
    // Only show rating section for paid bookings
    if (booking.status != BookingStatus.paid) {
      return const SizedBox.shrink();
    }

    return Consumer<RatingProvider>(
      builder: (context, ratingProvider, child) {
        return FutureBuilder<RatingModel?>(
          future: ratingProvider.getRatingForBooking(booking.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final rating = snapshot.data;

            if (rating != null) {
              // Show submitted rating
              return Column(
                children: [
                  const SizedBox(height: 16),
                  RatingDisplayWidget(rating: rating),
                ],
              );
            } else {
              // Show rate button if not rated
              return Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.star_border,
                          color: Colors.orange,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Rate This Service',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Share your experience to help other customers',
                          style: TextStyle(fontSize: 14, color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CustomerRatingScreen(booking: booking),
                                ),
                              );
                              if (result == true) {
                                // Refresh the page to show the new rating
                                setState(() {});
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Rate Now'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        );
      },
    );
  }

  // ✅ Simple timeline row (matching the image design)
  Widget _buildSimpleTimelineRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: OTP Section Widget
  Widget _buildOTPSection(BookingModel booking) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('otps')
          .doc(booking.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final otpDoc = snapshot.data!;
        if (!otpDoc.exists) return const SizedBox.shrink();

        final otpData = otpDoc.data() as Map<String, dynamic>;
        final String otpCode = otpData['code'] ?? '';
        final bool isUsed = otpData['isUsed'] ?? false;

        // Only show OTP if booking is confirmed and OTP hasn't been used
        if (booking.status == BookingStatus.confirmed &&
            !isUsed &&
            otpCode.isNotEmpty) {
          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.1),
                    Colors.orange.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Service Verification Code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Share this code with your service provider',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Text(
                            otpCode,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              letterSpacing: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: otpCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ OTP copied to clipboard'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Tap to copy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Keep this code ready. Your provider will ask for it to start the work.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // ✅ NEW: Helper methods for provider privacy styling
  Color _getProviderPrivacyColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return AppColors.success.withValues(alpha: 0.1);
      case BookingStatus.paid:
        return Colors.purple.withValues(alpha: 0.1);
      case BookingStatus.cancelled:
        return AppColors.error.withValues(alpha: 0.1);
      case BookingStatus.refunded:
        return Colors.orange.withValues(alpha: 0.1);
      default:
        return Colors.grey.withValues(alpha: 0.1);
    }
  }

  Color _getProviderPrivacyBorderColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return AppColors.success.withValues(alpha: 0.3);
      case BookingStatus.paid:
        return Colors.purple.withValues(alpha: 0.3);
      case BookingStatus.cancelled:
        return AppColors.error.withValues(alpha: 0.3);
      case BookingStatus.refunded:
        return Colors.orange.withValues(alpha: 0.3);
      default:
        return Colors.grey.withValues(alpha: 0.3);
    }
  }

  Color _getProviderPrivacyTextColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return AppColors.success;
      case BookingStatus.paid:
        return Colors.purple;
      case BookingStatus.cancelled:
        return AppColors.error;
      case BookingStatus.refunded:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getProviderPrivacyMessage(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return 'Service completed. Provider contact details are now protected for privacy.';
      case BookingStatus.paid:
        return 'Payment completed. Provider contact details are protected for privacy.';
      case BookingStatus.cancelled:
        return 'Booking cancelled. Provider contact details are protected for privacy.';
      case BookingStatus.refunded:
        return 'Booking refunded. Provider contact details are protected for privacy.';
      default:
        return 'Provider contact details are protected for privacy.';
    }
  }

  // Helper method for loading states
  Widget _buildLoadingRow(String label, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ ADD: Method to fetch provider details from Firestore
  Future<Map<String, dynamic>?> _fetchProviderDetails(String providerId) async {
    try {
      // debugPrint(
      //   '🔍 [CUSTOMER DETAIL] Fetching provider details for: $providerId',
      // );

      // ✅ CRITICAL: Method 1 - Try to get from booking's existing provider data first
      if (booking?.providerPhone?.isNotEmpty == true) {
        //debugPrint('✅ [CUSTOMER DETAIL] Using existing booking provider data');
        return {
          'name': booking?.providerName ?? 'Service Provider',
          'businessName': booking?.providerName ?? 'Service Provider',
          'phone': booking?.providerPhone ?? '',
          'mobileNumber': booking?.providerPhone ?? '',
          'email': booking?.providerEmail ?? '',
        };
      }

      // ✅ CRITICAL: Method 2 - Try to get from service data via booking
      final serviceDoc = await FirebaseFirestore.instance
          .collection('services')
          .doc(booking?.serviceId ?? '')
          .get();

      if (serviceDoc.exists && serviceDoc.data() != null) {
        final serviceData = serviceDoc.data()!;
        final serviceMobile = serviceData['mobileNumber'] as String?;
        final serviceProviderName =
            serviceData['providerBusinessName'] as String? ??
            serviceData['providerName'] as String?;

        if (serviceMobile?.isNotEmpty == true) {
          //debugPrint('✅ [CUSTOMER DETAIL] Provider found via service data');
          return {
            'name': serviceProviderName ?? 'Service Provider',
            'businessName': serviceProviderName ?? 'Service Provider',
            'phone': serviceMobile!,
            'mobileNumber': serviceMobile,
            'email': serviceData['providerEmail'] ?? '',
          };
        }
      }

      // ✅ Method 3 - Try Firebase Realtime Database
      try {
        //debugPrint('🔍 [CUSTOMER DETAIL] Trying Realtime Database...');
        final rtdbSnapshot = await FirebaseDatabase.instance
            .ref('users')
            .child(providerId)
            .get();

        if (rtdbSnapshot.exists && rtdbSnapshot.value != null) {
          final userData = Map<String, dynamic>.from(rtdbSnapshot.value as Map);
          //debugPrint('✅ [CUSTOMER DETAIL] Provider found in Realtime DB');

          // ✅ ENHANCED: Better field mapping with multiple phone field options
          final providerPhone =
              userData['phone']?.toString() ??
              userData['mobileNumber']?.toString() ??
              userData['mobile']?.toString() ??
              userData['phoneNumber']?.toString() ??
              '';

          final providerName =
              userData['businessName']?.toString() ??
              userData['name']?.toString() ??
              'Service Provider';

          // debugPrint('✅ [CUSTOMER DETAIL] Mapped phone: $providerPhone');
          // debugPrint('✅ [CUSTOMER DETAIL] Mapped name: $providerName');

          return {
            'name': providerName,
            'businessName': providerName,
            'phone': providerPhone,
            'mobileNumber': providerPhone,
            'email': userData['email']?.toString() ?? '',
          };
        }
      } catch (e) {
        //debugPrint('⚠️ [CUSTOMER DETAIL] Realtime DB error: $e');
      }

      // ✅ Method 4 - Try Firestore providers collection
      try {
        // debugPrint(
        //   '🔍 [CUSTOMER DETAIL] Trying Firestore providers collection...',
        // );
        final providerDoc = await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .get();

        if (providerDoc.exists && providerDoc.data() != null) {
          final providerData = providerDoc.data()!;
          // debugPrint(
          //   '✅ [CUSTOMER DETAIL] Provider found in Firestore providers',
          // );

          final providerPhone =
              providerData['mobileNumber']?.toString() ??
              providerData['phone']?.toString() ??
              providerData['mobile']?.toString() ??
              '';

          return {
            'name':
                providerData['businessName']?.toString() ?? 'Service Provider',
            'businessName':
                providerData['businessName']?.toString() ?? 'Service Provider',
            'phone': providerPhone,
            'mobileNumber': providerPhone,
            'email': providerData['email']?.toString() ?? '',
          };
        }
      } catch (e) {
        //debugPrint('⚠️ [CUSTOMER DETAIL] Firestore providers error: $e');
      }

      // ✅ Method 5 - Try Firestore users collection
      try {
        //debugPrint('🔍 [CUSTOMER DETAIL] Trying Firestore users collection...');
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(providerId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          //debugPrint('✅ [CUSTOMER DETAIL] Provider found in Firestore users');

          final providerPhone =
              userData['phone']?.toString() ??
              userData['mobileNumber']?.toString() ??
              userData['mobile']?.toString() ??
              '';

          return {
            'name': userData['name']?.toString() ?? 'Service Provider',
            'businessName':
                userData['businessName']?.toString() ??
                userData['name']?.toString() ??
                'Service Provider',
            'phone': providerPhone,
            'mobileNumber': providerPhone,
            'email': userData['email']?.toString() ?? '',
          };
        }
      } catch (e) {
        //debugPrint('⚠️ [CUSTOMER DETAIL] Firestore users error: $e');
      }

      // debugPrint(
      //   '❌ [CUSTOMER DETAIL] Provider not found in any source: $providerId',
      // );
      return null;
    } catch (e) {
      //debugPrint('❌ [CUSTOMER DETAIL] Critical error fetching provider: $e');
      return null;
    }
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithAction(
    String label,
    String value,
    IconData actionIcon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(actionIcon, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final bookingProvider = context.read<BookingProvider>();
      final success = await bookingProvider.updateBookingStatus(
        booking.id,
        BookingStatus.cancelled,
        booking.providerId,
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        // Refresh the booking data after cancellation
        await _loadBooking();
      }
    }
  }

  Widget _buildProgressSection(BookingModel booking) {
    if (booking.status != BookingStatus.inProgress) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(booking.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isWorkInProgress = (data['isWorkInProgress'] as bool?) ?? false;
        final ts = data['workStartTime'] as Timestamp?;
        final workStartTime = ts?.toDate();
        final dbProgress = ((data['workProgress'] ?? 0.0) as num).toDouble();

        if (!isWorkInProgress || workStartTime == null) {
          return const SizedBox.shrink();
        }

        final display = _computeSyncedProgress(workStartTime, dbProgress);
        final elapsed = DateTime.now().difference(workStartTime);
        final elapsedHours = elapsed.inHours;
        final remainingMinutes = elapsed.inMinutes % 60;

        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withValues(alpha: 0.1),
                  Colors.blue.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.construction,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Work in Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(display * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: display,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Time Elapsed',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          elapsedHours > 0
                              ? '${elapsedHours}h ${remainingMinutes}m'
                              : '${elapsed.inMinutes}m',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          display >= 0.75
                              ? 'Almost Complete'
                              : (display >= 0.5
                                    ? 'In Progress'
                                    : 'Getting Started'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Your service provider is working on your request.\nYou’ll be notified when it’s completed.',
                          style: TextStyle(fontSize: 14, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _computeSyncedProgress(DateTime workStartTime, double dbProgress) {
    final minutes = DateTime.now().difference(workStartTime).inMinutes;
    final intervals = minutes ~/ 15;
    final stepped = 0.10 + (intervals * 0.05);
    final computed = stepped.clamp(0.0, 0.95);
    return (dbProgress.isNaN ? 0.0 : dbProgress).clamp(0.0, 0.95) > computed
        ? dbProgress.clamp(0.0, 0.95)
        : computed;
  }
}
