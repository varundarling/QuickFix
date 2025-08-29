import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/data/models/provider_model.dart';
import 'package:quickfix/data/models/service_model.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/presentation/providers/favourites_provider.dart';
import 'package:quickfix/presentation/screens/service/service_detail_screen.dart';
import 'package:quickfix/presentation/widgets/dialogs/profile_completion_dialog.dart';

class ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final VoidCallback onTap;
  final double? userLatitude;
  final double? userLongitude;
  final bool showFavoriteButton;

  const ServiceCard({
    super.key,
    required this.service,
    required this.onTap,
    this.userLatitude,
    this.userLongitude,
    this.showFavoriteButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final distance = service.distanceFromUser(userLatitude, userLongitude);
    final currentUser = context.read<AuthProvider>().user;
    final isBookedByCurrentUser =
        service.isBooked && service.bookedByUserId == currentUser?.uid;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          // ✅ Main Card Content (with opacity if booked)
          Opacity(
            opacity: service.isBooked ? 0.6 : 1.0,
            child: _buildCardContent(context, distance),
          ),

          // ✅ Blur Effect and "BOOKED" Overlay
          if (service.isBooked) _buildBookedOverlay(isBookedByCurrentUser),
        ],
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, double? distance) {
    return Card(
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: service.isBooked
            ? null
            : () => _navigateToServiceDetail(context, service),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, AppColors.primary.withValues(alpha: 0.02)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Image Section
              _buildImageSection(),

              // Service Content Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service Name
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Service Description
                    Text(
                      service.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Location Information
                    if (service.address != null && service.address!.isNotEmpty)
                      _buildLocationInfo(distance),

                    // Sub-services
                    if (service.subServices.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSubServices(),
                    ],

                    const SizedBox(height: 16),

                    // Bottom Action Row
                    _buildActionRow(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Booked Overlay with Blur Effect
  Widget _buildBookedOverlay(bool isBookedByCurrentUser) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isBookedByCurrentUser
                          ? AppColors.success.withValues(alpha: 0.9)
                          : AppColors.error.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBookedByCurrentUser
                              ? Icons.check_circle
                              : Icons.block,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isBookedByCurrentUser ? 'BOOKED BY YOU' : 'BOOKED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (service.bookedAt != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        'Booked on ${_formatDate(service.bookedAt!)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        Container(
          height: 160,
          width: double.infinity,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: service.imageUrl.isNotEmpty
                ? Image.network(
                    service.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultImage();
                    },
                  )
                : _buildDefaultImage(),
          ),
        ),

        // Category Badge
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              service.category,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Price Badge
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.success, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.currency_rupee, size: 14, color: AppColors.success),
                Text(
                  '${service.basePrice.toInt()}',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo(double? distance) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              service.address!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (distance != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${distance.toStringAsFixed(1)} km',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubServices() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: service.subServices.take(3).map((subService) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Text(
            subService,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        // View Details / Book Button
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: service.isBooked
                  ? null
                  : () => _handleServiceTap(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: service.isBooked
                    ? Colors.grey
                    : AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    service.isBooked ? 'Not Available' : 'View Details',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!service.isBooked) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Favorites Button
        if (showFavoriteButton) const SizedBox(width: 12),

        Consumer<FavoritesProvider>(
          builder: (context, favoritesProvider, child) {
            final isFavorite = favoritesProvider.isFavorite(service.id);
            return Container(
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isFavorite ? AppColors.error : Colors.grey[300]!,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: InkWell(
                  onTap: service.isBooked
                      ? null
                      : () {
                          favoritesProvider.toggleFavorite(service);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isFavorite
                                    ? '${service.name} removed from favorites'
                                    : '${service.name} added to favorites',
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: isFavorite
                                  ? Colors.orange
                                  : AppColors.success,
                            ),
                          );
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? AppColors.error.withValues(alpha: 0.05)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? AppColors.error : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(service.category),
          size: 60,
          color: AppColors.primary.withValues(alpha: 0.6),
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

  void _handleServiceTap(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isCustomerProfileComplete) {
      await ProfileCompletionDialog.show(
        context,
        'customer',
        authProvider.missingCustomerFields,
      );
      return;
    }

    onTap();
  }

  void _navigateToServiceDetail(BuildContext context, ServiceModel service) {
    // ✅ FIXED: Fetch provider data and pass it
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FutureBuilder<ProviderModel?>(
          future: _fetchProviderForService(service.providerId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(title: Text('Loading...')),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return ServiceDetailScreen(
              service: service,
              provider: snapshot.data,
            );
          },
        ),
      ),
    );
  }

  // ✅ ADD: Method to fetch provider data
  Future<ProviderModel?> _fetchProviderForService(String providerId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();

      if (doc.exists) {
        return ProviderModel.fromFireStore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching provider: $e');
      return null;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
