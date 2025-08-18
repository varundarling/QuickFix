// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/constants/app_strings.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/services/location_service.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/presentation/screens/home/search_screen.dart';
import 'package:quickfix/presentation/widgets/common/ad_banner_widget.dart';
import 'package:quickfix/presentation/widgets/cards/provider_card.dart';
import '../../widgets/cards/service_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.passedLocation});

  final String? passedLocation;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService.instance;
  final AdService _adService = AdService.instance;
  LocationData? _curentLocation;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
      _loadAds();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkQueryParameters();
  }

  void _checkQueryParameters() {
    // ✅ Get query parameters from go_router
    final router = GoRouter.of(context);
    final location = router.routeInformationProvider.value.location;
    final uri = Uri.parse(location);
    final locationParam = uri.queryParameters['location'];

    debugPrint('🔍 Query parameter location: $locationParam');

    if (locationParam != null && locationParam != _currentAddress) {
      setState(() {
        _currentAddress = Uri.decodeComponent(locationParam);
      });
      debugPrint('✅ Location updated: $_currentAddress');
    }
  }

  Future<void> _initializeScreen() async {
    //Load current location
    _curentLocation = await _locationService.getCurrentLocation();
    if (_curentLocation != null) {
      _currentAddress = await _locationService.getAddressFromCoordinates(
        _curentLocation!.latitude!,
        _curentLocation!.longitude!,
      );
      setState(() {});
    }

    //Load Service and providers
    final serviceProvider = context.read<ServiceProvider>();
    // Load all services with location filtering for customers
    await serviceProvider.loadAllServices(
      userLat: _curentLocation?.latitude,
      userLng: _curentLocation?.longitude,
    );

    // Load providers
    await serviceProvider.loadProviders(
      userLat: _curentLocation?.latitude,
      userLng: _curentLocation?.longitude,
    );
  }

  void _loadAds() {
    _adService.loadBannerAd();
    _adService.loadInterstitialAd();
    _adService.loadRewardedAd();
  }

  @override
  void dispose() {
    _adService.disposeBannerAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _initializeScreen,
          child: CustomScrollView(
            slivers: [
              //custom App bar
              _buildCustomAppBar(),

              //Location Banner
              SliverToBoxAdapter(child: _buildLocationBanner()),

              //search Bar
              SliverToBoxAdapter(child: _buildSearchBar(context)),

              //Category tabs
              SliverToBoxAdapter(child: _buildCategoryTabs()),

              //Services Grid
              Consumer<ServiceProvider>(
                builder: (context, serviceProvider, child) {
                  if (serviceProvider.isLoading) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  final services = serviceProvider.getServicesByCategory();

                  // Show message if no services
                  if (services.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No services available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try selecting a different category or check back later',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Use SliverList for full-width cards instead of SliverGrid
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      // Show ad every 3 services
                      if ((index + 1) % 4 == 0 && index < services.length - 1) {
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: const AdBannerWidget(),
                        );
                      }

                      final serviceIndex = index - (index ~/ 4);
                      if (serviceIndex >= services.length) return null;

                      return ServiceCard(
                        service: services[serviceIndex],
                        onTap: () {
                          // Show interstitial ad occasionally
                          if (serviceIndex % 3 == 0) {
                            _adService.showInterstitialAd();
                          }

                          // Navigate to service booking screen
                          // context.push('/book-service/${services[serviceIndex].id}');
                        },
                      );
                    }, childCount: services.length + (services.length ~/ 4)),
                  );
                },
              ),
              //nearby providers section
              SliverToBoxAdapter(child: _buildNearByProvidersSection()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                              'Hello, ${authProvider.userModel?.name ?? 'User'}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              AppStrings.findServices,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.notifications_outlined),
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                        ),
                        onPressed: () => context.push('/profile'),
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

  Widget _buildLocationBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          debugPrint(
            '🏗️ Consumer called with address: ${authProvider.userModel?.address}',
          );

          // ✅ Get route arguments for passed location
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          final passedLocation = args?['location'] as String?;

          // ✅ Priority order: passed location > provider address > current address > default
          final displayAddress =
              passedLocation ??
              authProvider.userModel?.address ??
              _currentAddress ??
              'Set your location';

          debugPrint('🏗️ Final display address: $displayAddress');

          return Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Location',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // TextButton(
              //   onPressed: () =>
              //       LocationService.showLocationChangeOptions(context),
              //   child: const Row(
              //     mainAxisSize: MainAxisSize.min,
              //     children: [
              //       Icon(Icons.edit_location, size: 16),
              //       SizedBox(width: 4),
              //       Text(
              //         'Change',
              //         style: TextStyle(
              //           fontSize: 12,
              //           fontWeight: FontWeight.w600,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search for services...',
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
          // Navigate to search screen with available services
          final serviceProvider = context.read<ServiceProvider>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SearchScreen(services: serviceProvider.services),
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
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Consumer<ServiceProvider>(
        builder: (context, serviceProvider, child) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: serviceProvider.categories.length,
            itemBuilder: (context, index) {
              final category = serviceProvider.categories[index];
              final isSelected = serviceProvider.selectedCategory == category;

              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: FilterChip(
                  label: Text(category),
                  onSelected: (_) {
                    serviceProvider.setSelectedCategory(category);
                  },
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNearByProvidersSection() {
    return Consumer<ServiceProvider>(
      builder: (context, serviceProvider, child) {
        if (serviceProvider.nearbyProviders.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Top Rated Providers Near You',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Provider Cards (Full Width)
            ...serviceProvider.nearbyProviders.take(3).map((provider) {
              return ProviderCard(
                provider: provider,
                userLocation: _curentLocation,
                onTap: () {
                  // Navigate to provider details
                  context.push('/provider-details/${provider.id}');
                },
              );
            }),

            // View All Button (if more than 3 providers)
            if (serviceProvider.nearbyProviders.length > 3)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Navigate to all providers screen
                    context.push('/all-providers');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View All ${serviceProvider.nearbyProviders.length} Providers',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
