import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/constants/app_strings.dart';
import 'package:quickfix/core/services/location_service.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/presentation/screens/home/search_screen.dart';
import 'package:quickfix/presentation/screens/service/service_detail_screen.dart';
import 'package:quickfix/presentation/widgets/cards/service_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.passedLocation});
  final String? passedLocation;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService.instance;
  LocationData? _currentLocation;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    // Load services and providers
    final serviceProvider = context.read<ServiceProvider>();
    await serviceProvider.loadAllServices(
      userLat: _currentLocation?.latitude,
      userLng: _currentLocation?.longitude,
    );
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
              // Reduced Header Size
              _buildCompactAppBar(),

              // Quick Access Menu (improved design)
              SliverToBoxAdapter(child: _buildQuickAccessMenu()),

              // Location Banner
              SliverToBoxAdapter(child: _buildLocationBanner()),

              // Search Bar
              SliverToBoxAdapter(child: _buildSearchBar(context)),

              // Category Tabs
              SliverToBoxAdapter(child: _buildCategoryTabs()),

              // Services Grid - ✅ FIXED: Removed RefreshIndicator from here
              _buildServicesGrid(),
            ],
          ),
        ),
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
                              'Hello, ${authProvider.userModel?.name ?? 'User'}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              AppStrings.findServices,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notification Icon
                      IconButton(
                        onPressed: () => _showNotifications(context),
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      // Profile Icon
                      IconButton(
                        icon: const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 22,
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

  Widget _buildQuickAccessMenu() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
                'Quick Access',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickAccessItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Bookings',
                  onTap: () => _navigateToBookings(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickAccessItem(
                  icon: Icons.favorite_outline,
                  label: 'Favorites',
                  onTap: () => _navigateToFavorites(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickAccessItem(
                  icon: Icons.history,
                  label: 'History',
                  onTap: () => _navigateToHistory(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickAccessItem(
                  icon: Icons.help_outline,
                  label: 'Help',
                  onTap: () => _showMoreOptions(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final displayAddress =
              authProvider.userModel?.address ??
              _currentAddress ??
              'Set your location';

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
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
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

  // ✅ FIXED: Removed RefreshIndicator from this method
  Widget _buildServicesGrid() {
    return Consumer<ServiceProvider>(
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
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No services available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try selecting a different category or check back later',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return ServiceCard(
              service: services[index],
              onTap: () {
                // ✅ FIXED: Navigate to service detail
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ServiceDetailScreen(service: services[index]),
                  ),
                );
              },
              userLatitude: _currentLocation?.latitude,
              userLongitude: _currentLocation?.longitude,
            );
          }, childCount: services.length),
        );
      },
    );
  }

  // Navigation methods
  void _navigateToBookings(BuildContext context) {
    context.push('/customer-bookings');
  }

  void _navigateToFavorites(BuildContext context) {
    context.push('/favorites');
  }

  void _navigateToHistory(BuildContext context) {
    context.push('/history');
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildMoreOptionsSheet(),
    );
  }

  Widget _buildMoreOptionsSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Help & Support',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildMoreOptionItem(
            icon: Icons.help_outline,
            title: 'FAQ',
            onTap: () => Navigator.pop(context),
          ),
          _buildMoreOptionItem(
            icon: Icons.feedback_outlined,
            title: 'Feedback',
            onTap: () => Navigator.pop(context),
          ),
          _buildMoreOptionItem(
            icon: Icons.info_outline,
            title: 'About Us',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMoreOptionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showNotifications(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications feature coming soon!')),
    );
  }
}
