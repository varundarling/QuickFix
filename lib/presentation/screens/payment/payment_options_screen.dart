import 'package:flutter/material.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/presentation/screens/payment/cash_payment_screen.dart';

class PaymentOptionsScreen extends StatelessWidget {
  final BookingModel booking;

  const PaymentOptionsScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Summary Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Service Completed Successfully!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      booking.serviceName,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Amount: ${Helpers.formatCurrency(booking.totalAmount)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Choose Payment Method',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // ✅ Available Payment Method - Cash
            _buildPaymentOption(
              context: context,
              icon: Icons.money,
              title: 'Cash Payment',
              subtitle: 'Pay directly to service provider',
              isAvailable: true,
              onTap: () => _handleCashPayment(context),
            ),
            const SizedBox(height: 12),

            // ✅ Unavailable Payment Methods
            _buildPaymentOption(
              context: context,
              icon: Icons.credit_card,
              title: 'Credit/Debit Card',
              subtitle: 'Coming soon - Currently unavailable',
              isAvailable: false,
            ),
            const SizedBox(height: 12),

            _buildPaymentOption(
              context: context,
              icon: Icons.account_balance_wallet,
              title: 'Digital Wallet',
              subtitle: 'PayPal, Google Pay, Apple Pay - Coming soon',
              isAvailable: false,
            ),
            const SizedBox(height: 12),

            _buildPaymentOption(
              context: context,
              icon: Icons.account_balance,
              title: 'Bank Transfer',
              subtitle: 'Direct bank transfer - Coming soon',
              isAvailable: false,
            ),
            const SizedBox(height: 12),

            _buildPaymentOption(
              context: context,
              icon: Icons.qr_code,
              title: 'UPI/QR Code',
              subtitle: 'Scan & Pay - Coming soon',
              isAvailable: false,
            ),
            const SizedBox(height: 32),

            // Information Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Payment Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Cash payment is currently the only available method\n'
                    '• Other payment methods will be available soon\n'
                    '• Contact support if you have any payment issues',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      height: 1.4,
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

  Widget _buildPaymentOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isAvailable,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: isAvailable ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAvailable
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
          width: isAvailable ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isAvailable ? AppColors.primary : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isAvailable
                                ? AppColors.textPrimary
                                : Colors.grey,
                          ),
                        ),
                        if (isAvailable) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'AVAILABLE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isAvailable
                            ? AppColors.textSecondary
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isAvailable ? Icons.arrow_forward_ios : Icons.lock,
                color: isAvailable ? AppColors.primary : Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCashPayment(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CashPaymentScreen(booking: booking),
      ),
    );
  }
}
