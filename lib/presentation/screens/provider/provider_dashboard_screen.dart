import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/screens/provider/booking_detail_for_provider.dart';
import 'package:quickfix/presentation/widgets/cards/provider_card.dart';
import 'package:quickfix/presentation/widgets/dialogs/profile_completion_dialog.dart';
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
  BookingProvider? _bookingProvider;
  AuthProvider? _authProvider;

  bool isLoading = true;
  // ✅ FIXED: Added missing variables
  StreamSubscription<QuerySnapshot>? _providerBookingsSubscription;
  bool _isUpdatingStatus = false;
  Set<String> _updatingBookings = {}; // Track multiple updating bookings
  final Map<String, bool> _processingBookings = {};

  Timer? _realTimeUpdateTimer;

  final List<Map<String, dynamic>> _tabs = [
    {
      'label': 'Pending',
      'status': BookingStatus.pending,
      'icon': Icons.schedule,
    },
    {
      'label': 'Active',
      'status': BookingStatus.confirmed,
      'icon': Icons.construction,
    },
    {
      'label': 'History',
      'status': BookingStatus.completed,
      'icon': Icons.history,
    },
    {'label': 'Profile', 'icon': Icons.person},
  ];
  bool _isBookingProcessing(String bookingId) {
    return _processingBookings[bookingId] ?? false;
  }

  void _setBookingProcessing(String bookingId, bool processing) {
    if (mounted) {
      setState(() {
        _processingBookings[bookingId] = processing;
        if (processing) {
          _updatingBookings.add(bookingId);
        } else {
          _updatingBookings.remove(bookingId);
        }
      });
    }
  }

  void _navigateToCreateService() async {
    final authProvider = context.read<AuthProvider>();

    // Check if provider profile is complete
    if (!authProvider.isProviderProfileComplete) {
      await ProfileCompletionDialog.show(
        context,
        'provider',
        authProvider.missingProviderFields,
      );
      return;
    }

    // If profile is complete, proceed to create service
    context.push('/create-service');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  Future<void> _initializeDashboard() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();

      // Ensure user is authenticated
      final isAuthenticated = await authProvider.ensureUserAuthenticated();
      if (!isAuthenticated) {
        debugPrint('❌ User not authenticated');
        return;
      }

      // Get current user ID
      final currentUserId = authProvider.getCurrentUserId();
      if (currentUserId == null) {
        debugPrint('❌ No user ID available');
        return;
      }

      _currentUserId = currentUserId;
      debugPrint('✅ Initializing dashboard for provider: $currentUserId');

      // ✅ CRITICAL: Initialize BookingProvider with current user ID
      await bookingProvider.initializeProvider(currentUserId);

      // Load services
      final serviceProvider = context.read<ServiceProvider>();
      await serviceProvider.loadMyServices();

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      debugPrint('✅ Dashboard initialization completed');
    } catch (error) {
      debugPrint('❌ Error initializing dashboard: $error');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize dashboard: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Save provider references early to avoid context access in dispose
    _bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
  }

  // ✅ FIXED: Added missing _fetchCustomerDetails method
  Future<Map<String, dynamic>?> _fetchCustomerDetails(String customerId) async {
    try {
      debugPrint('🔍 [DEBUG] Starting customer fetch for ID: $customerId');
      debugPrint('🔍 [DEBUG] Customer ID length: ${customerId.length}');
      debugPrint('🔍 [DEBUG] Customer ID type: ${customerId.runtimeType}');

      // Check if customerId is valid
      if (customerId.isEmpty) {
        debugPrint('❌ [ERROR] Customer ID is empty');
        return {
          'customerName': 'Invalid Customer ID',
          'customerPhone': '',
          'customerEmail': '',
        };
      }

      // Try users collection first
      debugPrint('🔍 [DEBUG] Checking users collection...');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();

      debugPrint('🔍 [DEBUG] Users query completed. Exists: ${userDoc.exists}');

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        debugPrint('✅ [SUCCESS] Customer found in users collection:');
        debugPrint('   - Name: ${userData['name']}');
        debugPrint('   - Phone: ${userData['phone'] ?? userData['mobile']}');
        debugPrint('   - Email: ${userData['email']}');

        return {
          'customerName': userData['name']?.toString() ?? 'Unknown Customer',
          'customerPhone':
              userData['phone']?.toString() ??
              userData['mobile']?.toString() ??
              '',
          'customerEmail': userData['email']?.toString() ?? '',
        };
      }

      // Try customers collection as fallback
      debugPrint('🔍 [DEBUG] Checking customers collection...');
      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .get();

      debugPrint(
        '🔍 [DEBUG] Customers query completed. Exists: ${customerDoc.exists}',
      );

      if (customerDoc.exists && customerDoc.data() != null) {
        final customerData = customerDoc.data()!;
        debugPrint('✅ [SUCCESS] Customer found in customers collection:');
        debugPrint('   - Name: ${customerData['name']}');
        debugPrint(
          '   - Phone: ${customerData['phone'] ?? customerData['mobile']}',
        );

        return {
          'customerName':
              customerData['name']?.toString() ?? 'Unknown Customer',
          'customerPhone':
              customerData['phone']?.toString() ??
              customerData['mobile']?.toString() ??
              '',
          'customerEmail': customerData['email']?.toString() ?? '',
        };
      }

      // If not found in either collection
      debugPrint('❌ [ERROR] Customer not found in any collection');
      debugPrint('   - Checked users/$customerId: ${userDoc.exists}');
      debugPrint('   - Checked customers/$customerId: ${customerDoc.exists}');

      return {
        'customerName': 'Customer Not Found',
        'customerPhone': '',
        'customerEmail': '',
      };
    } catch (e, stackTrace) {
      debugPrint('❌ [ERROR] Exception fetching customer details: $e');
      debugPrint('❌ [STACK] $stackTrace');
      return {
        'customerName': 'Error Loading Customer',
        'customerPhone': '',
        'customerEmail': '',
      };
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
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                InkWell(
                  onTap: () => context.go('/provider-profile'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.person_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
          _buildOverviewTab(), // Tab 0: Overview
          _buildServicesTab(), // Tab 1: Services
          _buildBookingsTab(BookingStatus.pending), // Tab 2: Pending
          _buildBookingsTab(BookingStatus.confirmed), // Tab 3: Active
          _buildBookingsTab(BookingStatus.completed), // Tab 4: History
        ],
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
                  bookingProvider.loadProviderBookingsWithCustomerData(
                    _currentUserId!,
                  ),
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
        final services =
            serviceProvider.providerServices; // ✅ FIXED: Use correct getter
        final pendingBookings = bookings
            .where((b) => b.status == BookingStatus.pending)
            .length;
        final completedBookings = bookings
            .where((b) => b.status == BookingStatus.completed)
            .length;
        final cancelledBookings = bookings
            .where((b) => b.status == BookingStatus.cancelled)
            .length;
        final totalEarnings = bookings
            .where((b) => b.status == BookingStatus.completed)
            .fold(0.0, (total, booking) => total + booking.totalAmount);

        return RefreshIndicator(
          onRefresh: () async {
            if (_currentUserId != null) {
              await Future.wait([
                bookingProvider.loadProviderBookingsWithCustomerData(
                  _currentUserId!,
                ),
                serviceProvider.loadMyServices(),
              ]);
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Real-time status indicator
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
                    _buildStatCard(
                      'Cancelled',
                      cancelledBookings.toString(),
                      Icons.cancel,
                      AppColors.error,
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

  String _getActionText(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Accepting booking';
      case BookingStatus.completed:
        return 'Completing service';
      case BookingStatus.cancelled:
        return 'Cancelling booking';
      default:
        return 'Updating booking';
    }
  }

  Widget _buildBookingsTab(BookingStatus status) {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        List<BookingModel> bookings;

        switch (status) {
          case BookingStatus.pending:
            bookings = bookingProvider.providerbookings
                .where((b) => b.status == BookingStatus.pending)
                .toList();
            break;

          case BookingStatus.confirmed: // Active tab
            bookings = bookingProvider.providerbookings
                .where((b) => b.status == BookingStatus.confirmed)
                .toList();
            break;

          case BookingStatus.completed: // History tab
            bookings = bookingProvider.providerbookings
                .where(
                  (b) =>
                      b.status == BookingStatus.completed ||
                      b.status == BookingStatus.cancelled ||
                      b.status == BookingStatus.paid,
                )
                .toList();
            break;

          default:
            bookings = bookingProvider.providerbookings
                .where((b) => b.status == status)
                .toList();
        }

        // ✅ DEBUG: Log customer data status for each tab
        debugPrint('🔍 [$status] Tab has ${bookings.length} bookings:');
        for (var booking in bookings) {
          debugPrint(
            '   - ${booking.serviceName}: ${booking.customerName ?? "NO_NAME"}',
          );
        }

        if (bookings.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              if (_currentUserId != null) {
                await bookingProvider.loadProviderBookingsWithCustomerData(
                  _currentUserId!,
                );
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
                        _getEmptyStateMessage(status),
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          if (_currentUserId != null) {
                            bookingProvider
                                .loadProviderBookingsWithCustomerData(
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
              await bookingProvider.loadProviderBookingsWithCustomerData(
                _currentUserId!,
              );
            }
          },
          child: ListView.builder(
            key: PageStorageKey<String>('${status.toString()}_list'),
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];

              // ✅ SIMPLIFIED: Just build the card - no async loading needed
              return _buildBookingCard(booking);
            },
          ),
        );
      },
    );
  }

  // ✅ NEW: Helper method for empty state messages
  String _getEmptyStateMessage(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'No pending bookings';
      case BookingStatus.confirmed:
        return 'No active bookings';
      case BookingStatus.completed:
        return 'No completed bookings';
      case BookingStatus.cancelled:
        return 'No cancelled bookings';
      default:
        return 'No ${_getStatusDisplayName(status)} bookings';
    }
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
    final bool showAddress =
        (booking.status == BookingStatus.confirmed) &&
        booking.customerAddress.isNotEmpty;

    final bool shouldShowCustomerContact = _shouldShowCustomerContactInfo(
      booking.status!,
    );

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                BookingDetailForProvider(bookingId: booking.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      splashColor: AppColors.primary.withValues(alpha: 0.1),
      highlightColor: AppColors.primary.withValues(alpha: 0.05),
      child: Card(
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
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
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

                    // Customer name
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

                    // Customer phone (only show if not null and not 'No Phone')
                    if (shouldShowCustomerContact &&
                        booking.customerPhone != null &&
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
                          // Call button
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
              const SizedBox(height: 4),

              if (showAddress) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Location',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Tap to navigate',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.place,
                              size: 16,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                booking.customerAddress.isNotEmpty
                                    ? booking.customerAddress
                                    : 'Address not provided',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.directions,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 4),

              _buildDateDisplay(booking),

              const SizedBox(height: 4),

              Text(
                'Amount: ${Helpers.formatCurrency(booking.totalAmount)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),

              // Dynamic action buttons based on booking status
              _buildBookingActions(booking),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldShowCustomerContactInfo(BookingStatus status) {
    // Hide contact info for completed services and final statuses
    switch (status) {
      case BookingStatus.completed:
      case BookingStatus.paid:
      case BookingStatus.cancelled:
      case BookingStatus.refunded:
        return false; // Hide contact info
      case BookingStatus.pending:
      case BookingStatus.confirmed:
      case BookingStatus.paymentPending:
        return true; // Show contact info
      default:
        return true;
    }
  }

  Widget _buildDateDisplay(BookingModel booking) {
    String dateLabel;
    DateTime dateToShow;
    Color? dateColor;

    switch (booking.status) {
      case BookingStatus.pending:
        dateLabel = 'Scheduled Date:';
        dateToShow = booking.scheduledDateTime;
        dateColor = AppColors.textSecondary;
        break;

      case BookingStatus.confirmed:
        dateLabel = 'Scheduled Date:';
        dateToShow = booking.scheduledDateTime;
        dateColor = AppColors.primary;
        break;

      case BookingStatus.completed:
        // ✅ CRITICAL: Use the actual completion date from when it was marked complete
        dateLabel = 'Completed On:';
        dateToShow =
            booking.completedAt ?? DateTime.now(); // Use actual completion time
        dateColor = AppColors.success;
        break;

      case BookingStatus.cancelled:
        dateLabel = 'Cancelled On:';
        dateToShow = booking.completedAt ?? booking.scheduledDateTime;
        dateColor = AppColors.error;
        break;

      default:
        dateLabel = 'Date:';
        dateToShow = booking.scheduledDateTime;
        dateColor = AppColors.textSecondary;
    }

    // ✅ DEBUG: Log what date is being shown
    debugPrint(
      '🔍 [CARD] Showing ${booking.status} booking ${booking.id.substring(0, 8)}:',
    );
    debugPrint('   - Label: $dateLabel');
    debugPrint('   - Date: $dateToShow');
    debugPrint('   - CompletedAt: ${booking.completedAt}');
    debugPrint('   - ScheduledAt: ${booking.scheduledDateTime}');

    return Row(
      children: [
        Icon(
          booking.status == BookingStatus.completed
              ? Icons.check_circle_outline
              : booking.status == BookingStatus.cancelled
              ? Icons.cancel_outlined
              : Icons.schedule,
          size: 16,
          color: dateColor,
        ),
        const SizedBox(width: 8),
        Text(
          '$dateLabel ${Helpers.formatDateTime(dateToShow)}',
          style: TextStyle(
            fontSize: 14,
            color: dateColor,
            fontWeight: booking.status == BookingStatus.completed
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ],
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

      // ✅ SIMPLIFIED: Direct completion to history
      case BookingStatus.confirmed:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isProcessing
                ? null
                : () => _markServiceCompleted(booking),
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

  Future<void> _markServiceCompleted(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('Mark as Completed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: ${booking.serviceName}'),
            const SizedBox(height: 8),
            Text('Customer: ${booking.customerName ?? "Customer"}'),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to mark this service as completed?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This will move the booking to completed status and the customer can choose their payment method.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();

      final currentUserId = authProvider.getCurrentUserId();
      if (currentUserId == null) return;

      _setBookingProcessing(booking.id, true);

      try {
        // ✅ SIMPLIFIED: Direct update to completed status
        final success = await bookingProvider.updateBookingStatus(
          booking.id,
          BookingStatus.completed,
          currentUserId,
        );

        if (success && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));

          // Force refresh to ensure UI shows updated data
          setState(() {
            // This will rebuild the widget tree with fresh data
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Service marked as completed!'),
              backgroundColor: AppColors.success,
            ),
          );

          _navigateToAppropriateTab(BookingStatus.completed);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        _setBookingProcessing(booking.id, false);
      }
    }
  }

  Future<void> _updateBookingStatus(
    String bookingId,
    BookingStatus newStatus,
  ) async {
    if (!mounted || _isBookingProcessing(bookingId)) {
      debugPrint('⚠️ Update blocked - already processing');
      return;
    }

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

    debugPrint('🎯 [PROVIDER DASHBOARD] Starting status update');
    debugPrint('   - Booking ID: $bookingId');
    debugPrint('   - New Status: $newStatus');

    // ✅ CRITICAL: Set flags BEFORE any async operations
    _setBookingProcessing(bookingId, true);
    _isUpdatingStatus = true;

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text('${_getActionText(newStatus)}...'),
                  const SizedBox(height: 10),
                  const Text(
                    'Please wait while we sync the changes...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      debugPrint(
        '🔄 [STATUS UPDATE] Calling BookingProvider.updateBookingStatus',
      );

      // ✅ CRITICAL: Wait for the update to complete
      final success = await bookingProvider.updateBookingStatus(
        bookingId,
        newStatus,
        currentUserId,
      );

      debugPrint('✅ [STATUS UPDATE] BookingProvider returned: $success');

      // ✅ ENHANCED: Add extra delay to ensure Firestore consistency
      await Future.delayed(const Duration(milliseconds: 1500));

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      if (success) {
        debugPrint('✅ [PROVIDER DASHBOARD] Status updated successfully');

        // ✅ NEW: Manually refresh the specific booking to ensure consistency
        await bookingProvider.refreshSpecificBooking(bookingId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking ${_getActionText(newStatus).toLowerCase()} successfully!',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );

        // ✅ ENHANCED: Wait longer before navigating
        await Future.delayed(const Duration(milliseconds: 2500));

        if (mounted) {
          _navigateToAppropriateTab(newStatus);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update booking status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      debugPrint('❌ [PROVIDER DASHBOARD] Error: $error');

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // ✅ CRITICAL: Reset flags with additional delay
      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        _isUpdatingStatus = false;
        _setBookingProcessing(bookingId, false);
      }

      debugPrint('🏁 [STATUS UPDATE] Cleanup completed');
    }
  }

  void _navigateToAppropriateTab(BookingStatus newStatus) {
    int targetTabIndex;
    String statusName;

    switch (newStatus) {
      case BookingStatus.pending:
        targetTabIndex = 2; // Pending tab
        statusName = 'Pending';
        break;
      case BookingStatus.confirmed:
        targetTabIndex = 3; // Active tab
        statusName = 'Active';
        break;
      // ✅ REMOVED: No more inProgress case
      case BookingStatus.completed:
      case BookingStatus.cancelled:
        targetTabIndex = 4; // History tab
        statusName = 'History';
        break;
      default:
        debugPrint('⚠️ No tab navigation for status: $newStatus');
        return;
    }

    debugPrint(
      '📍 [TAB NAVIGATION] Moving to $statusName (index: $targetTabIndex)',
    );

    if (_tabController.index != targetTabIndex) {
      _tabController.animateTo(
        targetTabIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
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

        final services =
            serviceProvider.providerServices; // ✅ FIXED: Use correct getter

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
                    onTap: () {},
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
                  onPressed: _navigateToCreateService,
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
    _realTimeUpdateTimer?.cancel(); // ✅ NEW: Cancel timer
    _bookingProvider?.disposeProviderListener();
    _providerBookingsSubscription?.cancel();
    _processingBookings.clear();
    _updatingBookings.clear(); // ✅ NEW: Clear updating set
    _tabController.dispose();
    super.dispose();
  }
}
