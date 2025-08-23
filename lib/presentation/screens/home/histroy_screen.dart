// lib/presentation/screens/history/history_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Completed',
    'Cancelled',
    'This Month',
    'Last 3 Months',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    final authProvider = context.read<AuthProvider>();
    final bookingProvider = context.read<BookingProvider>();

    if (authProvider.user != null) {
      await bookingProvider.loadUserBookings(authProvider.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Booking History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size(double.infinity, 60),
          child: _buildFilterTabs(),
        ),
      ),
      body: Consumer<BookingProvider>(
        builder: (context, bookingProvider, child) {
          if (bookingProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your history...'),
                ],
              ),
            );
          }

          final filteredBookings = _getFilteredBookings(
            bookingProvider.userBookings,
          );

          if (filteredBookings.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _loadHistory,
            child: Column(
              children: [
                _buildStatsHeader(bookingProvider.userBookings),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBookings.length,
                    itemBuilder: (context, index) {
                      return _buildHistoryCard(filteredBookings[index]);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final option = _filterOptions[index];
          final isSelected = _selectedFilter == option;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = option;
                });
              },
              backgroundColor: Colors.grey.withValues(alpha: 0.5),
              selectedColor: Colors.white,
              labelStyle: TextStyle(
                color: AppColors.primary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsHeader(List<BookingModel> allBookings) {
    final completedBookings = allBookings
        .where((b) => b.status == BookingStatus.completed)
        .length;
    final totalSpent = allBookings
        .where((b) => b.status == BookingStatus.completed)
        .fold(0.0, (sum, booking) => sum + booking.totalAmount);
    final thisMonthBookings = allBookings
        .where(
          (b) =>
              b.createdAt.year == DateTime.now().year &&
              b.createdAt.month == DateTime.now().month,
        )
        .length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Total Services',
              completedBookings.toString(),
              Icons.check_circle,
              AppColors.success,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildStatItem(
              'Total Spent',
              '₹${totalSpent.toInt()}',
              Icons.currency_rupee,
              AppColors.primary,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildStatItem(
              'This Month',
              thisMonthBookings.toString(),
              Icons.calendar_today,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHistoryCard(BookingModel booking) {
    final statusColor = Helpers.getStatusColor(booking.status.toString());
    final isCompleted = booking.status == BookingStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/customer-booking-detail/${booking.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(booking.status),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.serviceName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Helpers.formatDateTime(booking.scheduledDateTime),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          booking.statusDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${booking.totalAmount.toInt()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? AppColors.success
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (booking.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Booked on ${Helpers.formatDate(booking.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        context.push('/customer-booking-detail/${booking.id}'),
                    child: const Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'No History Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'You haven\'t booked any services yet'
                : 'No bookings found for $_selectedFilter',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            icon: const Icon(Icons.explore),
            label: const Text('Browse Services'),
          ),
        ],
      ),
    );
  }

  List<BookingModel> _getFilteredBookings(List<BookingModel> allBookings) {
    List<BookingModel> filtered = [];
    final now = DateTime.now();

    switch (_selectedFilter) {
      case 'Completed':
        filtered = allBookings
            .where((b) => b.status == BookingStatus.completed)
            .toList();
        break;
      case 'Cancelled':
        filtered = allBookings
            .where((b) => b.status == BookingStatus.cancelled)
            .toList();
        break;
      case 'This Month':
        filtered = allBookings
            .where(
              (b) =>
                  b.createdAt.year == now.year &&
                  b.createdAt.month == now.month,
            )
            .toList();
        break;
      case 'Last 3 Months':
        final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
        filtered = allBookings
            .where((b) => b.createdAt.isAfter(threeMonthsAgo))
            .toList();
        break;
      default:
        filtered = allBookings;
    }

    // Sort by date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.schedule;
      case BookingStatus.confirmed:
        return Icons.check_circle;
      case BookingStatus.completed:
        return Icons.check_circle;
      case BookingStatus.cancelled:
        return Icons.cancel;
      case BookingStatus.refunded:
        return Icons.money_off;
      case BookingStatus.paymentPending:
        // TODO: Handle this case.
        throw UnimplementedError();
      case BookingStatus.paid:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}
