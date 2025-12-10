import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/utils/currency.dart';
import 'package:quickfix/data/models/service_model.dart';
import 'package:quickfix/presentation/widgets/common/base_screen.dart';

class SearchScreen extends StatefulWidget {
  final List<ServiceModel> services;

  const SearchScreen({super.key, required this.services});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ServiceModel> _filteredServices = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredServices = widget.services; // Show all services initially
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredServices = widget.services;
      } else {
        _filteredServices = widget.services.where((service) {
          return service.name.toLowerCase().contains(query) ||
              service.category.toLowerCase().contains(query) ||
              service.description.toLowerCase().contains(query);
        }).toList();
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
          title: const Text('Search Services'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Search Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Search TextField
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search for services...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.primary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: AppColors.primary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Search Results Counter
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_filteredServices.length} services found',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Results
            Expanded(child: _buildSearchResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_filteredServices.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoResultsFound();
    }

    if (_filteredServices.isEmpty) {
      return _buildNoServicesAvailable();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredServices.length,
      itemBuilder: (context, index) {
        final service = _filteredServices[index];
        return _buildSearchResultCard(service);
      },
    );
  }

  Widget _buildSearchResultCard(ServiceModel service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigate to service details screen
          _navigateToServiceDetails(service);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Service Icon/Image
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(service.category),
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Service Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                service.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Currency.formatUsd(service.basePrice),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Arrow Icon
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),

              // Service Description
              if (service.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  service.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Sub-services (if any)
              if (service.subServices.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: service.subServices.take(3).map((subService) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        subService,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'No services found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try searching with different keywords\nor check your spelling',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Clear Search'),
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

  Widget _buildNoServicesAvailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No services available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'There are currently no services available in your area',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'appliance repair':
        return Icons.home_repair_service;
      case 'painting':
        return Icons.format_paint;
      case 'carpentry':
        return Icons.carpenter;
      default:
        return Icons.build;
    }
  }

  // Navigate to service details using GoRouter
  void _navigateToServiceDetails(ServiceModel service) {
    context.push(
      '/service-detail/${service.id}',
      extra: service,
    );
  }
}
