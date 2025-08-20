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
  String? _currentUserId;
  BookingProvider? _bookingProvider; // ✅ Store provider reference
  AuthProvider? _authProvider; // ✅ Store provider reference

  final Map<String, bool> _processingBookings = {};

  bool _isBookingProcessing(String bookingId) {
    return _processingBookings[bookingId] ?? false;
  }

  void _setBookingProcessing(String bookingId, bool processing) {
    if (mounted) {
      setState(() {
        _processingBookings[bookingId] = processing;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        debugPrint('📱 Tab changed to: ${_tabController.index}');
        final tabNames = [
          'Overview',
          'Services',
          'Pending',
          'Active',
          'History',
        ];
        debugPrint('📱 Current tab: ${tabNames[_tabController.index]}');
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _setupRealTimeListening();
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Save provider references early to avoid context access in dispose
    _bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
  }

  Future<void> _setupRealTimeListening() async {
    if (!mounted) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();
      final serviceProvider = context.read<ServiceProvider>();

      debugPrint('🏗️ Setting up real-time listeners...');

      final isAuthenticated = await authProvider.ensureUserAuthenticated();
      if (!isAuthenticated) {
        debugPrint('❌ User not authenticated, cannot set up listeners');
        return;
      }

      final userId = authProvider.getCurrentUserId();
      if (userId == null) {
        debugPrint('❌ No user ID available');
        return;
      }

      _currentUserId = userId;
      debugPrint('✅ Setting up listeners for provider: $userId');

      // Start real-time listening to bookings
      bookingProvider.listenToProviderBookings(userId);

      // Load services once
      await serviceProvider.loadMyServices();

      debugPrint('✅ Real-time listening setup completed');
    } catch (error, stackTrace) {
      debugPrint('❌ Error setting up real-time listeners: $error');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to setup dashboard: ${error.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _setupRealTimeListening(),
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();
      final serviceProvider = context.read<ServiceProvider>();

      debugPrint('🏗️ Loading provider dashboard data...');

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

      await Future.wait([
        bookingProvider.loadProviderBookings(userId),
        serviceProvider.loadMyServices(),
      ]);

      debugPrint('✅ Data loading completed');
    } catch (error, stackTrace) {
      debugPrint('❌ Error loading provider data: $error');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard: ${error.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _setupRealTimeListening(),
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadProviderServices() async {
    if (!mounted) return;

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
          _buildBookingsTab(BookingStatus.pending), // Pending tab
          _buildBookingsTab(
            BookingStatus.inProgress,
          ), // Active tab (in progress bookings)
          _buildHistoryTab(), // History tab
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/create-service'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Consumer2<BookingProvider, ServiceProvider>(
      builder: (context, bookingProvider, serviceProvider, child) {
        if (bookingProvider.isLoading || serviceProvider.isLoading) {
          return RefreshIndicator(
            onRefresh: () async {
              if (_currentUserId != null) {
                await Future.wait([
                  bookingProvider.loadProviderBookings(_currentUserId!),
                  serviceProvider.loadMyServices(),
                ]);
              }
            },
            child: const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading dashboard...'),
                  ],
                ),
              ),
            ),
          );
        }

        final bookings = bookingProvider.providerbookings;
        final services = serviceProvider.services;
        final pendingBookings = bookings
            .where((b) => b.status == BookingStatus.pending)
            .length;
        final activeBookings = bookings
            .where((b) => b.status == BookingStatus.inProgress)
            .length;
        final completedBookings = bookings
            .where((b) => b.status == BookingStatus.completed)
            .length;
        final totalEarnings = bookings
            .where((b) => b.status == BookingStatus.completed)
            .fold(0.0, (sum, booking) => sum + booking.totalAmount);

        return RefreshIndicator(
          onRefresh: () async {
            if (_currentUserId != null) {
              await Future.wait([
                bookingProvider.loadProviderBookings(_currentUserId!),
                serviceProvider.loadMyServices(),
              ]);
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Real-time status indicator
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Real-time updates active'),
                        const Spacer(),
                        Text(
                          'Last updated: ${DateTime.now().toString().substring(11, 19)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                                'You have ${services.length} services and $pendingBookings pending bookings',
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

                // Statistics Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildStatCard(
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

                // Recent Bookings
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
          ),
        );
      },
    );
  }

  Widget _buildBookingsTab(BookingStatus status) {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        List<BookingModel> bookings;

        // ✅ Fix filtering logic for Active tab
        if (status == BookingStatus.inProgress) {
          // Active tab shows BOTH confirmed AND inProgress bookings
          bookings = [
            ...bookingProvider.confirmedBookings, // Accepted bookings
            ...bookingProvider.activeBookings, // Started bookings
          ];
          debugPrint(
            '🔍 Active tab bookings: ${bookings.length} (${bookingProvider.confirmedBookings.length} confirmed + ${bookingProvider.activeBookings.length} in progress)',
          );
        } else {
          // Other tabs show their specific status
          bookings = bookingProvider.providerbookings
              .where((b) => b.status == status)
              .toList();
          debugPrint(
            '🔍 ${status.toString().split('.').last} tab bookings: ${bookings.length}',
          );
        }

        if (bookings.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              if (_currentUserId != null) {
                await bookingProvider.loadProviderBookings(_currentUserId!);
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
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
                        status == BookingStatus.inProgress
                            ? 'No active bookings'
                            : 'No ${_getStatusDisplayName(status)} bookings',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          if (_currentUserId != null) {
                            bookingProvider.loadProviderBookings(
                              _currentUserId!,
                            );
                          }
                        },
                        child: const Text('Tap to refresh'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (_currentUserId != null) {
              await bookingProvider.loadProviderBookings(_currentUserId!);
            }
          },
          child: ListView.builder(
            key: PageStorageKey<String>('${status.toString()}_list'),
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
          return RefreshIndicator(
            onRefresh: () async {
              await _loadData();
            },
            child: const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
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
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _loadData();
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
    if (booking.status == null) {
      return const SizedBox.shrink();
    }

    final statusColor = Helpers.getStatusColor(booking.status.toString());

    return Card(
      key: ValueKey('booking_${booking.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.serviceName ?? 'Unknown Service',
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

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Customer Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ✅ Customer name
                  Row(
                    children: [
                      Icon(
                        Icons.account_circle,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.customerName ?? 'Loading customer...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: booking.customerName != null
                                ? AppColors.textPrimary
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ✅ Customer phone (only show if not null and not 'No Phone')
                  if (booking.customerPhone != null &&
                      booking.customerPhone != 'No Phone' &&
                      booking.customerPhone!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            booking.customerPhone!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        // ✅ Call button
                        InkWell(
                          onTap: () {
                            if (booking.customerPhone != null &&
                                booking.customerPhone != 'No Phone') {
                              Helpers.launchPhone(booking.customerPhone!);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.call,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

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

            // ✅ Dynamic action buttons based on booking status
            _buildBookingActions(booking),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingActions(BookingModel booking) {
    final isProcessing = _isBookingProcessing(booking.id);

    switch (booking.status) {
      case BookingStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isProcessing
                    ? null
                    : () => _updateBookingStatus(
                        booking.id,
                        BookingStatus.cancelled,
                      ),
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close, size: 16),
                label: Text(isProcessing ? 'Processing...' : 'Decline'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isProcessing
                    ? null
                    : () => _updateBookingStatus(
                        booking.id,
                        BookingStatus.confirmed,
                      ),
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check, size: 16),
                label: Text(isProcessing ? 'Accepting...' : 'Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
              ),
            ),
          ],
        );

      case BookingStatus.confirmed:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isProcessing
                ? null
                : () => _updateBookingStatus(
                    booking.id,
                    BookingStatus.inProgress,
                  ),
            icon: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.play_arrow, size: 16),
            label: Text(isProcessing ? 'Starting...' : 'Start Service'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        );

      case BookingStatus.inProgress:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isProcessing
                ? null
                : () =>
                      _updateBookingStatus(booking.id, BookingStatus.completed),
            icon: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle, size: 16),
            label: Text(isProcessing ? 'Completing...' : 'Mark as Completed'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _updateBookingStatus(
    String bookingId,
    BookingStatus newStatus,
  ) async {
    if (!mounted || _isBookingProcessing(bookingId)) return;

    final authProvider = context.read<AuthProvider>();
    final bookingProvider = context.read<BookingProvider>();

    final currentUserId = authProvider.getCurrentUserId();
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      }
      return;
    }

    _setBookingProcessing(bookingId, true);

    try {
      bookingProvider.debugCurrentState('Before update');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false, // ✅ Updated from WillPopScope
          child: const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Updating booking status...'),
              ],
            ),
          ),
        ),
      );

      final success = await bookingProvider.updateBookingStatus(
        bookingId,
        newStatus,
        currentUserId,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      if (success) {
        bookingProvider.debugCurrentState('After Update');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking ${newStatus.statusDisplay.toLowerCase()} successfully',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );

        // ✅ Navigate to appropriate tab IMMEDIATELY
        _navigateToAppropriateTab(newStatus);

        if (mounted) {
          setState(() {});
        }

        // ✅ Refresh data after a short delay
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          bookingProvider.debugCurrentState('After refresh');
          await bookingProvider.loadProviderBookings(
            currentUserId,
          ); // Use existing method
        }
      } else {
        final errorMessage =
            bookingProvider.errorMessage ?? 'Failed to update booking status';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        _setBookingProcessing(bookingId, false);
      }
    }
  }

  // ✅ Add this helper method for tab navigation
  void _navigateToAppropriateTab(BookingStatus newStatus) {
    int targetTabIndex;

    switch (newStatus) {
      case BookingStatus.confirmed:
        targetTabIndex = 3; // Active tab
        debugPrint('📍 Navigating to Active tab (confirmed booking)');
        break;
      case BookingStatus.inProgress:
        targetTabIndex = 3; // Active tab
        debugPrint('📍 Staying in Active tab (in progress booking)');
        break;
      case BookingStatus.completed:
        targetTabIndex = 4; // History tab
        debugPrint('📍 Navigating to History tab (completed booking)');
        break;
      case BookingStatus.cancelled:
        targetTabIndex = 4; // History tab
        debugPrint('📍 Navigating to History tab (cancelled booking)');
        break;
      default:
        debugPrint('📍 No tab navigation needed for status: $newStatus');
        return;
    }

    // Animate to target tab with smooth transition
    _tabController.animateTo(
      targetTabIndex,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );

    debugPrint('📍 Tab animation initiated to index: $targetTabIndex');
  }

  Future<bool> _showConfirmationDialog(
    String action,
    String serviceName,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm $action'),
            content: Text(
              'Are you sure you want to $action the booking for "$serviceName"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: Text(action == 'accept' ? 'Accept' : 'Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.schedule;
      case BookingStatus.confirmed:
        return Icons.check_circle;
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

  Widget _buildServicesTab() {
    return Consumer<ServiceProvider>(
      builder: (context, serviceProvider, child) {
        if (serviceProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
            _buildServicesHeader(services.length),
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

  Future<void> _refreshServicesAfterDeletion() async {
    if (!mounted) return;

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
        gradient: const LinearGradient(
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

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
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

  String _getStatusDisplayName(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'pending';
      case BookingStatus.confirmed:
        return 'confirmed';
      case BookingStatus.inProgress:
        return 'active';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
      default:
        return 'unknown';
    }
  }

  @override
  void dispose() {
    _processingBookings.clear();
    // ✅ Use stored reference instead of accessing context
    if (_bookingProvider != null) {
      _bookingProvider!.stopListeningToProviderBookings();
    }
    _tabController.dispose();
    super.dispose();
  }
}