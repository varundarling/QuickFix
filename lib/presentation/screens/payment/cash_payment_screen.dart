import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/services/notification_service.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';

class CashPaymentScreen extends StatefulWidget {
  final BookingModel booking;

  const CashPaymentScreen({super.key, required this.booking});

  @override
  State<CashPaymentScreen> createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends State<CashPaymentScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Payment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Cash Payment Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.money,
                        size: 64,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Cash Payment',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    const Text(
                      'Pay directly to the service provider',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Payment Details Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildDetailRow(
                              'Service',
                              widget.booking.serviceName,
                            ),
                            _buildDetailRow('Provider', 'Service Provider'),
                            _buildDetailRow('Payment Method', 'Cash'),

                            const Divider(height: 24),

                            Row(
                              children: [
                                const Text(
                                  'Amount to Pay: ',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  Helpers.formatCurrency(
                                    widget.booking.totalAmount,
                                  ),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Instructions Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.amber,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Payment Instructions',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '1. Make cash payment directly to the service provider\n'
                            '2. Ensure you get a receipt for your payment\n'
                            '3. Keep the receipt for your records\n'
                            '4. Contact support if you face any issues',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.amber,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _markPaymentCompleted,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle, size: 24),
                label: Text(
                  _isProcessing ? 'Processing...' : 'Payment Completed',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _isProcessing
                    ? null
                    : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Direct Firestore update with proper refresh
  Future<void> _markPaymentCompleted() async {
    setState(() => _isProcessing = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();

      final currentUserId = authProvider.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🔄 Updating booking ${widget.booking.id} to paid status');

      // ✅ CRITICAL: Update to "paid" status instead of "completed"
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.booking.id)
          .update({
            'status': 'paid',
            'paymentConfirmed': true,
            'paymentConfirmedAt': Timestamp.fromDate(DateTime.now()),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
            'lastUpdatedBy': 'customer_$currentUserId',
          });

      debugPrint('✅ Firestore updated to paid status');

      // ✅ NEW: Send payment notification to provider
      await _sendPaymentNotificationToProvider();

      // ✅ CRITICAL: Force refresh with delay to ensure Firestore consistency
      await Future.delayed(const Duration(milliseconds: 1000));
      await bookingProvider.loadUserBookings(currentUserId);

      debugPrint('✅ User bookings refreshed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Payment completed! Provider has been notified.'),
            backgroundColor: AppColors.success,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context).pop(); // Close cash payment screen
          Navigator.of(context).pop(); // Close payment options screen
        }
        await AdService.instance.showInterstitial();
      }
    } catch (e) {
      debugPrint('❌ Error updating payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _sendPaymentNotificationToProvider() async {
    try {
      debugPrint('💰 Sending payment notification to provider...');

      final authProvider = context.read<AuthProvider>();
      final customerName = authProvider.userModel?.name ?? 'Customer';

      // Send notification to provider
      await NotificationService.instance.notifyProviderOfPaymentReceived(
        providerId: widget.booking.providerId,
        serviceName: widget.booking.serviceName,
        customerName: customerName,
        bookingId: widget.booking.id,
        paymentAmount: widget.booking.totalAmount,
      );

      debugPrint('✅ Payment notification sent to provider successfully');
    } catch (e) {
      debugPrint('❌ Error sending payment notification: $e');
      // Don't throw error - payment was successful, notification is secondary
    }
  }
}
