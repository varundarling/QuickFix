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
                          padding: EdgeInsetsGeometry.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  final services = serviceProvider.getServicesByCategory();
                  return SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        //Show ad every 4 times
                        if ((index + 1) % 4 == 0 &&
                            index < services.length - 1) {
                          return const AdBannerWidget();
                        }

                        final serviceIndex = index - (index ~/ 4);
                        if (serviceIndex >= services.length) return null;

                        return ServiceCard(
                          service: services[serviceIndex],
                          onTap: () {
                            //show the interstitial ad occasionally
                            if (serviceIndex % 3 == 0) {
                              _adService.showInterstitialAd();
                            }
                          },
                        );
                      }, childCount: services.length + (services.length ~/ 4)),
                    ),
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
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
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
            const Padding(
              padding: EdgeInsetsGeometry.all(16),
              child: Text(
                'Top Rated Providers Near You',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: serviceProvider.nearbyProviders.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 16),
                    child: ProviderCard(
                      provider: serviceProvider.nearbyProviders[index],
                      userLocation: _curentLocation,
                      onTap: () {
                        //naigate to provider details
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
