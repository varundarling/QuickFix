import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/data/models/service_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer2<BookingProvider, ServiceProvider>(
        builder: (context, bookingProvider, serviceProvider, child) {
          final bookings = bookingProvider.providerbookings;
          final services = serviceProvider.providerServices;

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh data
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Cards
                  _buildOverviewSection(bookings, services),
                  const SizedBox(height: 24),

                  // Revenue Analytics
                  _buildRevenueSection(bookings),
                  const SizedBox(height: 24),

                  // Booking Status Analytics
                  _buildBookingStatusSection(bookings),
                  const SizedBox(height: 24),

                  // Service Performance
                  _buildServicePerformanceSection(services, bookings),
                  const SizedBox(height: 24),

                  // Recent Trends
                  _buildTrendsSection(bookings),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewSection(
    List<BookingModel> bookings,
    List<ServiceModel> services,
  ) {
    final totalBookings = bookings.length;

    // ✅ FIXED: Proper type handling for revenue calculation
    final totalRevenue = bookings
        .where(
          (BookingModel b) =>
              b.status == BookingStatus.completed ||
              b.status == BookingStatus.paid,
        )
        .fold(
          0.0,
          (double sum, BookingModel b) => sum + (b.totalAmount ?? 0.0),
        );

    final avgBookingValue = totalBookings > 0
        ? totalRevenue / totalBookings
        : 0.0;

    // ✅ FIXED: Proper service filtering with explicit type
    final activeServices = services
        .where((ServiceModel s) => s.isAvailableForBooking == true)
        .length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Business Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ✅ FIXED: Wrap GridView in SizedBox with fixed height and padding
            SizedBox(
              height: 280, // Fixed height to prevent overflow
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                ), // Add horizontal padding
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 4, // Reduced spacing to prevent overflow
                  mainAxisSpacing: 4, // Reduced spacing to prevent overflow
                  childAspectRatio: 1.30, // Slightly adjusted aspect ratio
                  children: [
                    _buildMetricCard(
                      'Total Bookings',
                      totalBookings.toString(),
                      Icons.book_online,
                      AppColors.primary,
                    ),
                    _buildMetricCard(
                      'Total Revenue',
                      Helpers.formatCurrency(totalRevenue),
                      Icons.currency_rupee,
                      AppColors.success,
                    ),
                    _buildMetricCard(
                      'Avg Booking Value',
                      Helpers.formatCurrency(avgBookingValue),
                      Icons.trending_up,
                      Colors.orange,
                    ),
                    _buildMetricCard(
                      'Active Services',
                      activeServices.toString(),
                      Icons.build_circle,
                      Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueSection(List<BookingModel> bookings) {
    // ✅ FIXED: Explicit type annotations for revenue calculations
    final completedEarnings = bookings
        .where((BookingModel b) => b.status == BookingStatus.completed)
        .fold(
          0.0,
          (double sum, BookingModel b) => sum + (b.totalAmount ?? 0.0),
        );

    final paidEarnings = bookings
        .where((BookingModel b) => b.status == BookingStatus.paid)
        .fold(
          0.0,
          (double sum, BookingModel b) => sum + (b.totalAmount ?? 0.0),
        );

    final pendingEarnings = bookings
        .where(
          (BookingModel b) =>
              b.status == BookingStatus.pending ||
              b.status == BookingStatus.confirmed,
        )
        .fold(
          0.0,
          (double sum, BookingModel b) => sum + (b.totalAmount ?? 0.0),
        );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.success,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Revenue Breakdown',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildRevenueRow(
              'Completed Services',
              completedEarnings,
              AppColors.success,
            ),
            const SizedBox(height: 12),
            _buildRevenueRow('Paid Services', paidEarnings, Colors.purple),
            const SizedBox(height: 12),
            _buildRevenueRow('Pending Revenue', pendingEarnings, Colors.orange),
            const Divider(height: 24),
            _buildRevenueRow(
              'Total Earnings',
              completedEarnings + paidEarnings,
              AppColors.primary,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingStatusSection(List<BookingModel> bookings) {
    // ✅ FIXED: Proper type handling for status filtering
    final pending = bookings
        .where((BookingModel b) => b.status == BookingStatus.pending)
        .length;
    final confirmed = bookings
        .where((BookingModel b) => b.status == BookingStatus.confirmed)
        .length;
    final completed = bookings
        .where((BookingModel b) => b.status == BookingStatus.completed)
        .length;
    final paid = bookings
        .where((BookingModel b) => b.status == BookingStatus.paid)
        .length;
    final cancelled = bookings
        .where((BookingModel b) => b.status == BookingStatus.cancelled)
        .length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.indigo, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Booking Status Distribution',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatusRow('Pending', pending, Colors.orange),
            _buildStatusRow('Confirmed', confirmed, Colors.blue),
            _buildStatusRow('Completed', completed, AppColors.success),
            _buildStatusRow('Paid', paid, Colors.purple),
            _buildStatusRow('Cancelled', cancelled, AppColors.error),
          ],
        ),
      ),
    );
  }

  Widget _buildServicePerformanceSection(
    List<ServiceModel> services,
    List<BookingModel> bookings,
  ) {
    // ✅ FIXED: Proper type handling for service filtering
    final totalServices = services.length;
    final bookedServices = services
        .where((ServiceModel s) => s.isBooked == true)
        .length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Service Performance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Services',
                    totalServices.toString(),
                    Icons.build,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Booked Services',
                    bookedServices.toString(),
                    Icons.check_circle,
                    AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsSection(List<BookingModel> bookings) {
    final thisMonth = DateTime.now().month;
    final thisYear = DateTime.now().year;

    // ✅ FIXED: Proper type handling for date filtering
    final thisMonthBookings = bookings
        .where(
          (BookingModel b) =>
              b.createdAt.month == thisMonth && b.createdAt.year == thisYear,
        )
        .length;

    final thisMonthRevenue = bookings
        .where(
          (BookingModel b) =>
              b.createdAt.month == thisMonth &&
              b.createdAt.year == thisYear &&
              (b.status == BookingStatus.completed ||
                  b.status == BookingStatus.paid),
        )
        .fold(
          0.0,
          (double sum, BookingModel b) => sum + (b.totalAmount ?? 0.0),
        );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.teal, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'This Month\'s Performance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Monthly Bookings',
                    thisMonthBookings.toString(),
                    Icons.calendar_month,
                    Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Monthly Revenue',
                    Helpers.formatCurrency(thisMonthRevenue),
                    Icons.currency_rupee,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods remain the same...
  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueRow(
    String label,
    double amount,
    Color color, {
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          Helpers.formatCurrency(amount),
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
