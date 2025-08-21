import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';

class CustomerBookingsScreen extends StatefulWidget {
  // ✅ FIXED: No parameters needed - this screen shows ALL customer bookings
  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
    });
  }

  Future<void> _loadBookings() async {
    try {
      setState(() {
        isLoading = true;
      });

      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();

      // ✅ FIXED: Load all bookings for current user
      final currentUser = authProvider.user;
      if (currentUser != null) {
        await bookingProvider.loadUserBookings(currentUser.uid);
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bookings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your bookings...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingsList(BookingStatus.pending),
                _buildBookingsList(BookingStatus.inProgress),
                _buildBookingsList(BookingStatus.completed),
                _buildBookingsList(BookingStatus.cancelled),
              ],
            ),
    );
  }

  Widget _buildBookingsList(BookingStatus status) {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        // ✅ FIXED: Filter bookings by status from all user bookings
        final bookings = bookingProvider.userBookings
            .where((booking) => booking.status == status)
            .toList();

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getStatusIcon(status), size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No ${status.toString().split('.').last} bookings',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (status == BookingStatus.pending)
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Browse Services'),
                  ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadBookings,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              return _buildBookingCard(bookings[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    final statusColor = Helpers.getStatusColor(booking.status.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToBookingDetail(booking),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.serviceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                ],
              ),
              const SizedBox(height: 12),

              // Booking Info
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    Helpers.formatDateTime(booking.scheduledDateTime),
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Description (if available)
              if (booking.description.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.description, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking.description,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Price
              Row(
                children: [
                  Icon(
                    Icons.currency_rupee,
                    size: 16,
                    color: AppColors.success,
                  ),
                  Text(
                    '${booking.totalAmount.toInt()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  const Spacer(),
                  // View Details button
                  TextButton(
                    onPressed: () => _navigateToBookingDetail(booking),
                    child: const Text('View Details'),
                  ),
                ],
              ),

              // Action buttons based on status
              if (booking.status == BookingStatus.inProgress) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _markAsCompleted(booking),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Mark as Completed'),
                  ),
                ),
              ] else if (booking.status == BookingStatus.pending) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _cancelBooking(booking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Cancel Booking'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToBookingDetail(BookingModel booking) {
    context.push('/customer-booking-detail/${booking.id}');
  }

  Future<void> _markAsCompleted(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Completion'),
        content: const Text(
          'Are you sure the service has been completed to your satisfaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final bookingProvider = context.read<BookingProvider>();
      final success = await bookingProvider.updateBookingStatus(
        booking.id,
        BookingStatus.completed,
        booking.providerId,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service marked as completed!'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadBookings(); // Reload to refresh the UI
      }
    }
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

    if (confirmed == true && mounted) {
      final bookingProvider = context.read<BookingProvider>();
      final success = await bookingProvider.updateBookingStatus(
        booking.id,
        BookingStatus.cancelled,
        booking.providerId,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadBookings(); // Reload to refresh the UI
      }
    }
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.schedule;
      case BookingStatus.inProgress:
        return Icons.construction;
      case BookingStatus.completed:
        return Icons.check_circle;
      case BookingStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}