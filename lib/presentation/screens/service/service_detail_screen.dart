// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/data/models/service_model.dart';
import 'package:quickfix/data/models/provider_model.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ServiceModel service;
  final ProviderModel? provider;

  const ServiceDetailScreen({super.key, required this.service, this.provider});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  bool _isBooking = false;
  ProviderModel? _provider;
  bool _isLoadingProvider = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();

    // Debug authentication
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('=== AUTH VERIFICATION ===');
    debugPrint('User ID: ${user?.uid}');
    debugPrint('Email: ${user?.email}');
    debugPrint('Is Authenticated: ${user != null}');
    debugPrint('========================');

    _provider = widget.provider;

    // If provider not passed, fetch it
    if (_provider == null) {
      debugPrint('🔄 Provider not passed, fetching from Firestore...');
      _fetchProviderData();
    } else {
      debugPrint('✅ Provider passed from parent: ${_provider!.businessName}');
    }

    // Load bookings for this service
    _loadBookingData();

    // Debug initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  Future<void> _fetchProviderData() async {
    if (widget.service.providerId.isEmpty) {
      debugPrint('❌ No provider ID provided');
      return;
    }

    setState(() {
      _isLoadingProvider = true;
    });

    try {
      debugPrint('🔄 Fetching provider data for: ${widget.service.providerId}');

      // ✅ FIRST: Try to get from providers collection
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.service.providerId)
          .get();

      if (providerDoc.exists && providerDoc.data() != null) {
        final providerModel = ProviderModel.fromFireStore(providerDoc);
        debugPrint(
          '✅ Provider found in providers collection: ${providerModel.businessName}',
        );

        if (mounted) {
          setState(() {
            _provider = providerModel;
            _isLoadingProvider = false;
          });
        }
        return;
      }

      // ✅ FALLBACK: If not found in providers collection, get from user data
      debugPrint(
        '⚠️ Provider not found in providers collection, checking user data...',
      );
      final userDoc = await FirebaseDatabase.instance
          .ref('users')
          .child(widget.service.providerId)
          .get();

      if (userDoc.exists && userDoc.value != null) {
        final userData = Map<String, dynamic>.from(userDoc.value as Map);
        debugPrint('✅ User data found: ${userData['name']}');

        // Create a temporary provider model from user data and service data
        final tempProvider = ProviderModel(
          id: widget.service.providerId,
          userId: widget.service.providerId,
          businessName:
              userData['businessName'] ??
              userData['name'] ??
              'Service Provider',
          description:
              userData['description'] ?? 'Professional service provider',
          services: [],
          raitng: 0.0,
          totalReviews: 0,
          certifications: [],
          latitude: widget.service.latitude ?? 0.0,
          longitude: widget.service.longitude ?? 0.0,
          address: widget.service.address ?? userData['address'] ?? '',
          availability: {},
          isVerified: false,
          isActive: true,
          createdAt: DateTime.now(),
          portfolioImages: [],
          mobileNumber: widget.service.mobileNumber,
          experience: userData['experience'] ?? '1+ years',
        );

        if (mounted) {
          setState(() {
            _provider = tempProvider;
            _isLoadingProvider = false;
          });
          debugPrint('✅ Temporary provider model created');
        }
        return;
      }

      debugPrint('❌ No provider data found anywhere');
      if (mounted) {
        setState(() {
          _provider = null;
          _isLoadingProvider = false;
        });
      } else {
        debugPrint('❌ Provider document does not exist or has no data');
        if (mounted) {
          setState(() {
            _provider = null;
            _isLoadingProvider = false;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching provider: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _provider = null;
          _isLoadingProvider = false;
        });

        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load provider details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadBookingData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingProvider = context.read<BookingProvider>();
      bookingProvider.loadServiceBookings(widget.service.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ✅ FIXED: Use regular AppBar, not inside CustomScrollView
      appBar: AppBar(
        title: const Text('Service Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              debugPrint('🔄 Manual refresh triggered');
              _fetchProviderData();
              _loadBookingData();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ✅ Service Image Header as SliverAppBar
          SliverAppBar(
            expandedHeight: 250,
            pinned: false,
            backgroundColor: AppColors.primary,
            automaticallyImplyLeading:
                false, // Remove back button since we have one in main AppBar
            flexibleSpace: FlexibleSpaceBar(background: _buildHeaderImage()),
          ),

          // ✅ CRITICAL FIX: Wrap all content in SliverToBoxAdapter
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Header
                  _buildServiceHeader(),
                  const SizedBox(height: 24),

                  // Provider Details Section
                  _buildProviderSection(),
                  const SizedBox(height: 24),

                  // Contact Information
                  _buildContactSection(),
                  const SizedBox(height: 24),

                  // Booking Details Section (for existing bookings)
                  _buildBookingDetailsSection(),

                  // Service Description
                  _buildServiceDescription(),
                  const SizedBox(height: 24),

                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      title: Text(
                        _selectedDate == null
                            ? 'Select desired date & time'
                            : 'Selected: ${Helpers.formatDateTime(_selectedDate!)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      trailing: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.event,
                          color: Colors.blue,
                          size: 28,
                        ),
                      ),
                      onTap: () async {
                        // Pick Date
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate:
                              _selectedDate ??
                              DateTime.now().add(const Duration(hours: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );

                        if (pickedDate != null) {
                          // Pick Time
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              _selectedDate ?? DateTime.now(),
                            ),
                          );

                          if (pickedTime != null) {
                            final selectedDateTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );

                            setState(() {
                              _selectedDate = selectedDateTime;
                            });
                          } else {
                            // User canceled time picker, still update date only with zero time or keep existing time
                            setState(() {
                              _selectedDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                _selectedDate?.hour ?? 0,
                                _selectedDate?.minute ?? 0,
                              );
                            });
                          }
                        }
                      },
                    ),
                  ),

                  // // Sub-services
                  // if (widget.service.subServices.isNotEmpty) ...[
                  //   _buildSubServices(),
                  //   const SizedBox(height: 24),
                  // ],

                  // Book Service Button
                  _buildBookServiceButton(context),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Service Image
        widget.service.imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.service.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => _buildDefaultHeader(),
              )
            : _buildDefaultHeader(),

        // Gradient Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
            ),
          ),
        ),

        // Price Badge
        Positioned(
          top: 100,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.currency_rupee, color: Colors.white, size: 18),
                Text(
                  '${widget.service.basePrice.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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

  Widget _buildDefaultHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCategoryIcon(widget.service.category),
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            widget.service.category,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.service.category,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.service.isAvailableForBooking
                        ? AppColors.success.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.service.isAvailableForBooking
                            ? Icons.check_circle
                            : Icons.pause_circle,
                        size: 14,
                        color: widget.service.isAvailableForBooking
                            ? AppColors.success
                            : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.service.isAvailableForBooking
                            ? 'Available'
                            : 'Not Available',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.service.isAvailableForBooking
                              ? AppColors.success
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.service.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Starting from ',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Icon(Icons.currency_rupee, size: 18, color: AppColors.success),
                Text(
                  '${widget.service.basePrice.toInt()}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  ' / service',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSection() {
    // Use ValueKey to force rebuild when provider data changes
    return Card(
      key: ValueKey('provider_${_provider?.id ?? 'null'}_$_isLoadingProvider'),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildProviderContent(),
      ),
    );
  }

  Widget _buildProviderContent() {
    // Loading State
    if (_isLoadingProvider) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading provider details...',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      );
    }

    // No Provider State
    if (_provider == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business_center, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            'Provider Information Not Available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _fetchProviderData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    // Provider Data Available
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Service Provider',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Provider Info Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary,
              child: Text(
                _provider!.businessName.isNotEmpty
                    ? _provider!.businessName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Provider Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business Name
                  Text(
                    _provider!.businessName.isNotEmpty
                        ? _provider!.businessName
                        : 'Service Provider',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  // Experience
                  if (_provider!.experience?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.work_history,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Experience: ${_provider!.experience}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],

                  // // Address with Maps Integration
                  // if (_provider!.address.isNotEmpty) ...[
                  //   const SizedBox(height: 4),
                  //   Row(
                  //     children: [
                  //       Icon(Icons.location_on, size: 14, color: Colors.grey),
                  //       const SizedBox(width: 4),
                  //       Expanded(
                  //         child: Text(
                  //           _provider!.address,
                  //           style: TextStyle(fontSize: 12, color: Colors.grey),
                  //           maxLines: 2,
                  //           overflow: TextOverflow.ellipsis,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ],

                  // // Rating
                  // const SizedBox(height: 8),
                  // Row(
                  //   children: [
                  //     RatingBarIndicator(
                  //       rating: _provider!.raitng,
                  //       itemBuilder: (context, index) =>
                  //           const Icon(Icons.star, color: Colors.amber),
                  //       itemCount: 5,
                  //       itemSize: 16,
                  //     ),
                  //     const SizedBox(width: 8),
                  //     Text(
                  //       '${_provider!.raitng.toStringAsFixed(1)} (${_provider!.totalReviews} reviews)',
                  //       style: const TextStyle(
                  //         fontSize: 14,
                  //         color: AppColors.textSecondary,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),

            // // Verification Badge
            // if (_provider!.isVerified)
            //   Container(
            //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            //     decoration: BoxDecoration(
            //       color: AppColors.success.withValues(alpha: 0.1),
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //     child: Row(
            //       mainAxisSize: MainAxisSize.min,
            //       children: [
            //         Icon(Icons.verified, size: 14, color: AppColors.success),
            //         const SizedBox(width: 4),
            //         Text(
            //           'Verified',
            //           style: TextStyle(
            //             fontSize: 10,
            //             fontWeight: FontWeight.w600,
            //             color: AppColors.success,
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Service Mobile Number
            if (widget.service.mobileNumber.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service Contact',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.service.mobileNumber,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _makePhoneCall(widget.service.mobileNumber),
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

            // Provider Mobile Number (if different)
            if (_provider?.mobileNumber.isNotEmpty == true &&
                _provider!.mobileNumber != widget.service.mobileNumber) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Provider Contact',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _provider!.mobileNumber,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _makePhoneCall(_provider!.mobileNumber),
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookingDetailsSection() {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return const SizedBox.shrink();

        final booking = bookingProvider.getUserBookingForService(
          currentUser.uid,
          widget.service.id,
        );

        if (booking == null) return const SizedBox.shrink();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bookmark, color: AppColors.success, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Your Booking Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Booking Status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      booking.status,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(
                        booking.status,
                      ).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getStatusIcon(booking.status),
                            color: _getStatusColor(booking.status),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status: ${booking.status}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(booking.status),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Booked on: ${Helpers.formatDate(booking.createdAt)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      ...[
                        const SizedBox(height: 4),
                        Text(
                          'Scheduled for: ${Helpers.formatDate(booking.scheduledDateTime)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                      if (booking.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Description: ${booking.description}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceDescription() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Service Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.service.description.isNotEmpty
                  ? widget.service.description
                  : 'No description available for this service.',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookServiceButton(BuildContext context) {
    final isAvailable = widget.service.isAvailableForBooking;
    final isBooked = widget.service.isBooked;

    String buttonText;
    Color buttonColor;

    if (isAvailable && !isBooked) {
      buttonText = 'Book This Service';
      buttonColor = AppColors.primary;
    } else if (isBooked) {
      buttonText = 'Service Already Booked';
      buttonColor = Colors.orange;
    } else {
      buttonText = 'Service Unavailable';
      buttonColor = Colors.grey;
    }

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [buttonColor, buttonColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (isAvailable && !isBooked && !_isBooking)
            ? () => _bookService(context)
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isBooking
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Booking Service...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAvailable && !isBooked
                        ? Icons.calendar_today
                        : Icons.block,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (isAvailable && !isBooked) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  // Helper methods
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
      case 'carepentry':
        return Icons.construction;
      default:
        return Icons.build;
    }
  }

  void _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    } catch (e) {
      debugPrint('Error making phone call: $e');
    }
  }

  void _bookService(BuildContext context) async {
    if (_isBooking || !mounted) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a desired date before booking'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool? confirmed = await _showBookingConfirmationDialog(context);
    if (confirmed != true || !mounted) return;

    setState(() {
      _isBooking = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to book service')),
          );
        }
        return;
      }

      // ✅ GET USER DATA BEFORE BOOKING
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();

      // ✅ ENSURE USER DATA IS AVAILABLE
      if (authProvider.userModel == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete your profile before booking'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // ✅ FIXED: Add required customer parameters
      final booking = await bookingProvider.createBooking(
        customerId: user.uid,
        providerId: widget.service.providerId,
        service: widget.service,
        scheduledDateTime: _selectedDate!,
        description: widget.service.description.isNotEmpty
            ? widget.service.description
            : 'Service booking',
        customerAddress:
            authProvider.userModel?.address ??
            'Customer address to be confirmed',
        customerLatitude: widget.service.latitude ?? 0.0,
        customerLongitude: widget.service.longitude ?? 0.0,
        totalAmount: widget.service.basePrice,
        selectedDate: _selectedDate,
        // ✅ ADD THESE REQUIRED PARAMETERS
        customerName: authProvider.userModel?.name ?? 'Customer',
        customerPhone: authProvider.userModel?.phone ?? '',
        customerEmail: authProvider.userModel?.email ?? '',
      );

      if (!mounted) return;

      if (booking != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.service.name} booked successfully!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );

        // Reload booking data
        _loadBookingData();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bookingProvider.errorMessage ?? 'Failed to book service',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book service: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  Future<bool?> _showBookingConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.event_available, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            const Text('Confirm Booking'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to book this service?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.service.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.currency_rupee,
                        size: 16,
                        color: AppColors.success,
                      ),
                      Text(
                        '${widget.service.basePrice.toInt()}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        ' (Base Price)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  // Add selected date display here
                  if (_selectedDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Desired Date: ${Helpers.formatDateTime(_selectedDate!)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (_provider != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Provider: ${_provider!.businessName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The provider will contact you for scheduling details.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );
  }
}

// ✅ Update helper methods to work with enum
Color _getStatusColor(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return Colors.orange;
    case BookingStatus.confirmed:
      return Colors.blue;
    case BookingStatus.inProgress:
      return Colors.yellow;
    case BookingStatus.completed:
      return AppColors.success;
    case BookingStatus.cancelled:
      return AppColors.error;
    case BookingStatus.refunded:
      return AppColors.error;
    case BookingStatus.paymentPending:
      return AppColors.error;
    case BookingStatus.paid:
      return AppColors.success;
  }
}

IconData _getStatusIcon(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return Icons.schedule;
    case BookingStatus.confirmed:
      return Icons.check_circle;
    case BookingStatus.inProgress:
      return Icons.hourglass_empty;
    case BookingStatus.completed:
      return Icons.done_all;
    case BookingStatus.cancelled:
      return Icons.cancel;
    case BookingStatus.refunded:
      return Icons.money_off;
    case BookingStatus.paymentPending:
      return Icons.payments;
    case BookingStatus.paid:
      return Icons.verified;
  }
}
