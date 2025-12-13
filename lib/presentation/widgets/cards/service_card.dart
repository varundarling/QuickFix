import 'dart:ui';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/utils/currency.dart';
import 'package:quickfix/data/models/service_model.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/presentation/providers/favourites_provider.dart';
import 'package:quickfix/presentation/widgets/dialogs/profile_completion_dialog.dart';

class ServiceCard extends StatefulWidget {
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
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Real-time rating fields
  StreamSubscription<DocumentSnapshot>? _providerRatingSub;
  StreamSubscription<DocumentSnapshot>? _serviceRatingSub; // fallback
  double? _currentRating;
  int? _totalReviews;
  bool _isLoadingRating = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Seed from ServiceModel for instant paint (if present)
    _currentRating = widget.service.providerRating;
    _totalReviews = widget.service.providerTotalReviews;
    _isLoadingRating = false; // we’ll immediately start streams below

    _setupProviderRatingListener(); // primary source: providers/{providerId}
    _setupServiceFallbackListener(); // fallback: services/{serviceId}
  }

  void _setupProviderRatingListener() {
    // Read exactly what analytics screen updates: providers.rating + providers.totalReviews
    _providerRatingSub = FirebaseFirestore.instance
        .collection('providers')
        .doc(widget.service.providerId)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            if (!snap.exists || snap.data() == null) return;

            final data = snap.data() as Map<String, dynamic>;
            final r = _parseRating(
              data['rating'] ?? data['raitng'],
            ); // accept legacy key
            final c = _parseReviews(data['totalReviews']);

            // Prefer provider analytics if present
            if (r != null && c != null) {
              setState(() {
                _currentRating = r;
                _totalReviews = c;
                _isLoadingRating = false;
              });
            }
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _isLoadingRating = false);
          },
        );
  }

  void _setupServiceFallbackListener() {
    // Fallback to denormalized fields on service doc if provider doc unavailable
    _serviceRatingSub = FirebaseFirestore.instance
        .collection('services')
        .doc(widget.service.id)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            if (!snap.exists || snap.data() == null) return;

            final data = snap.data() as Map<String, dynamic>;
            final r = _parseRating(
              data['providerRating'] ??
                  data['rating'] ??
                  data['averageRating'] ??
                  data['raitng'] ??
                  data['serviceRating'],
            );
            final c = _parseReviews(
              data['providerTotalReviews'] ??
                  data['totalReviews'] ??
                  data['reviewCount'] ??
                  data['totalReviewCount'] ??
                  data['numReviews'],
            );

            // Only apply fallback if provider values are missing
            if ((_totalReviews == null || _totalReviews == 0) && c != null) {
              setState(() {
                _currentRating = r ?? _currentRating;
                _totalReviews = c;
                _isLoadingRating = false;
              });
            }
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _isLoadingRating = false);
          },
        );
  }

  double? _parseRating(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseReviews(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  void dispose() {
    _providerRatingSub?.cancel();
    _serviceRatingSub?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.service.isBooked) {
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _handleTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final distance = widget.service.distanceFromUser(
      widget.userLatitude,
      widget.userLongitude,
    );
    final currentUser = context.read<AuthProvider>().user;
    final isBookedByCurrentUser =
        widget.service.isBooked &&
        widget.service.bookedByUserId == currentUser?.uid;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Stack(
              children: [
                Opacity(
                  opacity: widget.service.isBooked ? 0.7 : 1.0,
                  child: _buildCardContent(context, distance),
                ),
                if (widget.service.isBooked)
                  _buildBookedOverlay(isBookedByCurrentUser),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardContent(BuildContext context, double? distance) {
    return Card(
      elevation: 12,
      shadowColor: AppColors.primary.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.service.isBooked
            ? null
            : () => _handleServiceTap(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                AppColors.primary.withValues(alpha: 0.02),
                Colors.white,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildServiceHeader(),
                    const SizedBox(height: 16),
                    _buildDescription(),
                    const SizedBox(height: 16),
                    // if (widget.service.address != null &&
                    //     widget.service.address!.isNotEmpty)
                    //   _buildLocationInfo(distance),
                    if (widget.service.subServices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSubServices(),
                    ],
                    const SizedBox(height: 24),
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

  Widget _buildImageSection() {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              width: double.infinity,
              height: 200,
              child: widget.service.imageUrl.isNotEmpty
                  ? Image.network(
                      widget.service.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _buildDefaultImage();
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          _buildDefaultImage(),
                    )
                  : _buildDefaultImage(),
            ),
          ),
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.3),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_buildCategoryBadge(), _buildPriceBadge()],
            ),
          ),
          Positioned(bottom: 16, left: 16, child: _buildStatusBadge()),
          Positioned(bottom: 16, right: 16, child: _buildRatingBadge()),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getCategoryIcon(widget.service.category),
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            widget.service.category,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_money, size: 18, color: AppColors.success),
          Text(
            Currency.formatUsd(widget.service.basePrice),
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.service.isActive ? AppColors.success : Colors.orange,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (widget.service.isActive ? AppColors.success : Colors.orange)
                .withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.service.isActive ? Icons.check_circle : Icons.pause_circle,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            widget.service.isActive ? 'Available' : 'Paused',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Rating badge shows provider analytics; “New” only when totalReviews == 0
  Widget _buildRatingBadge() {
    if (_isLoadingRating) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.grey, Colors.grey.shade600]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 4),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final count = _totalReviews ?? 0;
    final hasReviews = count > 0;
    final rating = (_currentRating ?? 0.0);

    final gradientColors = hasReviews
        ? [Colors.amber, Colors.amber.shade600]
        : [Colors.grey.shade400, Colors.grey.shade600];
    final shadowColor = hasReviews
        ? Colors.amber.withValues(alpha: 0.4)
        : Colors.grey.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasReviews ? Icons.star : Icons.star_outline,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            hasReviews ? rating.toStringAsFixed(1) : 'New',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (hasReviews) ...[
            const SizedBox(width: 2),
            Text(
              '($count)',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.service.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Professional Service',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.description, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.service.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Widget _buildLocationInfo(double? distance) {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       gradient: LinearGradient(
  //         colors: [
  //           AppColors.primary.withValues(alpha: 0.1),
  //           AppColors.primary.withValues(alpha: 0.05),
  //         ],
  //       ),
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
  //     ),
  //     child: Row(
  //       children: [
  //         Container(
  //           padding: const EdgeInsets.all(8),
  //           decoration: const BoxDecoration(
  //             color: AppColors.primary,
  //             borderRadius: BorderRadius.all(Radius.circular(12)),
  //           ),
  //           child: const Icon(Icons.location_on, size: 18, color: Colors.white),
  //         ),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 'Service Location',
  //                 style: TextStyle(
  //                   fontSize: 12,
  //                   color: AppColors.primary,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //               const SizedBox(height: 2),
  //               Text(
  //                 widget.service.address ?? '',
  //                 style: const TextStyle(
  //                   fontSize: 14,
  //                   color: AppColors.textPrimary,
  //                   fontWeight: FontWeight.w500,
  //                 ),
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //             ],
  //           ),
  //         ),
  //         if (distance != null) ...[
  //           const SizedBox(width: 12),
  //           Container(
  //             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //             decoration: const BoxDecoration(
  //               color: AppColors.primary,
  //               borderRadius: BorderRadius.all(Radius.circular(16)),
  //             ),
  //             child: Text(
  //               '${distance.toStringAsFixed(1)} km',
  //               style: const TextStyle(
  //                 fontSize: 12,
  //                 fontWeight: FontWeight.w600,
  //                 color: Colors.white,
  //               ),
  //             ),
  //           ),
  //         ],
  //       ],
  //     ),
  //   );
  // }

  Widget _buildSubServices() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Services Included',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.service.subServices.take(6).map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
          if (widget.service.subServices.length > 6) ...[
            const SizedBox(height: 8),
            Text(
              '+${widget.service.subServices.length - 6} more services',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: widget.service.isBooked
                  ? LinearGradient(colors: [Colors.grey, Colors.grey.shade600])
                  : LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: widget.service.isBooked
                  ? []
                  : [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: ElevatedButton(
              onPressed: widget.service.isBooked
                  ? null
                  : () => _handleServiceTap(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.service.isBooked ? Icons.block : Icons.visibility,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.service.isBooked ? 'Not Available' : 'View Details',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.showFavoriteButton) const SizedBox(width: 16),
        if (widget.showFavoriteButton)
          Consumer<FavoritesProvider>(
            builder: (context, favoritesProvider, child) {
              final isFavorite = favoritesProvider.isFavorite(
                widget.service.id,
              );
              return Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: isFavorite
                      ? LinearGradient(
                          colors: [
                            AppColors.error,
                            AppColors.error.withValues(alpha: 0.8),
                          ],
                        )
                      : LinearGradient(
                          colors: [Colors.grey.shade100, Colors.grey.shade200],
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFavorite ? AppColors.error : Colors.grey.shade300,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isFavorite ? AppColors.error : Colors.grey)
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: widget.service.isBooked
                      ? null
                      : () {
                          favoritesProvider.toggleFavorite(widget.service);
                          _showFavoriteSnackbar(context, isFavorite);
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.white : Colors.grey.shade600,
                      size: 24,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBookedOverlay(bool isBookedByCurrentUser) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isBookedByCurrentUser
                            ? [
                                AppColors.success,
                                AppColors.success.withValues(alpha: 0.8),
                              ]
                            : [
                                AppColors.error,
                                AppColors.error.withValues(alpha: 0.8),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isBookedByCurrentUser
                              ? Icons.check_circle
                              : Icons.block,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isBookedByCurrentUser
                              ? 'BOOKED BY YOU'
                              : 'SERVICE BOOKED',
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
                  if (widget.service.bookedAt != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Booked on ${_formatDate(widget.service.bookedAt!)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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
          _getCategoryIcon(widget.service.category),
          size: 80,
          color: AppColors.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  void _showFavoriteSnackbar(BuildContext context, bool wasAlreadyFavorite) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              wasAlreadyFavorite ? Icons.favorite_border : Icons.favorite,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                wasAlreadyFavorite
                    ? '${widget.service.name} removed from favorites'
                    : '${widget.service.name} added to favorites',
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: wasAlreadyFavorite ? Colors.orange : AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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

    widget.onTap();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
