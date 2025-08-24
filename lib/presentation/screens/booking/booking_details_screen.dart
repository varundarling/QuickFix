// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/presentation/screens/payment/customer_payment_screen.dart';

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

      // ✅ NEW: Fetch provider details
      final providerDetails = await _fetchProviderDetails(
        bookingToProcess.providerId,
      );

      // ✅ NEW: Update booking with provider details
      final updatedBooking = bookingToProcess.copyWith(
        providerName:
            providerDetails?['name'] ??
            providerDetails?['businessName'] ??
            'Unknown Provider',
        providerPhone:
            providerDetails?['phone'] ??
            providerDetails?['mobileNumber'] ??
            providerDetails?['mobile'] ??
            '',
        providerEmail: providerDetails?['email'] ?? '',
      );

      setState(() {
        booking = updatedBooking;
        isLoading = false;
      });
    } catch (e) {
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

  void _navigateToCustomerPayment(BookingModel booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerPaymentScreen(booking: booking),
      ),
    );
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
    final statusColor = Helpers.getStatusColor(booking.status.toString());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Card(
            color: statusColor.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(booking.status),
                    color: statusColor,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking ${booking.statusDisplay}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Booking ID: ${booking.id.substring(0, 8)}',
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
            ),
          ),
          const SizedBox(height: 20),

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
              ), // New row added
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

          // Provider Details
          _buildDetailCard(
            title: 'Service Provider',
            icon: Icons.person,
            children: [
              // ✅ UPDATED: Display provider name instead of ID
              _buildDetailRow(
                'Provider Name',
                booking.providerName ?? 'Loading...',
              ),

              // ✅ UPDATED: Show provider contact ONLY if service is NOT completed/paid
              if (booking.providerPhone != null &&
                  booking.providerPhone!.isNotEmpty &&
                  _shouldShowProviderContact(booking.status))
                _buildDetailRowWithAction(
                  'Contact',
                  booking.providerPhone!,
                  Icons.phone,
                  () => Helpers.launchPhone(booking.providerPhone!),
                ),

              // ✅ OPTIONAL: Show provider email if available
              if (booking.providerEmail != null &&
                  booking.providerEmail!.isNotEmpty)
                _buildDetailRow('Email', booking.providerEmail!),
            ],
          ),
          const SizedBox(height: 16),

          // Timeline
          _buildDetailCard(
            title: 'Booking Timeline',
            icon: Icons.timeline,
            children: [
              _buildTimelineItem(
                'Booked For',
                booking.selectedDate != null
                    ? Helpers.formatDateTime(booking.selectedDate!)
                    : 'Not available',
                Icons.calendar_today,
                Colors.blue,
              ),
              if (booking.status == BookingStatus.confirmed &&
                  booking.acceptedAt != null)
                _buildTimelineItem(
                  'Accepted on',
                  Helpers.formatDateTime(booking.acceptedAt!),
                  Icons.thumb_up,
                  Colors.green,
                ),
              if (booking.completedAt != null)
                _buildTimelineItem(
                  'Completion Date',
                  Helpers.formatDateTime(booking.completedAt!),
                  Icons.check_circle,
                  AppColors.success,
                ),
              if (booking.paymentDate != null)
                _buildTimelineItem(
                  'Payment Completion On',
                  Helpers.formatDateTime(booking.scheduledDateTime),
                  Icons.payment,
                  Colors.orange,
                ),
              // For cancelled bookings
              if (booking.status == BookingStatus.cancelled &&
                  booking.completedAt != null)
                _buildTimelineItem(
                  'Booking Cancelled',
                  Helpers.formatDateTime(booking.completedAt!),
                  Icons.cancel,
                  AppColors.error,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Buttons
          if (booking.status == BookingStatus.completed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToCustomerPayment(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.payment, size: 20),
                label: const Text(
                  'Complete Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
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

  bool _shouldShowProviderContact(BookingStatus? status) {
    if (status == null) return true;

    // Hide provider contact for completed, paid, cancelled, and refunded services
    switch (status) {
      case BookingStatus.completed:
      case BookingStatus.paid:
      case BookingStatus.cancelled:
      case BookingStatus.refunded:
        return false; // Hide contact info
      case BookingStatus.pending:
      case BookingStatus.confirmed:
      case BookingStatus.paymentPending:
        return true;
    }
  }

  // ✅ ADD: Method to fetch provider details from Firestore
  Future<Map<String, dynamic>?> _fetchProviderDetails(String providerId) async {
    try {
      debugPrint('🔍 Fetching provider details for: $providerId');

      final providerDoc = await FirebaseFirestore.instance
          .collection(
            'users',
          ) // or 'providers' if you have a separate collection
          .doc(providerId)
          .get();

      if (providerDoc.exists) {
        final providerData = providerDoc.data();
        debugPrint('✅ Provider details found: ${providerData?['name']}');
        return providerData;
      } else {
        // Try in providers collection if not found in users
        final providerInProvidersDoc = await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .get();

        if (providerInProvidersDoc.exists) {
          final providerData = providerInProvidersDoc.data();
          debugPrint(
            '✅ Provider details found in providers collection: ${providerData?['businessName']}',
          );
          return providerData;
        }

        debugPrint('❌ Provider document not found');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching provider details: $e');
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

  Widget _buildTimelineItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Timeline indicator with enhanced styling
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),

          // Timeline content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Status indicator for completed events
          if (title.contains('Completed'))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Completed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
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

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.schedule;
      case BookingStatus.confirmed:
        return Icons.construction; // More appropriate for active service
      case BookingStatus.completed:
        return Icons.done; // Different from confirmed
      case BookingStatus.cancelled:
        return Icons.cancel;
      case BookingStatus.refunded:
        return Icons.money_off;
      case BookingStatus.paymentPending:
        return Icons.pending; // Alternative: Icons.access_time, Icons.timer
      case BookingStatus.paid:
        return Icons.verified;
    }
  }
}
