import 'package:flutter/material.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/data/models/service_model.dart';
import 'package:quickfix/presentation/screens/service/service_detail_screen.dart';

class ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final VoidCallback onTap;
  final double? userLatitude;
  final double? userLongitude;

  const ServiceCard({
    super.key,
    required this.service,
    required this.onTap,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = service.isAvailableForBooking;
    final distance = service.distanceFromUser(userLatitude, userLongitude);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 3,
        shadowColor: AppColors.primary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _navigateToServiceDetail(context, service),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Image Section with enhanced overlays
                Stack(
                  children: [
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: service.imageUrl.isNotEmpty
                            ? ColorFiltered(
                                colorFilter: isAvailable
                                    ? const ColorFilter.mode(
                                        Colors.transparent,
                                        BlendMode.multiply,
                                      )
                                    : const ColorFilter.mode(
                                        Colors.grey,
                                        BlendMode.saturation,
                                      ),
                                child: Image.network(
                                  service.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildDefaultImage();
                                  },
                                ),
                              )
                            : _buildDefaultImage(),
                      ),
                    ),

                    // Category Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: AppColors.success,
                            width: 2,
                          ),
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
                            Icon(
                              Icons.currency_rupee,
                              size: 14,
                              color: AppColors.success,
                            ),
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

                    // Status Badge
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? AppColors.success.withValues(alpha: 0.9)
                              : Colors.orange.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAvailable
                                  ? Icons.check_circle
                                  : Icons.pause_circle,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAvailable ? 'Available' : 'Not Available',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Distance Badge (if available)
                    if (distance != null)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${distance.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

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
                      if (service.address != null &&
                          service.address!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: AppColors.primary,
                              ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
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
                        ),

                      // Sub-services (if any)
                      if (service.subServices.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Includes:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: service.subServices.take(3).map((
                            subService,
                          ) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
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
                        ),
                        if (service.subServices.length > 3) ...[
                          const SizedBox(height: 4),
                          Text(
                            '+${service.subServices.length - 3} more services',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 16),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: isAvailable
                              ? () => _navigateToServiceDetail(context, service)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAvailable
                                ? AppColors.primary
                                : Colors.grey,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: AppColors.primary.withValues(
                              alpha: 0.3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isAvailable ? 'View Details' : 'Not Available',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isAvailable) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 18),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  void _navigateToServiceDetail(BuildContext context, ServiceModel service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceDetailScreen(service: service),
      ),
    );
  }
}
