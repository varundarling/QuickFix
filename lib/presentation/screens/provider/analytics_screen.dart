import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/data/models/service_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/presentation/providers/rating_providers.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final ratingProvider = context.read<RatingProvider>();
      final currentUserId = authProvider.getCurrentUserId();

      if (currentUserId != null) {
        await ratingProvider.loadProviderRatingStats(currentUserId);
      }
    } catch (e) {
      // debugPrint('Error loading analytics data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Business Stats',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refreshData,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Consumer3<BookingProvider, ServiceProvider, RatingProvider>(
        builder:
            (context, bookingProvider, serviceProvider, ratingProvider, child) {
              final bookings = bookingProvider.providerbookings;
              final services = serviceProvider.providerServices;

              return RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewSection(bookings, services, ratingProvider),
                      const SizedBox(height: 20),
                      _buildFinancialSection(bookings),
                      const SizedBox(height: 20),
                      _buildServiceSection(services, bookings),
                      const SizedBox(height: 20),
                      _buildMonthlySection(bookings),
                      const SizedBox(height: 20),
                      _buildRatingSection(
                        ratingProvider,
                      ), // Moved here - below monthly
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
    RatingProvider ratingProvider,
  ) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.getCurrentUserId();
    final ratingStats = currentUserId != null
        ? ratingProvider.getProviderStats(currentUserId)
        : null;

    final totalBookings = bookings.length;
    final totalRevenue = bookings
        .where(
          (b) =>
              b.status == BookingStatus.completed ||
              b.status == BookingStatus.paid,
        )
        .fold(0.0, (sum, b) => sum + (b.totalAmount));
    final avgRating = ratingStats?['averageRating']?.toDouble() ?? 0.0;
    final totalReviews = ratingStats?['totalReviews'] ?? 0;
    final activeServices = services.where((s) => s.isActive).length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dashboard_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Quick Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Fixed overflow issue with LayoutBuilder and proper sizing
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final itemWidth =
                    (availableWidth - 12) / 2; // 2 items per row with 12px gap

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _buildOverviewCard(
                        'Total Jobs',
                        totalBookings.toString(),
                        Icons.work_rounded,
                        AppColors.primary,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildOverviewCard(
                        'Money Earned',
                        Helpers.formatCurrency(totalRevenue),
                        Icons.attach_money,
                        Colors.green,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildOverviewCard(
                        'Star Rating',
                        avgRating > 0 ? avgRating.toStringAsFixed(1) : 'None',
                        Icons.star_rounded,
                        Colors.amber,
                        subtitle: totalReviews > 0
                            ? '$totalReviews reviews'
                            : 'No reviews yet',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildOverviewCard(
                        'Active Services',
                        activeServices.toString(),
                        Icons.build_circle_rounded,
                        Colors.blue,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialSection(List<BookingModel> bookings) {
    final completedEarnings = bookings
        .where((b) => b.status == BookingStatus.completed)
        .fold(0.0, (sum, b) => sum + (b.totalAmount));

    final paidEarnings = bookings
        .where((b) => b.status == BookingStatus.paid)
        .fold(0.0, (sum, b) => sum + (b.totalAmount));

    final pendingEarnings = bookings
        .where(
          (b) =>
              b.status == BookingStatus.pending ||
              b.status == BookingStatus.confirmed,
        )
        .fold(0.0, (sum, b) => sum + (b.totalAmount));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Money Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            // const SizedBox(height: 20),
            // _buildFinancialRow(
            //   'Finished Jobs',
            //   completedEarnings,
            //   Colors.green,
            //   Icons.check_circle_rounded,
            // ),
            const SizedBox(height: 12),
            _buildFinancialRow(
              'Paid Jobs',
              paidEarnings,
              Colors.green,
              Icons.payment_rounded,
            ),
            const SizedBox(height: 12),
            _buildFinancialRow(
              'Waiting for Payment',
              pendingEarnings,
              Colors.orange,
              Icons.schedule_rounded,
            ),
            const Divider(height: 24),
            _buildFinancialRow(
              'Total Money Made',
              completedEarnings + paidEarnings,
              AppColors.primary,
              Icons.trending_up_rounded,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSection(
    List<ServiceModel> services,
    List<BookingModel> bookings,
  ) {
    final totalServices = services.length;
    final activeServices = services.where((s) => s.isActive).length;
    final bookedServices = services.where((s) => s.isBooked).length;
    final avgBookings = totalServices > 0
        ? (bookings.length / totalServices).toStringAsFixed(1)
        : '0';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_circle_rounded, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'My Services',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final itemWidth = (availableWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _buildServiceCard(
                        'All Services',
                        totalServices.toString(),
                        Icons.build_rounded,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildServiceCard(
                        'Available Now',
                        activeServices.toString(),
                        Icons.check_circle_rounded,
                        Colors.green,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildServiceCard(
                        'Currently Booked',
                        bookedServices.toString(),
                        Icons.event_available_rounded,
                        Colors.orange,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildServiceCard(
                        'Average Jobs',
                        avgBookings,
                        Icons.trending_up_rounded,
                        Colors.purple,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySection(List<BookingModel> bookings) {
    final now = DateTime.now();
    final monthlyBookings = bookings
        .where(
          (b) => b.createdAt.month == now.month && b.createdAt.year == now.year,
        )
        .length;

    final monthlyRevenue = bookings
        .where(
          (b) =>
              b.createdAt.month == now.month &&
              b.createdAt.year == now.year &&
              (b.status == BookingStatus.completed ||
                  b.status == BookingStatus.paid),
        )
        .fold(0.0, (sum, b) => sum + (b.totalAmount));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.teal,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'This Month',
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
                  child: _buildMonthlyCard(
                    'Jobs This Month',
                    monthlyBookings.toString(),
                    Icons.work_rounded,
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMonthlyCard(
                    'Money This Month',
                    Helpers.formatCurrency(monthlyRevenue),
                    Icons.attach_money,
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

  Widget _buildRatingSection(RatingProvider ratingProvider) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.getCurrentUserId();
    final ratingStats = currentUserId != null
        ? ratingProvider.getProviderStats(currentUserId)
        : null;

    final avgRating = ratingStats?['averageRating']?.toDouble() ?? 0.0;
    final totalReviews = ratingStats?['totalReviews'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Customer Reviews',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (totalReviews > 0)
              _buildRatingContent(avgRating, totalReviews)
            else
              _buildNoRatingContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingContent(double avgRating, int totalReviews) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  RatingBarIndicator(
                    rating: avgRating,
                    itemBuilder: (context, index) =>
                        const Icon(Icons.star, color: Colors.amber),
                    itemCount: 5,
                    itemSize: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalReviews Reviews',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildRatingBar('5 Stars', 0.7, Colors.green),
                  _buildRatingBar('4 Stars', 0.2, Colors.lightGreen),
                  _buildRatingBar('3 Stars', 0.1, Colors.orange),
                  _buildRatingBar('2 Stars', 0.0, Colors.deepOrange),
                  _buildRatingBar('1 Star', 0.0, Colors.red),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildRatingMetric(
                'Happy Customers',
                '${(avgRating >= 4.5
                    ? 95
                    : avgRating >= 4.0
                    ? 85
                    : avgRating >= 3.5
                    ? 75
                    : 65)}%',
                Icons.sentiment_very_satisfied_rounded,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRatingMetric(
                'Response Rate',
                '${((totalReviews / (totalReviews + 5)) * 100).toInt()}%',
                Icons.reply_rounded,
                Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingBar(String label, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 35,
            child: Text(
              '${(percentage * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingMetric(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoRatingContent() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.star_border_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Reviews Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete more jobs to get customer reviews',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(
    String label,
    double amount,
    Color color,
    IconData icon, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 16 : 15,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            Helpers.formatCurrency(amount),
            style: TextStyle(
              fontSize: isTotal ? 16 : 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    await _loadData();
  }
}
