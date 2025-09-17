// ignore_for_file: use_build_context_synchronously, prefer_final_fields, unused_local_variable

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/services/otp_service.dart';
import 'package:quickfix/core/services/progress_tracking_service.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/screens/provider/analytics_screen.dart';
import 'package:quickfix/presentation/screens/provider/booking_detail_for_provider.dart';
import 'package:quickfix/presentation/screens/provider/provider_settings_screen.dart';
import 'package:quickfix/presentation/widgets/cards/provider_card.dart';
import 'package:quickfix/presentation/widgets/common/banner_ad_widget.dart';
import 'package:quickfix/presentation/widgets/dialogs/profile_completion_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/booking_model.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  String? _currentUserId;
  BookingProvider? _bookingProvider;
  AuthProvider? _authProvider;

  bool isLoading = true;
  StreamSubscription<QuerySnapshot>? _providerBookingsSubscription;
  Set<String> _updatingBookings = {};
  final Map<String, bool> _processingBookings = {};

  Timer? _realTimeUpdateTimer;

  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _tabs = [
    {
      'label': 'Dashboard',
      'icon': Icons.dashboard_outlined,
      'activeIcon': Icons.dashboard,
    },
    {
      'label': 'Pending',
      'status': BookingStatus.pending,
      'icon': Icons.schedule_outlined,
      'activeIcon': Icons.schedule,
    },
    {
      'label': 'Active',
      'status': BookingStatus.confirmed,
      'icon': Icons.construction_outlined,
      'activeIcon': Icons.construction,
    },
    {
      'label': 'Completed',
      'status': BookingStatus.completed,
      'icon': Icons.done_all_outlined,
      'activeIcon': Icons.done_all,
    },
    {
      'label': 'More',
      'icon': Icons.more_horiz_outlined,
      'activeIcon': Icons.more_horiz,
    },
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
    _selectedIndex = widget.initialTabIndex; // ✅ Use passed initial tab
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex, // ✅ Set initial tab
    );
    _pageController = PageController(
      initialPage: widget.initialTabIndex, // ✅ Set initial page
    );

    // ✅ CRITICAL: Sync TabController with PageController
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;

      if (_selectedIndex != _tabController.index) {
        setState(() {
          _selectedIndex = _tabController.index;
        });

        // ✅ Animate PageView to match TabController
        _pageController.animateToPage(
          _selectedIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

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
        //debugPrint('❌ User not authenticated');
        return;
      }

      // Get current user ID
      final currentUserId = authProvider.getCurrentUserId();
      if (currentUserId == null) {
        //debugPrint('❌ No user ID available');
        return;
      }

      _currentUserId = currentUserId;
      //debugPrint('✅ Initializing dashboard for provider: $currentUserId');

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

      //debugPrint('✅ Dashboard initialization completed');
    } catch (error) {
      //debugPrint('❌ Error initializing dashboard: $error');
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

    // Force refresh when returning to dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentUserId != null) {
        context.read<BookingProvider>().loadProviderBookingsWithCustomerData(
          _currentUserId!,
        );
      }
    });
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
    //debugPrint('🏗️ Building ProviderDashboardScreen');
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
              ],
            ),
          ),
        ),
      ),
      // ✅ FIXED: Use _selectedIndex instead of _tabController.index
      body: PageView(
        controller: _pageController,
        onPageChanged: (int index) {
          // ✅ CRITICAL: Update TabController when page changes via swipe
          setState(() {
            _selectedIndex = index;
          });
          _tabController.animateTo(index);
        },
        children: [
          _buildDashboardTab(), // 0: Dashboard
          _buildBookingsTab(BookingStatus.pending), // 1: Pending
          _buildBookingsTab(BookingStatus.confirmed), // 2: Active
          _buildBookingsTab(BookingStatus.completed), // 3: Completed
          _buildMoreTab(), // 4: More
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
              // ✅ ENHANCED: Handle tab tap and sync with PageView
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });

                // ✅ Animate PageView to match tab selection
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              tabs: _tabs.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, dynamic> tab = entry.value;
                bool isActive = _selectedIndex == index;

                return Tab(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isActive ? tab['activeIcon'] : tab['icon'],
                      size: 20,
                      key: ValueKey('${tab['label']}_$isActive'),
                    ),
                  ),
                  text: tab['label'],
                );
              }).toList(),
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: _navigateToCreateService,
      //   backgroundColor: AppColors.primary,
      //   icon: const Icon(Icons.add_business, color: Colors.white),
      //   label: const Text(
      //     'Create Service',
      //     style: TextStyle(color: Colors.white),
      //   ),
      // ),
    );
  }

  Widget _buildDashboardTab() {
    return Consumer2<BookingProvider, ServiceProvider>(
      builder: (context, bookingProvider, serviceProvider, child) {
        if (bookingProvider.isLoading || serviceProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading dashboard...'),
              ],
            ),
          );
        }

        final bookings = bookingProvider.providerbookings;
        final services = serviceProvider.providerServices;

        final pendingBookings = bookings
            .where((b) => b.status == BookingStatus.pending)
            .length;
        final activeBookings = bookings
            .where((b) => b.status == BookingStatus.confirmed)
            .length;
        final completedBookings = bookings
            .where((b) => b.status == BookingStatus.completed)
            .length;

        final totalEarnings = bookings
            .where(
              (b) =>
                  b.status == BookingStatus.completed ||
                  b.status == BookingStatus.paid,
            )
            .fold(0.0, (total, booking) => total + (booking.totalAmount));

        final paidEarnings = bookings
            .where((b) => b.status == BookingStatus.paid)
            .fold(0.0, (total, booking) => total + (booking.totalAmount));

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
                // Welcome Card with actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.business_center,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _navigateToCreateService,
                              icon: const Icon(Icons.create_rounded, size: 18),
                              label: const Text('Create Service'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showServicesBottomSheet(),
                              icon: const Icon(Icons.list, size: 18),
                              label: const Text('View Services'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Statistics Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    _buildStatCard(
                      'Services',
                      services.length.toString(),
                      Icons.build_circle,
                      AppColors.primary,
                      onTap: () => _showServicesBottomSheet(),
                    ),
                    _buildStatCard(
                      'Pending',
                      pendingBookings.toString(),
                      Icons.schedule,
                      Colors.orange,
                      onTap: () => _navigateToTab(
                        1,
                      ), // ✅ UPDATED: Use new navigation method
                    ),
                    _buildStatCard(
                      'Active',
                      activeBookings.toString(),
                      Icons.construction,
                      Colors.blue,
                      onTap: () => _navigateToTab(2), // ✅ UPDATED
                    ),
                    _buildStatCard(
                      'Completed',
                      completedBookings.toString(),
                      Icons.done_all,
                      Colors.green,
                      onTap: () => _navigateToTab(3), // ✅ UPDATED
                    ),
                    _buildStatCard(
                      'Total Earnings',
                      Helpers.formatCurrency(totalEarnings),
                      Icons.account_balance_wallet,
                      AppColors.primary,
                    ),
                    _buildStatCard(
                      'Paid Earnings',
                      Helpers.formatCurrency(paidEarnings),
                      Icons.payment,
                      Colors.purple,
                      onTap: () => _showMoreBottomSheet(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Recent Bookings Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Bookings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedIndex = 1;
                          _tabController.animateTo(1);
                        });
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...bookings
                    .take(3)
                    .map((booking) => _buildBookingCard(booking)),
                if (bookings.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_note_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No bookings yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
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

  void _navigateToTab(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });

      _tabController.animateTo(index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildMoreTab() {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        final bookings = bookingProvider.providerbookings;
        final paidBookings = bookings
            .where((b) => b.status == BookingStatus.paid)
            .length;
        final cancelledBookings = bookings
            .where((b) => b.status == BookingStatus.cancelled)
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Additional Options',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Status Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildStatCard(
                    'Paid Bookings',
                    paidBookings.toString(),
                    Icons.payment,
                    Colors.purple,
                    onTap: () => _showBookingsModal(BookingStatus.paid),
                  ),
                  _buildStatCard(
                    'Cancelled',
                    cancelledBookings.toString(),
                    Icons.cancel,
                    AppColors.error,
                    onTap: () => _showBookingsModal(BookingStatus.cancelled),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Additional Options
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              _buildActionTile(
                icon: Icons.analytics_outlined,
                title: 'View Analytics',
                subtitle: 'See detailed business insights',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalyticsScreen(),
                    ),
                  );
                },
              ),
              // _buildActionTile(
              //   icon: Icons.help_outline,
              //   title: 'Help & Support',
              //   subtitle: 'Get help with your account',
              //   onTap: () {
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       const SnackBar(content: Text('Support coming soon!')),
              //     );
              //   },
              // ),
              _buildActionTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Manage app preferences',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProviderSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showServicesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ✅ Critical for full height
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height:
              MediaQuery.of(context).size.height *
              0.95, // ✅ 95% of screen height
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag indicator
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'My Services',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(child: _buildSimpleServicesContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Simplified content method for Option 2
  Widget _buildSimpleServicesContent() {
    return Consumer<ServiceProvider>(
      builder: (context, serviceProvider, child) {
        if (serviceProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final services = serviceProvider.providerServices;

        if (services.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildEmptyServicesContent(),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ProviderCard(
                service: service,
                onTap: () {},
                onServiceDeleted: () => _refreshServicesAfterDeletion(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyServicesContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
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
          textAlign: TextAlign.center,
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _navigateToCreateService();
            },
            icon: const Icon(Icons.add_business, size: 20),
            label: const Text('Create Your First Service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showBookingsModal(BookingStatus status) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ✅ Enable full height
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.95, // ✅ Full height
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag indicator
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Status icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getStatusDisplayName(status).toUpperCase()} Bookings',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'All your ${_getStatusDisplayName(status)} services',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(child: _buildFullModalBookingsContent(status)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullModalBookingsContent(BookingStatus status) {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        final bookings = bookingProvider.providerbookings
            .where((b) => b.status == status)
            .toList();

        if (bookings.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 100),
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(80),
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    size: 80,
                    color: _getStatusColor(status).withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _getEmptyStateMessage(status),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _getEmptyStateSubtitle(status),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_currentUserId != null) {
                        bookingProvider.loadProviderBookingsWithCustomerData(
                          _currentUserId!,
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Refresh Bookings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getStatusColor(status),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedIndex = 0;
                      _tabController.animateTo(0);
                    });
                  },
                  child: const Text('Back to Dashboard'),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        }

        // Show bookings with summary header
        return Column(
          children: [
            // Summary container
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getStatusColor(status).withValues(alpha: 0.1),
                    _getStatusColor(status).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getStatusColor(status).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(status),
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${bookings.length} ${_getStatusDisplayName(status)} ${bookings.length == 1 ? 'booking' : 'bookings'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (status == BookingStatus.paid)
                          Text(
                            'Total: ${Helpers.formatCurrency(_calculateStatusEarnings(bookings))}',
                            style: TextStyle(
                              fontSize: 14,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          Text(
                            'All your ${_getStatusDisplayName(status)} services',
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
            // Bookings list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildBookingCard(booking),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMoreBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ✅ Enable full height
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height:
              MediaQuery.of(context).size.height *
              0.6, // ✅ 60% height for this modal
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag indicator
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.more_horiz,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'More Options',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        // Paid Bookings Option
                        Consumer<BookingProvider>(
                          builder: (context, bookingProvider, child) {
                            final paidCount = bookingProvider.providerbookings
                                .where((b) => b.status == BookingStatus.paid)
                                .length;

                            return _buildMoreOptionTile(
                              icon: Icons.payment,
                              iconColor: Colors.purple,
                              title: 'Paid Bookings',
                              subtitle: '$paidCount paid services',
                              onTap: () {
                                Navigator.pop(context);
                                _showBookingsModal(BookingStatus.paid);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        // Cancelled Bookings Option
                        Consumer<BookingProvider>(
                          builder: (context, bookingProvider, child) {
                            final cancelledCount = bookingProvider
                                .providerbookings
                                .where(
                                  (b) => b.status == BookingStatus.cancelled,
                                )
                                .length;

                            return _buildMoreOptionTile(
                              icon: Icons.cancel,
                              iconColor: Colors.red,
                              title: 'Cancelled Bookings',
                              subtitle: '$cancelledCount cancelled services',
                              onTap: () {
                                Navigator.pop(context);
                                _showBookingsModal(BookingStatus.cancelled);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        // Additional options
                        _buildMoreOptionTile(
                          icon: Icons.analytics_outlined,
                          iconColor: Colors.blue,
                          title: 'Analytics',
                          subtitle: 'View business insights',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AnalyticsScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildMoreOptionTile(
                          icon: Icons.help_outline,
                          iconColor: Colors.green,
                          title: 'Help & Support',
                          subtitle: 'Get help with your account',
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Support coming soon!'),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Colors.grey,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  // Helper method for status colors
  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.paid:
        return Colors.purple;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.completed:
        return Colors.green;
      case BookingStatus.confirmed:
        return Colors.blue;
      case BookingStatus.pending:
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  // Helper method for empty state subtitles
  String _getEmptyStateSubtitle(BookingStatus status) {
    switch (status) {
      case BookingStatus.paid:
        return 'Fully paid services will appear here.\nCustomers can pay after service completion.';
      case BookingStatus.cancelled:
        return 'Cancelled bookings will appear here.\nYou can review cancelled services and reasons.';
      default:
        return 'Your ${_getStatusDisplayName(status)} bookings will appear here.';
    }
  }

  // Helper method to calculate earnings for a status
  double _calculateStatusEarnings(List<BookingModel> bookings) {
    return bookings.fold(
      0.0,
      (total, booking) => total + (booking.totalAmount),
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

        // ✅ UPDATED: Enhanced filtering to handle all statuses
        switch (status) {
          case BookingStatus.pending:
            bookings = bookingProvider.providerbookings
                .where((b) => b.status == BookingStatus.pending)
                .toList();
            break;

          case BookingStatus.confirmed: // Active tab
            bookings = bookingProvider.providerbookings
                .where(
                  (b) =>
                      b.status == BookingStatus.confirmed ||
                      b.status == BookingStatus.inProgress,
                )
                .toList();
            break;

          case BookingStatus.completed:
            bookings = bookingProvider.providerbookings
                .where((b) => b.status == BookingStatus.completed)
                .toList();
            break;

          // ✅ NEW: Paid tab filtering
          case BookingStatus.paid:
            bookings = bookingProvider.providerbookings
                .where((b) => b.status == BookingStatus.paid)
                .toList();
            break;

          case BookingStatus.cancelled:
            bookings = bookingProvider.providerbookings
                .where((b) => b.status == BookingStatus.cancelled)
                .toList();
            break;

          default:
            bookings = bookingProvider.providerbookings
                .where((b) => b.status == status)
                .toList();
        }

        //debugPrint('🔍 [$status] Tab has ${bookings.length} bookings');

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
      case BookingStatus.paid:
        return 'No paid bookings'; // ✅ NEW
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
    Color color, {
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    final statusColor = Helpers.getStatusColor(booking.status.toString());

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
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _bookingStatusToString(booking.status),
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

              _buildCustomerDetailsSection(booking),

              const SizedBox(height: 4),

              _buildProviderNarrowProgressBar(booking),

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

  // ✅ FIXED: Enhanced customer details section in booking cards
  Widget _buildCustomerDetailsSection(BookingModel booking) {
    return Container(
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

          // ✅ ENHANCED: Customer Name with better fallback display
          Row(
            children: [
              Icon(Icons.account_circle, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDisplayCustomerName(booking),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _getCustomerNameColor(booking),
                      ),
                    ),
                    // ✅ Show refresh hint for error states
                    if (_isCustomerDataError(booking))
                      Text(
                        'Pull to refresh to reload',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // ✅ CRITICAL: Show phone for ALL non-private booking statuses
          if (booking.status != BookingStatus.cancelled &&
              booking.status != BookingStatus.paid &&
              booking.status != BookingStatus.refunded) ...[
            if (_hasValidCustomerPhone(booking)) ...[
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
                    onTap: () => Helpers.launchPhone(booking.customerPhone!),
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
            ] else ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.phone_disabled, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text(
                    'Phone not available',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            // ✅ Privacy message for finished bookings
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.privacy_tip, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(
                  'Contact details protected',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getDisplayCustomerName(BookingModel booking) {
    if (booking.customerName == null || booking.customerName!.isEmpty) {
      return 'Loading customer...';
    }

    if (booking.customerName == 'Unknown Customer' ||
        booking.customerName == 'null' ||
        booking.customerName == 'Loading...') {
      return 'Customer information unavailable';
    }

    if (booking.customerName!.startsWith('Error') ||
        booking.customerName!.startsWith('Customer Not Found')) {
      return 'Error loading customer data';
    }

    return booking.customerName!;
  }

  Color _getCustomerNameColor(BookingModel booking) {
    if (_isCustomerDataError(booking)) {
      return Colors.orange.shade600;
    }

    if (_hasValidCustomerData(booking)) {
      return AppColors.textPrimary;
    }

    return Colors.grey.shade600;
  }

  bool _hasValidCustomerData(BookingModel booking) {
    return booking.customerName != null &&
        booking.customerName!.isNotEmpty &&
        booking.customerName != 'Unknown Customer' &&
        booking.customerName != 'Loading...' &&
        booking.customerName != 'null' &&
        !booking.customerName!.startsWith('Error') &&
        !booking.customerName!.startsWith('Customer Not Found');
  }

  bool _hasValidCustomerPhone(BookingModel booking) {
    return booking.customerPhone != null &&
        booking.customerPhone!.isNotEmpty &&
        booking.customerPhone != 'No Phone' &&
        booking.customerPhone != 'Contact not available' &&
        booking.customerPhone != 'Contact unavailable' &&
        !booking.customerPhone!.startsWith('Error');
  }

  bool _isCustomerDataError(BookingModel booking) {
    return booking.customerName != null &&
        (booking.customerName!.startsWith('Error') ||
            booking.customerName!.startsWith('Customer Not Found'));
  }

  String _bookingStatusToString(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.paid:
        return 'Paid'; // ✅ NEW
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.paymentPending:
        return 'Payment Pending';
      case BookingStatus.refunded:
        return 'Refunded';
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
        dateLabel = 'Completed On:';
        dateToShow = booking.completedAt ?? DateTime.now();
        dateColor = AppColors.success;
        break;

      // ✅ NEW: Paid status date display
      case BookingStatus.paid:
        dateLabel = 'Paid On:';
        dateToShow = booking.completedAt ?? DateTime.now();
        dateColor = Colors.purple;
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

    return Row(
      children: [
        Icon(
          booking.status == BookingStatus.completed
              ? Icons.check_circle_outline
              : booking.status == BookingStatus.paid
              ? Icons.payment
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
            fontWeight:
                booking.status == BookingStatus.completed ||
                    booking.status == BookingStatus.paid
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
                : () => _showOTPVerificationDialog(booking),
            icon: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.security, size: 16),
            label: Text(isProcessing ? 'Processing...' : 'Enter Customer OTP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        );

      // ✅ FIXED: Show progress for inProgress bookings
      case BookingStatus.inProgress:
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
            label: Text(isProcessing ? 'Completing...' : 'Work Completed'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _showOTPVerificationDialog(BookingModel booking) async {
    final TextEditingController otpController = TextEditingController();
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.orange),
              SizedBox(width: 8),
              Text('Enter Customer OTP'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Service: ${booking.serviceName}'),
              Text('Customer: ${booking.customerName ?? "Customer"}'),
              const SizedBox(height: 16),
              const Text(
                'Ask the customer for their 4-digit verification code:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '1234',
                  border: const OutlineInputBorder(),
                  errorText: errorMessage,
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
                onChanged: (value) {
                  if (errorMessage != null) {
                    setState(() => errorMessage = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (otpController.text.length != 4) {
                  setState(() => errorMessage = 'Please enter 4 digits');
                  return;
                }

                try {
                  // ✅ CRITICAL: Pause real-time listener during OTP verification
                  final bookingProvider = context.read<BookingProvider>();
                  bookingProvider.lockBookingForOTP(booking.id);
                  bookingProvider.pauseRealTimeListener();

                  // debugPrint(
                  //   '🔐 [DASHBOARD] Starting OTP verification process',
                  // );

                  // Verify OTP and start work
                  final success = await OTPService.instance.verifyOTP(
                    booking.id,
                    otpController.text,
                  );

                  if (success) {
                    //debugPrint('✅ [DASHBOARD] OTP verification succeeded');
                    Navigator.of(context).pop(true);
                  } else {
                    //debugPrint('❌ [DASHBOARD] OTP verification failed');
                    setState(
                      () => errorMessage =
                          'OTP verification failed. Check console for details.',
                    );

                    // Resume listener on failure
                    bookingProvider.unlockBookingFromOTP(booking.id);
                    bookingProvider.resumeRealTimeListener();
                  }
                } catch (e) {
                  //debugPrint('❌ [DASHBOARD] OTP verification error: $e');
                  setState(() => errorMessage = 'Verification failed: $e');

                  // Resume listener on error
                  context.read<BookingProvider>().unlockBookingFromOTP(
                    booking.id,
                  );
                  context.read<BookingProvider>().resumeRealTimeListener();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Start Work'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ OTP verified! Work started successfully.'),
          backgroundColor: AppColors.success,
        ),
      );

      // ✅ CRITICAL: Wait longer and then resume listener
      await Future.delayed(const Duration(seconds: 10));

      if (_currentUserId != null && mounted) {
        final bookingProvider = context.read<BookingProvider>();

        // Resume real-time listener
        bookingProvider.unlockBookingFromOTP(booking.id);
        bookingProvider.resumeRealTimeListener();

        // Force refresh to get latest data
        await bookingProvider.loadProviderBookingsWithCustomerData(
          _currentUserId!,
        );

        // Debug status
        bookingProvider.debugStatusAfterOTP('FINAL_OTP_CHECK');

        setState(() {});

        //debugPrint('✅ [DASHBOARD] OTP verification process completed');
      }
    } else {
      // Resume listener if dialog was cancelled
      if (mounted) {
        final bookingProvider = context.read<BookingProvider>();
        bookingProvider.unlockBookingFromOTP(booking.id);
        bookingProvider.resumeRealTimeListener();
      }
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
        await ProgressTrackingService.instance.completeWork(booking.id);
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

          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              _navigateToTab(3); // Completed tab is index 3
            }
          });
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
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final bookingProvider = context.read<BookingProvider>();

    final currentUserId = authProvider.getCurrentUserId();
    if (currentUserId == null) return;

    _setBookingProcessing(bookingId, true);

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

      // Update booking status
      final success = await bookingProvider.updateBookingStatus(
        bookingId,
        newStatus,
        currentUserId,
      );

      // ✅ CRITICAL: Generate OTP when accepting booking
      if (success && newStatus == BookingStatus.confirmed) {
        try {
          //debugPrint('🔑 Generating OTP for booking: $bookingId');
          await OTPService.instance.createOTPForBooking(bookingId);
          //debugPrint('✅ OTP generated successfully: $otpCode');

          // ✅ Verify OTP was actually created
          await Future.delayed(const Duration(seconds: 1));
          final verifyOTP = await OTPService.instance.getOTPForBooking(
            bookingId,
          );
          if (verifyOTP != null) {
            //debugPrint('✅ OTP verified in database: $verifyOTP');
          } else {
            //debugPrint('❌ OTP verification failed - not found in database');
          }
        } catch (e) {
          //debugPrint('❌ Error generating OTP: $e');
          // Show error but don't fail the booking acceptance
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Booking accepted but OTP generation failed: $e'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 1500));

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == BookingStatus.confirmed
                  ? 'Booking accepted! OTP generated for customer.'
                  : 'Booking ${_getActionText(newStatus).toLowerCase()} successfully!',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );

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
      //debugPrint('❌ Error: $error');

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        _setBookingProcessing(bookingId, false);
      }
    }
  }

  void _navigateToAppropriateTab(BookingStatus newStatus) {
    int targetTabIndex;
    String statusName;

    switch (newStatus) {
      case BookingStatus.pending:
        targetTabIndex = 1; // Pending tab
        statusName = 'Pending';
        break;
      case BookingStatus.confirmed:
        targetTabIndex = 2; // Active tab
        statusName = 'Active';
        break;
      case BookingStatus.completed:
        targetTabIndex = 3; // Completed tab
        statusName = 'Completed';
        break;
      case BookingStatus.paid:
      case BookingStatus.cancelled:
        targetTabIndex = 4; // More tab
        statusName = 'More';
        break;
      default:
        //debugPrint('⚠️ No tab navigation for status: $newStatus');
        return;
    }

    // debugPrint(
    //   '📍 [TAB NAVIGATION] Moving to $statusName (index: $targetTabIndex)',
    // );

    if (_selectedIndex != targetTabIndex) {
      setState(() {
        _selectedIndex = targetTabIndex;
      });

      // ✅ Animate both controllers
      _tabController.animateTo(targetTabIndex);
      _pageController.animateToPage(
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
        return Icons.construction;
      case BookingStatus.completed:
        return Icons.done_all;
      case BookingStatus.paid:
        return Icons.payment; // ✅ NEW
      case BookingStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Future<void> _refreshServicesAfterDeletion() async {
    if (!mounted) return;

    try {
      final serviceProvider = context.read<ServiceProvider>();
      await serviceProvider.loadMyServices();
    } catch (error) {
      //debugPrint('❌ Error refreshing services after deletion: $error');
    }
  }

  String _getStatusDisplayName(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'pending';
      case BookingStatus.confirmed:
        return 'confirmed';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.paid:
        return 'paid'; // ✅ NEW
      case BookingStatus.cancelled:
        return 'cancelled';
      default:
        return 'unknown';
    }
  }

  Widget _buildProviderNarrowProgressBar(BookingModel booking) {
    if (booking.status != BookingStatus.inProgress ||
        !booking.isWorkInProgress) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(booking.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final isWorkInProgress = data['isWorkInProgress'] as bool? ?? false;
        if (!isWorkInProgress) return const SizedBox.shrink();

        final workStartTs = data['workStartTime'] as Timestamp?;
        final workStartTime = workStartTs?.toDate();
        final dbProgress = ((data['workProgress'] ?? 0.0) as num).toDouble();

        if (workStartTime == null) return const SizedBox.shrink();

        final display = _computeSyncedProgress(workStartTime, dbProgress);

        return Container(
          margin: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.work, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    'Work Progress - ${(display * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: display,
                  minHeight: 4,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _computeSyncedProgress(DateTime workStartTime, double dbProgress) {
    final minutes = DateTime.now().difference(workStartTime).inMinutes;
    final intervals = minutes ~/ 15; // one step every 15 minutes
    final stepped = 0.10 + (intervals * 0.05); // base 10% + 5% per step
    final computed = stepped.clamp(0.0, 0.95);
    final persisted = (dbProgress.isNaN ? 0.0 : dbProgress).clamp(0.0, 0.95);
    return persisted > computed ? persisted : computed;
  }

  @override
  void dispose() {
    _realTimeUpdateTimer?.cancel(); // ✅ NEW: Cancel timer
    _bookingProvider?.disposeProviderListener();
    _providerBookingsSubscription?.cancel();
    _processingBookings.clear();
    _updatingBookings.clear(); // ✅ NEW: Clear updating set
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
