import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/widgets/cards/provider_card.dart';
import '../../../core/utils/navigation_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/booking_model.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    // ✅ Wait longer for authentication to be ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Add a small delay to ensure Firebase Auth is fully initialized
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _loadData();
          }
        });
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();
      final serviceProvider = context.read<ServiceProvider>();

      debugPrint('🏗️ Loading provider dashboard data...');

      // ✅ Ensure user is authenticated before loading data
      final isAuthenticated = await authProvider.ensureUserAuthenticated();

      if (!isAuthenticated) {
        debugPrint('❌ User not authenticated, cannot load services');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // ✅ Wait for user model to be loaded
      if (authProvider.userModel == null) {
        debugPrint('🔄 User model not loaded, reloading...');
        await authProvider.reloadUserData();
      }

      final userId = authProvider.getCurrentUserId();

      if (userId == null) {
        debugPrint('❌ No user ID available');
        return;
      }

      debugPrint('✅ Loading data for user: $userId');

      // Load data with proper error handling
      await Future.wait([
        bookingProvider.loadProviderBookings(userId),
        serviceProvider.loadMyServices(),
      ]);

      debugPrint('✅ Data loading completed');
    } catch (error, stackTrace) {
      debugPrint('❌ Error loading provider data: $error');
      debugPrint('Stack trace: $stackTrace');

      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load services. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadProviderServices() async {
    try {
      final serviceProvider = context.read<ServiceProvider>();
      await serviceProvider.loadMyServices();
    } catch (error) {
      debugPrint('❌ Error loading services: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh services'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void safeSetState(VoidCallback fn) {
    if (!mounted) return;

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      setState(fn);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ Building ProviderDashboardScreen');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            onPressed: () => context.go('/provider-profile'),
            icon: const Icon(Icons.person),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                // ✅ Use NavigationHelper for logout
                NavigationHelper.handleLogout(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Services'),
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildServicesTab(),
          _buildBookingsTab(BookingStatus.pending),
          _buildBookingsTab(BookingStatus.inProgresss),
          _buildHistoryTab(),
        ],
      ),
      // ✅ Add this after the body
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/create-service'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _loadDataFuture() async {
    final authProvider = context.read<AuthProvider>();
    final bookingProvider = context.read<BookingProvider>();
    final serviceProvider = context.read<ServiceProvider>();

    if (authProvider.user != null) {
      await Future.wait([
        bookingProvider.loadProviderBookings(authProvider.user!.uid),
        serviceProvider.loadMyServices(),
      ]);
    }
  }

  Widget _buildOverviewTab() {
    return FutureBuilder(
      future: _loadDataFuture(), // Create this future once
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return Consumer2<BookingProvider, ServiceProvider>(
          // ✅ Changed from Consumer to Consumer2
          builder: (context, bookingProvider, serviceProvider, child) {
            // ✅ Added serviceProvider parameter
            final bookings = bookingProvider.providerbookings;
            final services = serviceProvider.services; // ✅ Added this line

            final pendingBookings = bookings
                .where((b) => b.status == BookingStatus.pending)
                .length;
            final activeBookings = bookings
                .where((b) => b.status == BookingStatus.inProgresss)
                .length;
            final completedBookings = bookings
                .where((b) => b.status == BookingStatus.completed)
                .length;
            final totalEarnings = bookings
                .where((b) => b.status == BookingStatus.completed)
                .fold(0.0, (sum, booking) => sum + booking.totalAmount);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Welcome back!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You have ${services.length} services and $pendingBookings pending bookings', // ✅ Updated this line
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.business_center,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ✅ Updated Statistics Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildStatCard(
                        // ✅ Added services stat card
                        'Services',
                        services.length.toString(),
                        Icons.build,
                        AppColors.primary,
                      ),
                      _buildStatCard(
                        'Active',
                        activeBookings.toString(),
                        Icons.construction,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Pending',
                        pendingBookings.toString(),
                        Icons.schedule,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Completed',
                        completedBookings.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Earnings',
                        Helpers.formatCurrency(totalEarnings),
                        Icons.account_balance_wallet,
                        AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Recent Bookings (keep your existing code here)
                  const Text(
                    'Recent Bookings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...bookings
                      .take(3)
                      .map((booking) => _buildBookingCard(booking)),

                  if (bookings.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'No bookings yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBookingsTab(BookingStatus status) {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        final bookings = bookingProvider.providerbookings
            .where((b) => b.status == status)
            .toList();

        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getStatusIcon(status),
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${status.toString().split('.').last} bookings',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _loadData();
          },
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

  Widget _buildHistoryTab() {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        final bookings = bookingProvider.providerbookings
            .where(
              (b) =>
                  b.status == BookingStatus.completed ||
                  b.status == BookingStatus.cancelled,
            )
            .toList();

        if (bookings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: AppColors.textSecondary),
                SizedBox(height: 16),
                Text(
                  'No booking history',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _loadData();
          },
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    final statusColor = Helpers.getStatusColor(booking.status.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.serviceName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
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
            const SizedBox(height: 8),

            Text(
              'Customer: ${booking.customerId.substring(0, 8)}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              'Date: ${Helpers.formatDateTime(booking.scheduledDateTime)}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              'Amount: ${Helpers.formatCurrency(booking.totalAmount)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),

            // Action buttons
            if (booking.status == BookingStatus.pending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateBookingStatus(
                        booking.id,
                        BookingStatus.cancelled,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateBookingStatus(
                        booking.id,
                        BookingStatus.confirmed,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ] else if (booking.status == BookingStatus.confirmed) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _updateBookingStatus(
                    booking.id,
                    BookingStatus.inProgresss,
                  ),
                  child: const Text('Start Service'),
                ),
              ),
            ] else if (booking.status == BookingStatus.inProgresss) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      _updateBookingStatus(booking.id, BookingStatus.completed),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  child: const Text('Mark as Completed'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    final bookingProvider = context.read<BookingProvider>();

    final success = await bookingProvider.updateBookingStatus(
      bookingId,
      status,
    );

    if (success && mounted) {
      Helpers.showSnackBar(
        context,
        'Booking ${status.toString().split('.').last} successfully',
        backgroundColor: AppColors.success,
      );
    }
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.schedule;
      case BookingStatus.confirmed:
        return Icons.check_circle;
      case BookingStatus.inProgresss:
        return Icons.construction;
      case BookingStatus.completed:
        return Icons.check_circle;
      case BookingStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Widget _buildServicesTab() {
    return Consumer<ServiceProvider>(
      builder: (context, serviceProvider, child) {
        if (serviceProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Loading your services...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        if (serviceProvider.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Oops! Something went wrong',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    serviceProvider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _loadProviderServices(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final services = serviceProvider.services;

        if (services.isEmpty) {
          return _buildEmptyServicesState();
        }

        return Column(
          children: [
            // Header Section
            _buildServicesHeader(services.length),
        
            // Services List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  return ProviderCard(
                    service: service,
                    onTap: () => context.go('/edit-service/${service.id}'),
                    customButtonText: 'Manage Service',
                    onServiceDeleted: () => _refreshServicesAfterDeletion(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ Add this method to refresh services after deletion
  Future<void> _refreshServicesAfterDeletion() async {
    try {
      final serviceProvider = context.read<ServiceProvider>();
      await serviceProvider.loadMyServices();
    } catch (error) {
      debugPrint('❌ Error refreshing services after deletion: $error');
    }
  }

  Widget _buildServicesHeader(int serviceCount) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Container(
          //   padding: const EdgeInsets.all(12),
          //   decoration: BoxDecoration(
          //     color: Colors.white.withOpacity(0.2),
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: const Icon(
          //     Icons.business_center,
          //     color: Colors.white,
          //     size: 24,
          //   ),
          // ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'My Services',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$serviceCount ${serviceCount == 1 ? 'service' : 'services'} available',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyServicesState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary.withValues(alpha: 0.02), Colors.white],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(80),
                ),
                child: Icon(
                  Icons.build_circle_outlined,
                  size: 80,
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'No Services Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Create your first service to start\nreceiving bookings from customers',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/create-service'),
                  icon: const Icon(Icons.add_business, size: 24),
                  label: const Text('Create Your First Service'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Quick benefits
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    _buildBenefitRow(
                      Icons.visibility,
                      'Get discovered by customers',
                    ),
                    const SizedBox(height: 12),
                    _buildBenefitRow(Icons.trending_up, 'Grow your business'),
                    const SizedBox(height: 12),
                    _buildBenefitRow(Icons.payments, 'Earn more revenue'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
