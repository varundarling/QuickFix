// ignore_for_file: use_build_context_synchronously, unused_local_variable, prefer_final_fields, unused_catch_stack

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/services/location_service.dart';
import 'package:quickfix/core/utils/currency.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/presentation/widgets/common/base_screen.dart';
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
  late TextEditingController _issueDetailsController = TextEditingController();
  bool _isFetchingLocation = false;
  bool _isLocationChanged = false;
  String _savedLocationText = '';

  bool _isAfterSixPm([DateTime? now]) {
    final n = now ?? DateTime.now();
    return n.hour >= 18;
  }

  // Apply rule: if selected is "today" and now >= 18 (6 PM), move to tomorrow
  DateTime _applySixPmCutoffRule(DateTime selected, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final isSameDay =
        selected.year == n.year &&
        selected.month == n.month &&
        selected.day == n.day;

    if (isSameDay && _isAfterSixPm(n)) {
      final tomorrow = DateTime(
        n.year,
        n.month,
        n.day,
      ).add(const Duration(days: 1));
      return DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
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

    _provider = widget.provider;

    if (_provider == null) {
      _fetchProviderData();
    }

    _loadBookingData();
    _issueDetailsController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCurrentLocation();
    });
  }

  Future<DateTime?> _selectConstrainedDate() async {
    final DateTime now = DateTime.now();

    // ✅ If after 6 PM, force tomorrow
    final DateTime minDate = now.hour >= 18
        ? now.add(const Duration(days: 1))
        : now;

    final DateTime maxDate = minDate.add(const Duration(days: 15));

    return await showDatePicker(
      context: context,
      initialDate: minDate,
      firstDate: minDate,
      lastDate: maxDate,
      helpText: 'Select service date',
      fieldLabelText: 'Service date',
      errorInvalidText: 'Date must be within 15 days',
    );
  }

  // Pick time between 9 AM - 6 PM only
  Future<TimeOfDay?> _selectConstrainedTime({required DateTime forDate}) async {
    final now = DateTime.now();
    final bool isToday =
        forDate.year == now.year &&
        forDate.month == now.month &&
        forDate.day == now.day;

    TimeOfDay minTime;
    if (isToday) {
      if (now.hour < 9) {
        minTime = const TimeOfDay(hour: 9, minute: 0);
      } else if (now.hour >= 18) {
        return null;
      } else {
        minTime = _roundUpToNext15Minutes(
          TimeOfDay(hour: now.hour, minute: now.minute),
        );
      }
    } else {
      minTime = const TimeOfDay(hour: 9, minute: 0);
    }

    // if (isToday) {
    //   if (now.hour < 9) {
    //     minTime = const TimeOfDay(hour: 9, minute: 0);
    //   } else if (now.hour >= 18) {
    //     // Should never happen because date picker blocks today
    //     return null;
    //   } else {
    //     minTime = TimeOfDay(hour: now.hour, minute: now.minute);
    //   }
    // } else {
    //   // Future date
    //   minTime = const TimeOfDay(hour: 9, minute: 0);
    // }

    while (true) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: minTime,
        helpText: 'Select service time (${minTime.format(context)} onwards)',
        hourLabelText: 'Hour',
        minuteLabelText: 'Minute',
      );

      if (pickedTime == null) return null;

      // ✅ Prevent back time
      if (!_isWithinWorkingHours(pickedTime)) {
        await _showWorkingHoursError();
        continue;
      }

      if (isToday) {
        final pickedMinutes = pickedTime.hour * 60 + pickedTime.minute;
        final minMinutes = minTime.hour * 60 + minTime.minute;

        if (pickedMinutes < minMinutes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a future time slot'),
              backgroundColor: Colors.orange,
            ),
          );
          continue;
        }
      }

      return pickedTime;
    }
  }

  bool _isWithinWorkingHours(TimeOfDay time) {
    const int startHour = 9;
    const int endHour = 18; // exclusive
    return time.hour >= startHour && time.hour < endHour;
  }

  TimeOfDay _roundUpToNext15Minutes(TimeOfDay time) {
    int minutes = ((time.minute + 14) ~/ 15) * 15; 
    int hour = time.hour;

    if (minutes == 60) {
      hour = (hour + 1) % 24;
      minutes = 0;
    }

    return TimeOfDay(hour: hour, minute: minutes);
  }

  // TimeOfDay _roundUpToNext5Minutes(TimeOfDay time) {
  //   int minutes = ((time.minute + 4) ~/ 5) * 5;
  //   int hour = time.hour;
  //   if (minutes == 60) {
  //     hour = (hour + 1) % 24;
  //     minutes = 0;
  //   }
  //   return TimeOfDay(hour: hour, minute: minutes);
  // }

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
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.2),
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

  Future<void> _selectConstrainedDateTime() async {
    try {
      final DateTime? pickedDate = await _selectConstrainedDate();
      if (pickedDate == null) return;

      final TimeOfDay? pickedTime = await _selectConstrainedTime(
        forDate: pickedDate,
      );
      if (pickedTime == null) return;

      DateTime combined = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      // Apply 6 PM cutoff rule if necessary
      final DateTime finalDt = _applySixPmCutoffRule(combined);

      setState(() {
        _selectedDate = finalDt;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Scheduled for ${Helpers.formatDateTime(finalDt)}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting date/time: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
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
          _savedLocationText = address;
        }
      }
    } catch (e) {
      // Location optional - swallow error
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

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
          _savedLocationText = address;
          setState(() => _isLocationChanged = false);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Location updated successfully'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
          }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location cannot be empty'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      setState(() {
        _savedLocationText = currentLocation;
        _isLocationChanged = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Location saved successfully'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save location: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _fetchProviderData() async {
    if (widget.service.providerId.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingProvider = true;
    });

    try {
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.service.providerId)
          .get();

      if (providerDoc.exists && providerDoc.data() != null) {
        final providerModel = ProviderModel.fromFireStore(providerDoc);
        if (mounted) {
          setState(() {
            _provider = providerModel;
            _isLoadingProvider = false;
          });
        }
        return;
      }

      final userDoc = await FirebaseDatabase.instance
          .ref('users')
          .child(widget.service.providerId)
          .get();

      if (userDoc.exists && userDoc.value != null) {
        final userData = Map<String, dynamic>.from(userDoc.value as Map);

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
        }
        return;
      }

      if (mounted) {
        setState(() {
          _provider = null;
          _isLoadingProvider = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _provider = null;
          _isLoadingProvider = false;
        });

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
    return BaseScreen(
      onScreenEnter: () {
        AdService.instance.loadInterstitial();
        AdService.instance.loadRewarded();
      },
      body: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Service Details'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () {
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
            SliverAppBar(
              expandedHeight: 250,
              pinned: false,
              backgroundColor: AppColors.primary,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(background: _buildHeaderImage()),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildServiceHeader(),
                    const SizedBox(height: 24),
                    _buildProviderSection(),
                    const SizedBox(height: 24),
                    _buildContactSection(),
                    const SizedBox(height: 24),
                    _buildServiceDescription(),
                    const SizedBox(height: 24),
                    _buildLocationField(),
                    const SizedBox(height: 16),
                    // Item/Issue details input
                    _buildIssueDetailsField(),
                    const SizedBox(height: 16),
                    _buildBookingDetailsSection(),
                    const SizedBox(height: 16),
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
                          decoration: _cardGradientDecoration(),
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
                                      'Available: Next 15 days • 9 AM - 6 PM',
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

                    const SizedBox(height: 16),
                    _buildBookServiceButton(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookServiceButton(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAvailable = widget.service.isAvailableForBooking;
    final isBooked = widget.service.isBooked;

    // Use BookingProvider to check if current user has booked this service
    final bookingProvider = Provider.of<BookingProvider>(context);
    final userBooking = currentUser == null
        ? null
        : bookingProvider.getUserBookingForService(
            currentUser.uid,
            widget.service.id,
          );

    // Determine button text & color
    String buttonText;
    Color buttonColor;

    if (!isAvailable) {
      buttonText = 'Service Unavailable';
      buttonColor = Colors.grey;
    } else if (userBooking != null) {
      // Logged-in user has a booking for this service
      buttonText = 'Service Booked by You';
      buttonColor = AppColors.success;
    } else if (isBooked) {
      // Service is booked by someone else (we don't know who here)
      buttonText = 'Service Already Booked';
      buttonColor = Colors.orange;
    } else {
      // Available and not booked
      buttonText = 'Book This Service';
      buttonColor = AppColors.primary;
    }

    final bool canBook =
        isAvailable && !isBooked && userBooking == null && !_isBooking;

    // ✅ FIXED: Return correct gradient container with ElevatedButton
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
        onPressed: canBook ? () => _bookService(context) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
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
                    canBook ? Icons.calendar_today : Icons.block,
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
                  if (canBook) ...{
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: Colors.white,
                    ),
                  },
                ],
              ),
      ),
    );
  }

  Decoration _cardGradientDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFEFF7FF), // very light blue
          Colors.white,
        ],
      ),
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _buildHeaderImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.service.imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.service.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => _buildDefaultHeader(),
              )
            : _buildDefaultHeader(),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.28),
              ],
            ),
          ),
        ),
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
                  color: AppColors.success.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Removed extra attach_money icon to avoid double-dollar feeling.
                Text(
                  Currency.formatUsd(widget.service.basePrice),
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
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardGradientDecoration(),
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
                    color: AppColors.primary.withValues(alpha: 0.08),
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
                        ? AppColors.success.withValues(alpha: 0.08)
                        : Colors.orange.withValues(alpha: 0.08),
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
                // Removed attach_money icon to avoid duplicate dollar impression.
                Text(
                  Currency.formatUsd(widget.service.basePrice),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  ' / day',
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
    return Card(
      key: ValueKey('provider_${_provider?.id ?? 'null'}_$_isLoadingProvider'),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardGradientDecoration(),
        child: _buildProviderContent(),
      ),
    );
  }

  Widget _buildProviderContent() {
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    providerBusinessName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProviderRating(),
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
    final servicePhone = widget.service.mobileNumber;
    final providerPhone = _provider?.mobileNumber ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardGradientDecoration(),
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
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardGradientDecoration(),
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
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled for: ${Helpers.formatDate(_applySixPmCutoffRule(booking.scheduledDateTime))}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardGradientDecoration(),
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

  Widget _buildLocationField() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: _cardGradientDecoration(),
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
                // Refresh button at end of line
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _refreshLocation,
                  tooltip: 'Refresh Location',
                ),
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
                if (_isLocationChanged)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
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

  Widget _buildIssueDetailsField() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: _cardGradientDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.report_problem, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Item / Issue Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                const Text(
                  '(Required)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _issueDetailsController,
              decoration: InputDecoration(
                hintText:
                    'Describe the item or issue that needs to be fixed (e.g., "Leaking pipe under kitchen sink").',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Text(
              'Provide concise details so the provider can prepare the right tools/parts.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
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

        double? rating;
        int? totalReviews;
        int? totalServices;
        double? completionRate;

        if (data.containsKey('analytics')) {
          final analytics = data['analytics'] as Map<String, dynamic>?;
          if (analytics != null) {
            if (analytics.containsKey('rating')) {
              rating = (analytics['rating'] as num?)?.toDouble();
            } else if (analytics.containsKey('averageRating')) {
              rating = (analytics['averageRating'] as num?)?.toDouble();
            } else if (analytics.containsKey('raitng')) {
              rating = (analytics['raitng'] as num?)?.toDouble();
            }

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
          }
        }

        if (rating == null || rating == 0.0) {
          if (data.containsKey('rating')) {
            rating = (data['rating'] as num?)?.toDouble();
          } else if (data.containsKey('raitng')) {
            rating = (data['raitng'] as num?)?.toDouble();
          }

          if (data.containsKey('totalReviews')) {
            totalReviews = (data['totalReviews'] as num?)?.toInt();
          }
        }

        final bool hasRating = rating != null && rating > 0;
        final displayRating = rating ?? 0.0;
        final displayReviews = totalReviews ?? 0;
        final displayServices = totalServices ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if (hasRating) ...[
              const SizedBox(height: 4),
              Row(
                children: [
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
                color: AppColors.primary.withValues(alpha: 0.08),
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
                      Text(
                        Currency.formatUsd(widget.service.basePrice),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(Base Price)',
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
                  if (_issueDetailsController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Issue details: ${_issueDetailsController.text.trim()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
    _issueDetailsController.dispose();
    super.dispose();
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
      // ignore
    }
  }

  void _bookService(BuildContext context) async {
    if (_isBooking || !mounted) return;

    // ✅ Validation 1: Date selected
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a desired date before booking'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ Validation 2: Time within working hours
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

    // ✅ Validation 3: Location entered
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

    // ✅ Validation 4: Issue details entered
    if (_issueDetailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the item or issue to be fixed'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // ✅ Validation 5: Location saved
    if (_isLocationChanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please save your location changes before booking',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'SAVE NOW',
            textColor: Colors.white,
            onPressed: () async => await _saveLocation(),
          ),
        ),
      );
      return;
    }

    // ✅ Show confirmation dialog
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

      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();

      String customerName = 'Customer';
      String customerPhone = '';
      String customerEmail = '';

      if (authProvider.userModel != null) {
        customerName = authProvider.userModel!.name;
        customerPhone = authProvider.userModel!.phone;
        customerEmail = authProvider.userModel!.email;
      } else {
        customerEmail = user.email ?? '';
        customerName = user.displayName ?? 'Customer';
      }

      if (customerName.isEmpty || customerName == 'null') {
        customerName = 'Customer';
      }

      Future<void> performBooking({
        required User user,
        required BookingProvider bookingProvider,
        required String customerName,
        required String customerPhone,
        required String customerEmail,
      }) async {
        final booking = await bookingProvider.createBookingWithDetails(
          customerId: user.uid,
          providerId: widget.service.providerId,
          service: widget.service,
          scheduledDateTime: _selectedDate!,
          description: widget.service.description, // provider description
          customerDescription: _issueDetailsController.text
              .trim(), // customer issue
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

          _loadBookingData();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        } else {
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
      }

      // ✅ Show rewarded ad BEFORE booking
      bool bookingTriggered = false;

      await AdService.instance.showRewarded(
        onReward: (reward) async {
          bookingTriggered = true;
          await performBooking(
            user: user,
            bookingProvider: bookingProvider,
            customerName: customerName,
            customerPhone: customerPhone,
            customerEmail: customerEmail,
          );
        },
      );

      // ✅ FALLBACK: If ad failed / skipped / not shown
      if (!bookingTriggered) {
        await performBooking(
          user: user,
          bookingProvider: bookingProvider,
          customerName: customerName,
          customerPhone: customerPhone,
          customerEmail: customerEmail,
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

  // Helper functions for status colors/icons (unchanged)
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
}
