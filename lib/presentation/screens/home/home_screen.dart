import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/constants/app_strings.dart';
import 'package:quickfix/core/services/location_service.dart';
import 'package:quickfix/core/notifications/notification_permission_helper.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/presentation/screens/home/search_screen.dart';
import 'package:quickfix/presentation/screens/service/service_detail_screen.dart';
import 'package:quickfix/presentation/widgets/cards/service_card.dart';
import 'package:quickfix/presentation/widgets/common/banner_ad_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.passedLocation});
  final String? passedLocation;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService.instance;
  LocationData? _currentLocation;
  bool _isRefreshing = false; // ✅ NEW: Track refresh state

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
      _requestPermissionIfNeeded();
    });
  }

  Future<void> _requestPermissionIfNeeded() async {
    // Check if we should show the dialog (e.g., first time user)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasAskedPermission =
        prefs.getBool('has_asked_notification_permission') ?? false;

    if (!hasAskedPermission) {
      await NotificationPermissionHelper.requestPermissionWithDialog(context);
      await prefs.setBool('has_asked_notification_permission', true);
    }
  }

  Future<void> _init() async {
    final sp = context.read<ServiceProvider>();

    final loc = await _locationService.getCurrentLocation();
    if (loc != null && mounted) {
      setState(() => _currentLocation = loc);
      await sp.loadAllServices(userLat: loc.latitude!, userLng: loc.longitude!);
    } else {
      sp.loadAllServices(userLat: 0, userLng: 0);
    }
  }

  // ✅ ENHANCED: Better refresh handling with loading state
  Future<void> _refresh() async {
    if (_isRefreshing) return; // Prevent multiple simultaneous refreshes

    setState(() => _isRefreshing = true);

    try {
      if (_currentLocation != null) {
        await context.read<ServiceProvider>().loadAllServices(
          userLat: _currentLocation!.latitude!,
          userLng: _currentLocation!.longitude!,
        );
      } else {
        await _init();
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ✅ NEW: Ad banner above everything
          const BannerAdWidget(),

          // ✅ UPDATED: Main content with RefreshIndicator
          Expanded(
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                backgroundColor: Colors.white,
                child: Consumer<ServiceProvider>(
                  builder: (context, sp, child) {
                    return CustomScrollView(
                      // ✅ FIXED: Always allow scrolling for RefreshIndicator to work
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        _buildCompactAppBar(),
                        SliverToBoxAdapter(child: _buildQuickAccessMenu()),
                        SliverToBoxAdapter(child: _buildSearchBar(context)),
                        SliverToBoxAdapter(child: _buildCategoryTabs()),
                        _buildServicesContent(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED: Added refresh icon to app bar
  Widget _buildCompactAppBar() {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Hi, ${authProvider.userModel?.name ?? 'there'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              AppStrings.findServices,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessMenu() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Quick access',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // ✅ NEW: Quick refresh hint
              if (_isRefreshing)
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Refreshing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _quickAccessButton(
                  icon: Icons.calendar_today_outlined,
                  label: 'Bookings',
                  onTap: () => context.push('/customer-bookings'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAccessButton(
                  icon: Icons.favorite_outline,
                  label: 'Favorites',
                  onTap: () => context.push('/favorites'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAccessButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () => context.push('/customer-settings'), // ✅ UPDATED
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickAccessButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search for services…',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onTap: () {
          final sp = context.read<ServiceProvider>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchScreen(services: sp.services),
            ),
          );
        },
        readOnly: true,
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Consumer<ServiceProvider>(
        builder: (context, sp, child) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sp.categories.length,
            itemBuilder: (context, i) {
              final category = sp.categories[i];
              final isSelected = sp.selectedCategory == category;
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: FilterChip(
                  label: Text(category),
                  onSelected: (_) => sp.setSelectedCategory(category),
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  selected: isSelected,
                  showCheckmark: false,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildServicesContent() {
    return Consumer<ServiceProvider>(
      builder: (context, sp, child) {
        if (sp.isLoading) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading services...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final services = sp.getServicesByCategory();

        if (_currentLocation == null) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildLocationPrompt(),
          );
        }

        if (services.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyServicesWidget(),
          );
        }

        // ✅ UPDATED: Always use SliverList for consistent scrolling
        return SliverList.builder(
          itemCount: services.length,
          itemBuilder: (context, index) {
            final s = services[index];
            return ServiceCard(
              service: s,
              userLatitude: _currentLocation?.latitude,
              userLongitude: _currentLocation?.longitude,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceDetailScreen(service: s),
                  ),
                );
              },
              showFavoriteButton: true,
            );
          },
        );
      },
    );
  }

  Widget _buildLocationPrompt() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
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
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_searching, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Location Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Turn on location to discover amazing services near you',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // ✅ NEW: Manual refresh button in location prompt
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _refresh,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isRefreshing ? 'Checking...' : 'Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyServicesWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 50,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Services Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find any services in your area right now. Please try after sometime...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // ✅ NEW: Manual refresh button in empty state
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _refresh,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isRefreshing ? 'Refreshing...' : 'Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
