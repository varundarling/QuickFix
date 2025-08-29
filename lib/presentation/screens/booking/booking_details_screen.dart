import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
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

      debugPrint(
        '🔍 [CUSTOMER DETAIL] Processing booking: ${bookingToProcess.serviceName}',
      );
      debugPrint(
        '🔍 [CUSTOMER DETAIL] Provider ID: ${bookingToProcess.providerId}',
      );

      // ✅ CRITICAL: Always fetch fresh provider details
      final providerDetails = await _fetchProviderDetails(
        bookingToProcess.providerId,
      );

      debugPrint(
        '🔍 [CUSTOMER DETAIL] Provider details result: $providerDetails',
      );

      BookingModel updatedBooking;

      if (providerDetails != null) {
        // ✅ ENHANCED: Proper field mapping with multiple fallbacks
        final providerName =
            providerDetails['businessName']?.toString() ??
            providerDetails['name']?.toString() ??
            'Unknown Provider';

        final providerPhone =
            providerDetails['phone']?.toString() ??
            providerDetails['mobileNumber']?.toString() ??
            providerDetails['mobile']?.toString() ??
            '';

        final providerEmail = providerDetails['email']?.toString() ?? '';

        debugPrint('✅ [CUSTOMER DETAIL] Mapped provider data:');
        debugPrint('   - Name: $providerName');
        debugPrint('   - Phone: $providerPhone');
        debugPrint('   - Email: $providerEmail');

        updatedBooking = bookingToProcess.copyWith(
          providerName: providerName,
          providerPhone: providerPhone,
          providerEmail: providerEmail,
        );
      } else {
        debugPrint(
          '⚠️ [CUSTOMER DETAIL] No provider details found, using fallback',
        );
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

      debugPrint(
        '✅ [CUSTOMER DETAIL] Booking loaded with provider: ${updatedBooking.providerName}',
      );
    } catch (e) {
      debugPrint('❌ [CUSTOMER DETAIL] Error loading booking: $e');
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
              // Provider Name - Always show
              if (booking.providerName == null)
                _buildLoadingRow('Name', 'Loading provider details...')
              else
                _buildDetailRow('Name', booking.providerName!),

              // ✅ CRITICAL: Privacy Logic with Helper Messages
              if (booking.status == BookingStatus.completed ||
                  booking.status == BookingStatus.paid ||
                  booking.status == BookingStatus.cancelled ||
                  booking.status == BookingStatus.refunded) ...[
                // ✅ Privacy Notice Banner (matching provider side)
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getProviderPrivacyTextColor(booking.status),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'PRIVATE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // ✅ Show contact details for ACTIVE bookings only
                if (booking.providerPhone != null &&
                    booking.providerPhone!.isNotEmpty)
                  _buildDetailRowWithAction(
                    'Mobile Number',
                    booking.providerPhone!,
                    Icons.phone,
                    () {
                      debugPrint(
                        '📞 [CUSTOMER DETAIL] Calling provider: ${booking.providerPhone}',
                      );
                      Helpers.launchPhone(booking.providerPhone!);
                    },
                  )
                else
                  _buildDetailRow('Contact', 'Contact info not available'),

                // Debug info (remove in production) - Only for active bookings
                if (booking.providerName == null ||
                    booking.providerName == 'Loading...' ||
                    booking.providerName == 'Provider information unavailable')
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Provider ID: ${booking.providerId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            debugPrint(
                              '🔄 [CUSTOMER DETAIL] Manual provider refresh',
                            );
                            _loadBooking();
                          },
                          child: const Text(
                            'Retry',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
              if (booking.completedAt != null &&
                  booking.status == BookingStatus.completed)
                _buildTimelineItem(
                  'Completion Date',
                  Helpers.formatDateTime(booking.completedAt!),
                  Icons.check_circle,
                  AppColors.success,
                ),
              if (booking.paymentDate != null)
                _buildTimelineItem(
                  'Payment Completion On',
                  Helpers.formatDateTime(booking.paymentDate!),
                  Icons.payment,
                  Colors.orange,
                ),
              // ✅ FIXED: For cancelled bookings
              if (booking.status == BookingStatus.cancelled)
                _buildTimelineItem(
                  'Booking Cancelled',
                  booking.completedAt != null
                      ? Helpers.formatDateTime(booking.completedAt!)
                      : Helpers.formatDateTime(
                          booking.createdAt,
                        ), // Fallback to creation date
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
  // Enhanced provider details fetching with better error handling
  Future<Map<String, dynamic>?> _fetchProviderDetails(String providerId) async {
    try {
      debugPrint(
        '🔍 [CUSTOMER DETAIL] Fetching provider details for: $providerId',
      );

      // Method 1: Try Firebase Realtime Database first
      try {
        debugPrint('🔍 [CUSTOMER DETAIL] Trying Realtime Database...');
        final rtdbSnapshot = await FirebaseDatabase.instance
            .ref('users')
            .child(providerId)
            .get();

        if (rtdbSnapshot.exists && rtdbSnapshot.value != null) {
          final userData = Map<String, dynamic>.from(rtdbSnapshot.value as Map);
          debugPrint('✅ [CUSTOMER DETAIL] Provider found in Realtime DB');
          debugPrint('   - Data keys: ${userData.keys.toList()}');
          debugPrint('   - Name: ${userData['name']}');
          debugPrint('   - Business Name: ${userData['businessName']}');
          debugPrint('   - Phone: ${userData['phone']}');

          return userData;
        } else {
          debugPrint('⚠️ [CUSTOMER DETAIL] Provider not found in Realtime DB');
        }
      } catch (e) {
        debugPrint('⚠️ [CUSTOMER DETAIL] Realtime DB error: $e');
      }

      // Method 2: Try Firestore users collection
      try {
        debugPrint('🔍 [CUSTOMER DETAIL] Trying Firestore users collection...');
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(providerId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          debugPrint('✅ [CUSTOMER DETAIL] Provider found in Firestore users');
          debugPrint('   - Data keys: ${userData.keys.toList()}');
          debugPrint('   - Name: ${userData['name']}');
          debugPrint('   - Business Name: ${userData['businessName']}');
          debugPrint('   - Phone: ${userData['phone']}');

          return userData;
        } else {
          debugPrint(
            '⚠️ [CUSTOMER DETAIL] Provider not found in Firestore users',
          );
        }
      } catch (e) {
        debugPrint('⚠️ [CUSTOMER DETAIL] Firestore users error: $e');
      }

      // Method 3: Try Firestore providers collection
      try {
        debugPrint(
          '🔍 [CUSTOMER DETAIL] Trying Firestore providers collection...',
        );
        final providerDoc = await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .get();

        if (providerDoc.exists && providerDoc.data() != null) {
          final providerData = providerDoc.data()!;
          debugPrint(
            '✅ [CUSTOMER DETAIL] Provider found in Firestore providers',
          );
          debugPrint('   - Data keys: ${providerData.keys.toList()}');
          debugPrint('   - Business Name: ${providerData['businessName']}');
          debugPrint('   - Mobile Number: ${providerData['mobileNumber']}');

          return providerData;
        } else {
          debugPrint(
            '⚠️ [CUSTOMER DETAIL] Provider not found in Firestore providers',
          );
        }
      } catch (e) {
        debugPrint('⚠️ [CUSTOMER DETAIL] Firestore providers error: $e');
      }

      debugPrint(
        '❌ [CUSTOMER DETAIL] Provider not found in any collection: $providerId',
      );
      return null;
    } catch (e) {
      debugPrint('❌ [CUSTOMER DETAIL] Error fetching provider details: $e');
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
      case BookingStatus.inProgress:
        return Icons.work; // New icon for in-progress status
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
