// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/services/otp_service.dart';
import 'package:quickfix/core/services/progress_tracking_service.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/screens/provider/analytics_screen.dart';
import 'package:quickfix/presentation/screens/provider/booking_detail_for_provider.dart';
import 'package:quickfix/presentation/screens/provider/provider_settings_screen.dart';
import 'package:quickfix/presentation/widgets/cards/provider_card.dart';
import 'package:quickfix/presentation/widgets/common/banner_ad_widget.dart';
import 'package:quickfix/presentation/widgets/common/base_screen.dart';
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

  bool _isBookingProcessing(String bookingId) =>
      _processingBookings[bookingId] ?? false;
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
    if (!authProvider.isProviderProfileComplete) {
      await ProfileCompletionDialog.show(
        context,
        'provider',
        authProvider.missingProviderFields,
      );
      return;
    }
    context.push('/create-service');
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _pageController = PageController(initialPage: widget.initialTabIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      if (_selectedIndex != _tabController.index) {
        setState(() => _selectedIndex = _tabController.index);
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
      final isAuthenticated = await authProvider.ensureUserAuthenticated();
      if (!isAuthenticated) return;
      final currentUserId = authProvider.getCurrentUserId();
      if (currentUserId == null) return;
      _currentUserId = currentUserId;
      await bookingProvider.initializeProvider(currentUserId);
      final serviceProvider = context.read<ServiceProvider>();
      await serviceProvider.loadMyServices();
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (error) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentUserId != null) {
        context.read<BookingProvider>().loadProviderBookingsWithCustomerData(
          _currentUserId!,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      onScreenEnter: () {
        AdService.instance.loadInterstitial();
        AdService.instance.loadRewarded();
      },
      body: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        body: PageView(
          controller: _pageController,
          onPageChanged: (int index) {
            setState(() {
              _selectedIndex = index;
            });
            _tabController.animateTo(index);
          },
          children: [
            _buildDashboardTab(),
            _buildBookingsTab(BookingStatus.pending),
            _buildBookingsTab(BookingStatus.confirmed),
            _buildBookingsTab(BookingStatus.completed),
            _buildMoreTab(),
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
                    color: Colors.black.withAlpha(16),
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
                onTap: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
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

                  // FIXED: Remove AnimatedSwitcher completely to avoid key conflicts
                  return Tab(
                    icon: Icon(
                      isActive ? tab['activeIcon'] : tab['icon'],
                      size: 20,
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
      ),
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
                // Welcome Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withAlpha(25),
                        AppColors.primary.withAlpha(10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withAlpha(32)),
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
                                  'Welcome...!',
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
                // Stats Grid
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
                      onTap: () => _navigateToTab(1),
                    ),
                    _buildStatCard(
                      'Active',
                      activeBookings.toString(),
                      Icons.construction,
                      Colors.blue,
                      onTap: () => _navigateToTab(2),
                    ),
                    _buildStatCard(
                      'Completed',
                      completedBookings.toString(),
                      Icons.done_all,
                      Colors.green,
                      onTap: () => _navigateToTab(3),
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
                    ),
                  ],
                ),
                // Native Ad between stats and recent bookings
                const SizedBox(height: 20),
                // const NativeAdWidget(),
                const SizedBox(height: 20),
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
                        setState(() => _selectedIndex = 1);
                        _tabController.animateTo(1);
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
                      color: Colors.grey.withAlpha(16),
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsScreen(),
                  ),
                ),
              ),
              _buildActionTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help with your account',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support coming soon!')),
                ),
              ),
              _buildActionTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Manage app preferences',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProviderSettingsScreen(),
                  ),
                ),
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
            color: AppColors.primary.withAlpha(25),
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.95,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(76),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withAlpha(51),
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
                Expanded(child: _buildSimpleServicesContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
                onServiceDeleted: _refreshServicesAfterDeletion,
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
                AppColors.primary.withAlpha(25),
                AppColors.primary.withAlpha(13),
              ],
            ),
            borderRadius: BorderRadius.circular(80),
          ),
          child: Icon(
            Icons.build_circle_outlined,
            size: 80,
            color: AppColors.primary.withAlpha(153),
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
        const Text(
          'Create your first service to start bookings from customers',
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.95,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(76),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withAlpha(51),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withAlpha(25),
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
                              '${_getStatusDisplayName(status).toUpperCase()} BOOKINGS',
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
                          backgroundColor: Colors.grey.withAlpha(25),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                    color: _getStatusColor(status).withAlpha(25),
                    borderRadius: BorderRadius.circular(80),
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    size: 80,
                    color: _getStatusColor(status).withAlpha(153),
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
                  style: const TextStyle(
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
                    setState(() => _selectedIndex = 0);
                    _tabController.animateTo(0);
                  },
                  child: const Text('Back to Dashboard'),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        }
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getStatusColor(status).withAlpha(25),
                    _getStatusColor(status).withAlpha(13),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getStatusColor(status).withAlpha(51),
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

  String _getEmptyStateSubtitle(BookingStatus status) {
    switch (status) {
      case BookingStatus.paid:
        return 'Fully paid services will appear here. Customers can pay after service completion.';
      case BookingStatus.cancelled:
        return 'Cancelled bookings will appear here. You can review cancelled services and reasons.';
      default:
        return 'Your ${_getStatusDisplayName(status)} bookings will appear here.';
    }
  }

  double _calculateStatusEarnings(List<BookingModel> bookings) {
    return bookings.fold(0.0, (total, booking) => total + booking.totalAmount);
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
          case BookingStatus.confirmed:
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
            key: PageStorageKey('${status.toString()}_list'),
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

  String _getEmptyStateMessage(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'No pending bookings';
      case BookingStatus.confirmed:
        return 'No active bookings';
      case BookingStatus.completed:
        return 'No completed bookings';
      case BookingStatus.paid:
        return 'No paid bookings';
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
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailForProvider(bookingId: booking.id),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      splashColor: AppColors.primary.withAlpha(25),
      highlightColor: AppColors.primary.withAlpha(13),
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
                      color: statusColor.withAlpha(25),
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
              _buildBookingActions(booking),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDetailsSection(BookingModel booking) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: AppColors.primary),
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
          Row(
            children: [
              const Icon(Icons.account_circle, size: 16, color: Colors.grey),
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
          if (booking.status != BookingStatus.cancelled &&
              booking.status != BookingStatus.paid &&
              booking.status != BookingStatus.refunded) ...[
            if (_hasValidCustomerPhone(booking)) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
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
        booking.customerName == null ||
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
    if (_isCustomerDataError(booking)) return Colors.orange.shade600;
    if (_hasValidCustomerData(booking)) return AppColors.textPrimary;
    return Colors.grey.shade600;
  }

  bool _hasValidCustomerData(BookingModel booking) {
    return booking.customerName != null &&
        booking.customerName!.isNotEmpty &&
        booking.customerName != 'Unknown Customer' &&
        booking.customerName != 'Loading...' &&
        booking.customerName != null &&
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
        return 'Paid';
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
        dateLabel = 'Scheduled Date: ';
        dateToShow = booking.scheduledDateTime;
        dateColor = AppColors.textSecondary;
        break;
      case BookingStatus.confirmed:
        dateLabel = 'Scheduled Date: ';
        dateToShow = booking.scheduledDateTime;
        dateColor = AppColors.primary;
        break;
      case BookingStatus.completed:
        dateLabel = 'Completed On: ';
        dateToShow = booking.completedAt ?? DateTime.now();
        dateColor = AppColors.success;
        break;
      case BookingStatus.paid:
        dateLabel = 'Paid On: ';
        dateToShow = booking.completedAt ?? DateTime.now();
        dateColor = Colors.purple;
        break;
      case BookingStatus.cancelled:
        dateLabel = 'Cancelled On: ';
        dateToShow = booking.completedAt ?? booking.scheduledDateTime;
        dateColor = AppColors.error;
        break;
      default:
        dateLabel = 'Date: ';
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
          '$dateLabel${Helpers.formatDateTime(dateToShow)}',
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
              Text('Customer: ${booking.customerName ?? 'Customer'}'),
              const SizedBox(height: 16),
              const Text(
                'Ask the customer for their 4-digit verification code',
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
                  if (errorMessage != null) setState(() => errorMessage = null);
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
                  final bookingProvider = context.read<BookingProvider>();
                  bookingProvider.lockBookingForOTP(booking.id);
                  bookingProvider.pauseRealTimeListener();

                  final success = await OTPService.instance.verifyOTP(
                    booking.id,
                    otpController.text,
                  );
                  if (success) {
                    Navigator.of(context).pop(true);
                  } else {
                    setState(
                      () => errorMessage =
                          'OTP verification failed. Check console for details.',
                    );
                    bookingProvider.unlockBookingFromOTP(booking.id);
                    bookingProvider.resumeRealTimeListener();
                  }
                } catch (e) {
                  setState(() => errorMessage = 'Verification failed: $e');
                  final bookingProvider = context.read<BookingProvider>();
                  bookingProvider.unlockBookingFromOTP(booking.id);
                  bookingProvider.resumeRealTimeListener();
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
          content: Text('OTP verified! Work started successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      await Future.delayed(const Duration(seconds: 10));
      if (_currentUserId != null && mounted) {
        final bookingProvider = context.read<BookingProvider>();
        bookingProvider.unlockBookingFromOTP(booking.id);
        bookingProvider.resumeRealTimeListener();
        await bookingProvider.loadProviderBookingsWithCustomerData(
          _currentUserId!,
        );
        bookingProvider.debugStatusAfterOTP('FINAL_OTP_CHECK');
        setState(() {});
      }
    } else {
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
            Text('Customer: ${booking.customerName ?? 'Customer'}'),
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
        final success = await bookingProvider.updateBookingStatus(
          booking.id,
          BookingStatus.completed,
          currentUserId,
        );
        if (success && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service marked as completed!'),
              backgroundColor: AppColors.success,
            ),
          );
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) _navigateToTab(3);
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
    if (!mounted || _isBookingProcessing(bookingId)) return;

    final authProvider = context.read<AuthProvider>();
    final bookingProvider = context.read<BookingProvider>();
    final currentUserId = authProvider.getCurrentUserId();
    if (currentUserId == null) return;

    _setBookingProcessing(bookingId, true);
    try {
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
                  Text(_getActionText(newStatus)),
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

      final success = await bookingProvider.updateBookingStatus(
        bookingId,
        newStatus,
        currentUserId,
      );

      if (success && newStatus == BookingStatus.confirmed) {
        try {
          await OTPService.instance.createOTPForBooking(bookingId);
          await Future.delayed(const Duration(seconds: 1));
          final verifyOTP = await OTPService.instance.getOTPForBooking(
            bookingId,
          );
          if (verifyOTP != null) {
            debugPrint('OTP verified in database: $verifyOTP');
          } else {
            debugPrint('OTP verification failed - not found in database');
          }
        } catch (e) {
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
      if (mounted) Navigator.of(context).pop();
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
        if (mounted) _navigateToAppropriateTab(newStatus);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update booking status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) _setBookingProcessing(bookingId, false);
    }
  }

  void _navigateToAppropriateTab(BookingStatus newStatus) {
    int targetTabIndex;
    switch (newStatus) {
      case BookingStatus.pending:
        targetTabIndex = 1;
        break;
      case BookingStatus.confirmed:
        targetTabIndex = 2;
        break;
      case BookingStatus.completed:
        targetTabIndex = 3;
        break;
      case BookingStatus.paid:
      case BookingStatus.cancelled:
        targetTabIndex = 4;
        break;
      default:
        return;
    }

    if (_selectedIndex != targetTabIndex) {
      setState(() => _selectedIndex = targetTabIndex);
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
        return Icons.payment;
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
      debugPrint('Error refreshing services after deletion: $error');
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
        return 'paid';
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
        final dbProgress = (data['workProgress'] ?? 0.0) as num;

        if (workStartTime == null) return const SizedBox.shrink();

        final display = _computeSyncedProgress(
          workStartTime,
          dbProgress.toDouble(),
        );

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
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
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
    final intervals = (minutes / 15);
    final stepped = 0.10 + (intervals * 0.05);
    final computed = stepped.clamp(0.0, 0.95);
    final persisted = dbProgress.isNaN ? 0.0 : dbProgress.clamp(0.0, 0.95);
    return persisted > computed ? persisted : computed;
  }

  @override
  void dispose() {
    _realTimeUpdateTimer?.cancel();
    _bookingProvider?.disposeProviderListener();
    _providerBookingsSubscription?.cancel();
    _processingBookings.clear();
    _updatingBookings.clear();
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
