// ignore_for_file: use_build_context_synchronously, unused_local_variable, prefer_final_fields, unused_catch_stack

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/services/location_service.dart';
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

  final TextEditingController _locationController = TextEditingController();
  bool _isFetchingLocation = false;
  bool _isLocationChanged = false;
  String _savedLocationText = '';

  bool _isAfterCutoff([DateTime? now]) {
    final n = now ?? DateTime.now();
    return n.hour >= 9;
  }

  // Apply rule: if selected is "today" and now >= 9, move to tomorrow (preserve time-of-day)
  DateTime _applyCutoffRule(DateTime selected, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final isSameDay =
        selected.year == n.year &&
        selected.month == n.month &&
        selected.day == n.day;

    if (isSameDay && _isAfterCutoff(n)) {
      return DateTime(
        n.year,
        n.month,
        n.day + 1,
        selected.hour,
        selected.minute,
        selected.second,
        selected.millisecond,
        selected.microsecond,
      );
    }
    return selected;
  }

  @override
  void initState() {
    super.initState();

    // Debug authentication
    final user = FirebaseAuth.instance.currentUser;
    // debugPrint('=== AUTH VERIFICATION ===');
    // debugPrint('User ID: ${user?.uid}');
    // debugPrint('Email: ${user?.email}');
    // debugPrint('Is Authenticated: ${user != null}');
    // debugPrint('========================');

    _provider = widget.provider;

    // If provider not passed, fetch it
    if (_provider == null) {
      //debugPrint('🔄 Provider not passed, fetching from Firestore...');
      _fetchProviderData();
    } else {
      //debugPrint('✅ Provider passed from parent: ${_provider!.businessName}');
    }

    // Load bookings for this service
    _loadBookingData();

    // Debug initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCurrentLocation();
    });
  }

  Future<DateTime?> _selectConstrainedDate() async {
    final DateTime now = DateTime.now();
    final DateTime minDate = _isAfterCutoff(now)
        ? now.add(const Duration(days: 1)) // after 9 ⇒ start tomorrow
        : now; // before 9 ⇒ same-day allowed
    final DateTime maxDate = now.add(const Duration(days: 30));

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: minDate, // align initial selection with the rule
      firstDate: minDate, // disallow selecting earlier than min
      lastDate: maxDate,
      helpText: 'Select service date',
      fieldLabelText: 'Service date',
      errorInvalidText: 'Date must be within 30 days',
    );

    return pickedDate;
  }

  // ✅ NEW: Pick time between 9 AM - 6 PM only
  Future<TimeOfDay?> _selectConstrainedTime() async {
    while (true) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
        helpText: 'Select service time',
        errorInvalidText: 'Please select time between 9 AM - 6 PM',
        hourLabelText: 'Hour',
        minuteLabelText: 'Minute',
      );

      // If user cancelled, return null
      if (pickedTime == null) return null;

      // ✅ Validate working hours (9 AM - 6 PM)
      if (_isWithinWorkingHours(pickedTime)) {
        return pickedTime;
      } else {
        // Show error and ask to pick again
        await _showWorkingHoursError();
      }
    }
  }

  // ✅ NEW: Check if time is within working hours
  bool _isWithinWorkingHours(TimeOfDay time) {
    // Working hours: 9:00 AM to 6:00 PM (18:00)
    const int startHour = 9;
    const int endHour = 18;

    return time.hour >= startHour && time.hour < endHour;
  }

  // ✅ NEW: Show working hours error dialog
  Future<void> _showWorkingHoursError() async {
    return await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.access_time, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              const Text('Invalid Time'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please select a time during our working hours:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Working Hours: 9:00 AM - 6:00 PM',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Monday to Sunday',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // ✅ NEW: Combined date and time picker with constraints
  Future<void> _selectConstrainedDateTime() async {
    try {
      final DateTime? pickedDate = await _selectConstrainedDate();
      if (pickedDate == null) return;

      final TimeOfDay? pickedTime = await _selectConstrainedTime();
      if (pickedTime == null) return;

      final DateTime combined = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      // Apply 9AM cutoff shift if needed
      final DateTime finalDt = _applyCutoffRule(combined);

      setState(() {
        _selectedDate = finalDt;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Scheduled for ${Helpers.formatDateTime(finalDt)}'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      //debugPrint('Error selecting date/time: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting date/time: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      final LocationService locationService = LocationService.instance;
      final locationData = await locationService.getCurrentLocation();

      if (locationData != null && mounted) {
        // Get address from coordinates
        final address = await locationService.getAddressFromCoordinates(
          locationData.latitude!,
          locationData.longitude!,
        );

        if (address != null && mounted) {
          _locationController.text = address;
          _savedLocationText = address; // ✅ NEW: Mark as saved
          //debugPrint('✅ Location auto-fetched: $address');
        }
      }
    } catch (e) {
      //debugPrint('❌ Error auto-fetching location: $e');
      // Don't show error - location is optional
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  // ✅ ENHANCED: Manual location refresh
  Future<void> _refreshLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      final LocationService locationService = LocationService.instance;
      final locationData = await locationService.getCurrentLocation();

      if (locationData != null && mounted) {
        final address = await locationService.getAddressFromCoordinates(
          locationData.latitude!,
          locationData.longitude!,
        );

        if (address != null && mounted) {
          _locationController.text = address;
          _savedLocationText = address; // ✅ NEW: Mark as saved
          setState(
            () => _isLocationChanged = false,
          ); // ✅ NEW: Reset changed flag

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Location updated successfully'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _saveLocation() async {
    final currentLocation = _locationController.text.trim();

    if (currentLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location cannot be empty'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      // ✅ Save location logic (you can add backend save here if needed)
      setState(() {
        _savedLocationText = currentLocation;
        _isLocationChanged = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Location saved successfully'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );

      //debugPrint('✅ Location saved: $currentLocation');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save location: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _fetchProviderData() async {
    if (widget.service.providerId.isEmpty) {
      //debugPrint('❌ No provider ID provided');
      return;
    }

    setState(() {
      _isLoadingProvider = true;
    });

    try {
      //debugPrint('🔄 Fetching provider data for: ${widget.service.providerId}');

      // ✅ FIRST: Try to get from providers collection
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.service.providerId)
          .get();

      if (providerDoc.exists && providerDoc.data() != null) {
        final providerModel = ProviderModel.fromFireStore(providerDoc);
        // debugPrint(
        //   '✅ Provider found in providers collection: ${providerModel.businessName}',
        // );

        if (mounted) {
          setState(() {
            _provider = providerModel;
            _isLoadingProvider = false;
          });
        }
        return;
      }

      // ✅ FALLBACK: If not found in providers collection, get from user data
      // debugPrint(
      //   '⚠️ Provider not found in providers collection, checking user data...',
      // );
      final userDoc = await FirebaseDatabase.instance
          .ref('users')
          .child(widget.service.providerId)
          .get();

      if (userDoc.exists && userDoc.value != null) {
        final userData = Map<String, dynamic>.from(userDoc.value as Map);
        //debugPrint('✅ User data found: ${userData['name']}');

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
          //debugPrint('✅ Temporary provider model created');
        }
        return;
      }

      //debugPrint('❌ No provider data found anywhere');
      if (mounted) {
        setState(() {
          _provider = null;
          _isLoadingProvider = false;
        });
      } else {
        //debugPrint('❌ Provider document does not exist or has no data');
        if (mounted) {
          setState(() {
            _provider = null;
            _isLoadingProvider = false;
          });
        }
      }
    } catch (e, stackTrace) {
      //debugPrint('❌ Error fetching provider: $e');
      //debugPrint('Stack trace: $stackTrace');

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
              //debugPrint('🔄 Manual refresh triggered');
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

                  _buildLocationField(),
                  const SizedBox(height: 24),

                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: InkWell(
                      onTap: _selectConstrainedDateTime,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.event,
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedDate == null
                                            ? 'Select desired date & time'
                                            : 'Selected Date & Time',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (_selectedDate != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          Helpers.formatDateTime(
                                            _selectedDate!,
                                          ),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),

                            // ✅ NEW: Show working hours info
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Available: Next 30 days • 9 AM - 6 PM',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
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

    final providerBusinessName =
        widget.service.providerBusinessName ??
        _provider?.businessName ??
        'Service Provider';

    final providerName =
        widget.service.providerName ??
        _provider?.businessName ??
        'Service Provider';

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
              radius: 32,
              backgroundColor: AppColors.primary,
              child: Text(
                providerBusinessName.isNotEmpty
                    ? providerBusinessName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
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
                    providerBusinessName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ✅ ENHANCED: Provider Rating from Analytics
                  _buildProviderRating(),

                  // Contact Person (if different)
                  if (providerName != providerBusinessName &&
                      providerName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Contact: $providerName',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  // Experience
                  if (_provider?.experience?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    // ✅ ENHANCED: Get phone number with proper priority
    final servicePhone = widget.service.mobileNumber;
    final providerPhone = _provider?.mobileNumber ?? '';

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

            // ✅ ENHANCED: Service Mobile Number (Primary Contact)
            if (servicePhone.isNotEmpty)
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
                            'Primary Contact',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            servicePhone,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          // ✅ NEW: Show business name with phone
                          if (widget.service.providerBusinessName != null &&
                              widget
                                  .service
                                  .providerBusinessName!
                                  .isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.service.providerBusinessName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _makePhoneCall(servicePhone),
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

            // ✅ NEW: Alternative contact (if provider phone is different)
            if (providerPhone.isNotEmpty && providerPhone != servicePhone) ...[
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
                            'Alternative Contact',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            providerPhone,
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
                      onPressed: () => _makePhoneCall(providerPhone),
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

            // ✅ NEW: No contact available message
            if (servicePhone.isEmpty && providerPhone.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Contact information will be available after booking confirmation',
                        style: TextStyle(fontSize: 14, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
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
                          'Scheduled for: ${Helpers.formatDate(_applyCutoffRule(booking.scheduledDateTime))}',
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
      //debugPrint('Error making phone call: $e');
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

    final selectedTime = TimeOfDay.fromDateTime(_selectedDate!);
    if (!_isWithinWorkingHours(selectedTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected time is outside working hours (9 AM - 6 PM)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your location before booking'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_isLocationChanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // ✅ Remove 'const' since we're using a function
          content: const Text(
            'Please save your location changes before booking',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'SAVE NOW',
            textColor: Colors.white,
            onPressed: () async {
              // ✅ Provide actual callback function
              await _saveLocation();
            },
          ),
        ),
      );
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

      String customerName = 'Customer';
      String customerPhone = '';
      String customerEmail = '';

      // ✅ ENSURE USER DATA IS AVAILABLE
      if (authProvider.userModel != null) {
        customerName = authProvider.userModel!.name;
        customerPhone = authProvider.userModel!.phone;
        customerEmail = authProvider.userModel!.email;
      } else {
        // Fallback: get from Firebase Auth
        customerEmail = user.email ?? '';
        // Try to get name from display name
        customerName = user.displayName ?? 'Customer';
      }

      if (customerName.isEmpty || customerName == 'null') {
        customerName = 'Customer';
      }

      // ✅ FIXED: Add required customer parameters
      final booking = await bookingProvider.createBookingWithDetails(
        customerId: user.uid,
        providerId: widget.service.providerId,
        service: widget.service,
        scheduledDateTime: _selectedDate!,
        description: widget.service.description.isNotEmpty
            ? widget.service.description
            : 'Service booking',
        customerAddress: _savedLocationText.isNotEmpty
            ? _savedLocationText
            : _locationController.text.trim(),
        customerLatitude: 0.0,
        customerLongitude: 0.0,
        totalAmount: widget.service.basePrice,
        selectedDate: _selectedDate,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        providerName:
            widget.service.providerBusinessName ??
            widget.service.providerName ??
            'Service Provider',
        providerPhone: widget.service.mobileNumber,
        providerEmail: widget.service.providerEmail ?? '',
        serviceName: widget.service.name,
        serviceCategory: widget.service.category,
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

  Widget _buildLocationField() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Service Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_isFetchingLocation)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: _isFetchingLocation
                    ? 'Getting your location...'
                    : 'Enter your location',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ NEW: Show save button when location is changed
                    if (_isLocationChanged)
                      IconButton(
                        icon: const Icon(
                          Icons.save,
                          size: 20,
                          color: AppColors.success,
                        ),
                        onPressed: _saveLocation,
                        tooltip: 'Save location',
                      ),
                    IconButton(
                      icon: const Icon(Icons.my_location, size: 20),
                      onPressed: _refreshLocation,
                      tooltip: 'Get current location',
                    ),
                  ],
                ),
              ),
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              // ✅ NEW: Track when user manually changes location
              onChanged: (value) {
                setState(() {
                  _isLocationChanged = value.trim() != _savedLocationText;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'This location will be shared with the service provider',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                // ✅ NEW: Show indicator if location has unsaved changes
                if (_isLocationChanged)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'UNSAVED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderRating() {
    if (widget.service.providerId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.service.providerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Loading rating...',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Row(
            children: [
              Icon(Icons.star_outline, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(
                'New Provider',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        if (data == null) {
          return Row(
            children: [
              Icon(Icons.star_outline, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(
                'No data',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          );
        }

        // ✅ CRITICAL: Fetch rating from analytics nested object
        double? rating;
        int? totalReviews;
        int? totalServices;
        double? completionRate;

        // ✅ Method 1: Check for analytics object (primary)
        if (data.containsKey('analytics')) {
          final analytics = data['analytics'] as Map<String, dynamic>?;
          //debugPrint('📊 [ANALYTICS] Found analytics data: $analytics');

          if (analytics != null) {
            // Try different rating field names in analytics
            if (analytics.containsKey('rating')) {
              rating = (analytics['rating'] as num?)?.toDouble();
            } else if (analytics.containsKey('averageRating')) {
              rating = (analytics['averageRating'] as num?)?.toDouble();
            } else if (analytics.containsKey('raitng')) {
              rating = (analytics['raitng'] as num?)?.toDouble();
            }

            // Get review/service counts from analytics
            if (analytics.containsKey('totalReviews')) {
              totalReviews = (analytics['totalReviews'] as num?)?.toInt();
            } else if (analytics.containsKey('reviewCount')) {
              totalReviews = (analytics['reviewCount'] as num?)?.toInt();
            }

            if (analytics.containsKey('totalServices')) {
              totalServices = (analytics['totalServices'] as num?)?.toInt();
            }

            if (analytics.containsKey('completionRate')) {
              completionRate = (analytics['completionRate'] as num?)
                  ?.toDouble();
            }

            // debugPrint(
            //   '📊 [ANALYTICS] Extracted - Rating: $rating, Reviews: $totalReviews, Services: $totalServices',
            // );
          }
        }

        // ✅ Method 2: Fallback to root-level fields
        if (rating == null || rating == 0.0) {
          if (data.containsKey('rating')) {
            rating = (data['rating'] as num?)?.toDouble();
          } else if (data.containsKey('raitng')) {
            rating = (data['raitng'] as num?)?.toDouble();
          }

          if (data.containsKey('totalReviews')) {
            totalReviews = (data['totalReviews'] as num?)?.toInt();
          }

          // debugPrint(
          //   '📊 [FALLBACK] Root-level - Rating: $rating, Reviews: $totalReviews',
          // );
        }

        final bool hasRating = rating != null && rating > 0;
        final displayRating = rating ?? 0.0;
        final displayReviews = totalReviews ?? 0;
        final displayServices = totalServices ?? 0;

        // debugPrint(
        //   '🎯 [FINAL] Rating: $displayRating, Has Rating: $hasRating, Reviews: $displayReviews',
        // );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Main Rating Display
            Row(
              children: [
                Icon(
                  hasRating ? Icons.star : Icons.star_outline,
                  color: hasRating ? Colors.amber : Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  hasRating ? displayRating.toStringAsFixed(1) : 'New Provider',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasRating ? AppColors.textPrimary : Colors.grey[600],
                  ),
                ),
                if (hasRating && displayReviews > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '($displayReviews ${displayReviews == 1 ? 'review' : 'reviews'})',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),

            // ✅ Additional Analytics Info (if available)
            if (hasRating) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  // Services completed
                  if (displayServices > 0) ...[
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$displayServices ${displayServices == 1 ? 'service' : 'services'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],

                  // Completion rate
                  if (completionRate != null && completionRate > 0) ...[
                    if (displayServices > 0) const SizedBox(width: 12),
                    Icon(Icons.trending_up, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${(completionRate * 100).toInt()}% completion',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
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

                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Location: ${_savedLocationText.isNotEmpty ? _savedLocationText : _locationController.text.trim()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // ✅ NEW: Show save status indicator
                      if (_isLocationChanged)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'UNSAVED',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
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
