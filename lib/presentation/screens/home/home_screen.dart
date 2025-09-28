import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/constants/app_strings.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/services/location_service.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/presentation/screens/home/search_screen.dart';
import 'package:quickfix/presentation/screens/booking/service_detail_screen.dart';
import 'package:quickfix/presentation/widgets/cards/service_card.dart';
import 'package:quickfix/presentation/widgets/common/base_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.passedLocation});
  final String? passedLocation;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService.instance;
  LocationData? _currentLocation;
  bool _isRefreshing = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // ✅ SIMPLIFIED: Only load data once when page is first opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeOnce();
      }
    });
  }

  // ✅ SIMPLIFIED: Initialize only once
  Future<void> _initializeOnce() async {
    if (_hasInitialized || !mounted) return;

    //debugPrint('🚀 [HOME] Initializing for first time only');

    // await _requestPermissionIfNeeded();

    await _loadData();
    _hasInitialized = true;
  }

  // Future<void> _requestPermissionIfNeeded() async {
  //   if (!mounted) return;

  //   try {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     bool hasAskedPermission =
  //         prefs.getBool('has_asked_notification_permission') ?? false;

  //     if (!hasAskedPermission && mounted) {
  //       await NotificationPermissionHelper.requestPermissionWithDialog(context);
  //       if (mounted) {
  //         await prefs.setBool('has_asked_notification_permission', true);
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint('❌ [HOME] Permission error: $e');
  //   }
  // }

  // ✅ SIMPLIFIED: Basic data loading
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isRefreshing = true);

    try {
      final sp = context.read<ServiceProvider>();

      final loc = await _locationService.getCurrentLocation();
      if (loc != null && mounted) {
        setState(() => _currentLocation = loc);
        await sp.loadAllServices(
          userLat: loc.latitude!,
          userLng: loc.longitude!,
        );
      } else if (mounted) {
        await sp.loadAllServices(userLat: 0, userLng: 0);
      }

      //debugPrint('✅ [HOME] Data loaded successfully');
    } catch (e) {
      //debugPrint('❌ [HOME] Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // ✅ SIMPLIFIED: Manual refresh only
  Future<void> _refresh() async {
    if (_isRefreshing || !mounted) return;

    //debugPrint('🔄 [HOME] Manual refresh triggered');
    await _loadData();
  }

  // ✅ SIMPLIFIED: Navigate with refresh on return
  Future<void> _navigateWithRefreshOnReturn(String route) async {
    if (!mounted) return;

    await context.push(route);

    // ✅ Refresh when returning to this page
    if (mounted) {
      //debugPrint('🔄 [HOME] Refreshing after return from $route');
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      onScreenEnter: () {
        AdService.instance.loadInterstitial();
        AdService.instance.loadRewarded();
      },
      body: FutureBuilder(
        future: _initializeOnce(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return Scaffold(
            body: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              backgroundColor: Colors.white,
              child: Consumer<ServiceProvider>(
                builder: (context, sp, child) {
                  return CustomScrollView(
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
          );
        },
      ),
    );
  }

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
                            Row(
                              children: [
                                const Text(
                                  AppStrings.findServices,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_isRefreshing) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _quickAccessButton(
                  icon: Icons.calendar_today_outlined,
                  label: 'Bookings',
                  onTap: () =>
                      _navigateWithRefreshOnReturn('/customer-bookings'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAccessButton(
                  icon: Icons.favorite_outline,
                  label: 'Favorites',
                  onTap: () => _navigateWithRefreshOnReturn('/favorites'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickAccessButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () =>
                      _navigateWithRefreshOnReturn('/customer-settings'),
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
          // ✅ SIMPLIFIED: No refresh before search
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
        if (sp.isLoading || _isRefreshing) {
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

        return SliverList.builder(
          itemCount: services.length,
          itemBuilder: (context, index) {
            final s = services[index];
            return ServiceCard(
              service: s,
              userLatitude: _currentLocation?.latitude,
              userLongitude: _currentLocation?.longitude,
              onTap: () {
                // ✅ SIMPLIFIED: Direct navigation without refresh
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceDetailScreen(service: s),
                  ),
                ).then((_) {
                  // ✅ Optional: Refresh when returning from service detail
                  if (mounted) {
                    _loadData();
                  }
                });
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
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _loadData,
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
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _loadData,
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

  @override
  void dispose() {
    //debugPrint('🔄 [HOME] Disposing screen');
    super.dispose();
  }
}
