// ignore_for_file: unused_local_variable

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/presentation/screens/booking/customer_otp_screen.dart';
import 'package:quickfix/presentation/screens/payment/payment_options_screen.dart';
import 'package:quickfix/presentation/widgets/common/banner_ad_widget.dart';
import 'package:quickfix/presentation/widgets/common/base_screen.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;

  StreamSubscription<QuerySnapshot>? _bookingsSubscription;

  final List<Map<String, dynamic>> _tabs = [
    {
      'label': 'Pending',
      'status': BookingStatus.pending,
      'icon': Icons.schedule,
    },
    {
      'label': 'Active',
      'status': BookingStatus.confirmed,
      'icon': Icons.construction,
    },
    {
      'label': 'Completed',
      'status': BookingStatus.completed,
      'icon': Icons.payment,
    }, // ✅ New tab
    {
      'label': 'History',
      'status': BookingStatus.paid,
      'icon': Icons.history,
    }, // ✅ Changed to paid status
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealTimeBookings();
    });
  }

  // ✅ NULL-SAFE: Real-time bookings listener
  // In CustomerBookingsScreen - Enhanced real-time setup
  Future<void> _setupRealTimeBookings() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();

      final currentUser = authProvider.user;
      if (currentUser == null) {
        //debugPrint('❌ [CUSTOMER] No current user, cannot setup listener');
        setState(() {
          isLoading = false;
        });
        return;
      }

      // debugPrint(
      //   '🔄 [CUSTOMER] Setting up enhanced listener: ${currentUser.uid}',
      // );

      // ✅ CRITICAL: Load initial data with provider details
      await bookingProvider.loadUserBookingsWithProviderData(currentUser.uid);

      // ✅ Set up real-time listener with enhanced error handling
      _bookingsSubscription?.cancel();
      _bookingsSubscription = FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
            (snapshot) async {
              if (!mounted) return;

              // debugPrint(
              //   '🔔 [CUSTOMER] Processing ${snapshot.docs.length} real-time updates',
              // );

              try {
                List<BookingModel> bookingsWithProviderDetails = [];

                // ✅ Process bookings with enhanced provider fetching
                for (var doc in snapshot.docs) {
                  try {
                    BookingModel booking = BookingModel.fromFireStore(doc);

                    // ✅ CRITICAL: Always fetch provider details with encryption handling
                    // debugPrint(
                    //   '🔍 [CUSTOMER] Fetching provider for: ${booking.providerId}',
                    // );

                    // Use enhanced provider fetching method
                    final providerDetails = await bookingProvider
                        .fetchProviderDetailsForCustomer(booking.providerId);

                    if (providerDetails != null) {
                      booking = booking.copyWith(
                        providerName:
                            providerDetails['providerName'] ??
                            'Service Provider',
                        providerPhone: providerDetails['providerPhone'] ?? '',
                        providerEmail: providerDetails['providerEmail'] ?? '',
                      );
                      // debugPrint(
                      //   '✅ [CUSTOMER] Provider details added: ${providerDetails['providerName']}',
                      // );
                    } else {
                      // debugPrint(
                      //   '⚠️ [CUSTOMER] No provider details found for: ${booking.providerId}',
                      // );
                      // Create fallback provider info
                      booking = booking.copyWith(
                        providerName: 'Service Provider',
                        providerPhone: '', // Hidden for privacy
                        providerEmail: '',
                      );
                    }

                    bookingsWithProviderDetails.add(booking);
                  } catch (e) {
                    //debugPrint('❌ [CUSTOMER] Error processing booking: $e');
                    // Add booking with minimal provider info rather than skipping
                    BookingModel booking = BookingModel.fromFireStore(doc);
                    booking = booking.copyWith(
                      providerName: 'Error loading provider',
                      providerPhone: '',
                      providerEmail: '',
                    );
                    bookingsWithProviderDetails.add(booking);
                  }
                }

                if (mounted) {
                  bookingProvider.updateUserBookings(
                    bookingsWithProviderDetails,
                  );
                  setState(() {
                    isLoading = false;
                  });
                  // debugPrint(
                  //   '✅ [CUSTOMER] Real-time update completed: ${bookingsWithProviderDetails.length} bookings',
                  // );
                }
              } catch (e) {
                // debugPrint('❌ [CUSTOMER] Error in real-time processing: $e');
                if (mounted) {
                  setState(() {
                    isLoading = false;
                  });
                }
              }
            },
            onError: (error) {
              //debugPrint('❌ [CUSTOMER] Real-time listener error: $error');
              if (mounted) {
                setState(() {
                  isLoading = false;
                });
              }
            },
          );
    } catch (e) {
      //debugPrint('❌ [CUSTOMER] Setup error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ✅ NULL-SAFE: Load bookings method
  Future<void> _loadBookings() async {
    if (!mounted) return;

    try {
      setState(() {
        isLoading = true;
      });

      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();

      final currentUser = authProvider.user;
      if (currentUser?.uid != null) {
        //debugPrint('🔄 [CUSTOMER] Manual refresh with provider data');
        // ✅ CRITICAL: Use the enhanced method that loads provider details
        await bookingProvider.loadUserBookingsWithProviderData(
          currentUser!.uid,
        );
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      //debugPrint('❌ [CUSTOMER] Load bookings error: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bookings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          title: const Text('My Bookings'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _tabs.map((tab) {
              return Tab(
                icon: Icon(tab['icon'] as IconData),
                text: tab['label'] as String,
              );
            }).toList(),
          ),
        ),
        body: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading your bookings...'),
                  ],
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: _tabs.map((tab) {
                  return _buildBookingsList(tab['status'] as BookingStatus);
                }).toList(),
              ),
        // Add banner ad at bottom
        bottomNavigationBar: const BannerAdWidget(),
      ),
    );
  }

  Widget _buildBookingsList(BookingStatus status) {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        final allBookings = bookingProvider.userBookings;
        List<BookingModel> bookings = [];

        try {
          switch (status) {
            case BookingStatus.pending:
              bookings = allBookings
                  .where((booking) => booking.status == BookingStatus.pending)
                  .toList();
              break;

            case BookingStatus.confirmed:
              bookings = allBookings
                  .where(
                    (booking) =>
                        booking.status == BookingStatus.confirmed ||
                        booking.status == BookingStatus.inProgress,
                  )
                  .toList();
              break;

            // ✅ FIXED: Completed tab shows only services awaiting payment
            case BookingStatus.completed:
              bookings = allBookings
                  .where((booking) => booking.status == BookingStatus.completed)
                  .toList();
              // debugPrint(
              //   '🔍 Customer Completed tab: ${bookings.length} awaiting payment',
              // );
              break;

            // ✅ FIXED: History tab shows paid and cancelled bookings
            case BookingStatus.paid:
              bookings = allBookings
                  .where(
                    (booking) =>
                        booking.status == BookingStatus.paid ||
                        booking.status == BookingStatus.cancelled,
                  )
                  .toList();
              // debugPrint(
              //   '🔍 Customer History tab: ${bookings.length} paid/cancelled bookings',
              // );
              break;

            default:
              bookings = [];
          }
        } catch (e) {
          // debugPrint('❌ [CUSTOMER] Error filtering bookings: $e');
          bookings = [];
        }

        // Debug print for each tab
        // debugPrint(
        //   '📊 Customer ${status.toString()} tab: ${bookings.length} bookings',
        // );
        for (var booking in bookings.take(3)) {
          //debugPrint('   - ${booking.serviceName}: ${booking.status}');
        }

        // ... rest of the method remains the same
        if (bookings.isEmpty) {
          return RefreshIndicator(
            onRefresh: _loadBookings,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ${_getStatusDisplayName(status)} bookings',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (status == BookingStatus.pending)
                        ElevatedButton(
                          onPressed: () => context.go('/home'),
                          child: const Text('Browse Services'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadBookings,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              return _buildBookingCard(bookings[index]);
            },
          ),
        );
      },
    );
  }

  // In CustomerBookingsScreen - Enhanced booking card with provider details
  Widget _buildBookingCard(BookingModel booking) {
    final statusColor = Helpers.getStatusColor(booking.status.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToBookingDetail(booking),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Name and Status Row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.serviceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getCustomerStatusDisplay(booking.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ✅ CRITICAL: Provider Details Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Service Provider',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Provider Business Name
                    Row(
                      children: [
                        Icon(
                          Icons.store,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            booking.providerName ?? 'Loading provider...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color:
                                  (booking.providerName == null ||
                                      booking.providerName ==
                                          'Loading provider...' ||
                                      booking.providerName ==
                                          'Error loading provider')
                                  ? Colors.grey.shade600
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),

                        // Loading indicator for provider details
                        if (booking.providerName == null ||
                            booking.providerName == 'Loading provider...')
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.grey.shade400,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // ✅ ENHANCED: Provider Phone with better visibility
                    if (booking.providerPhone != null &&
                        booking.providerPhone!.isNotEmpty &&
                        (booking.status == BookingStatus.confirmed ||
                            booking.status == BookingStatus.inProgress ||
                            booking.status == BookingStatus.completed)) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                booking.providerPhone!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            // Call button
                            InkWell(
                              onTap: () =>
                                  Helpers.launchPhone(booking.providerPhone!),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.call,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              _buildNarrowProgressBar(booking),

              const SizedBox(height: 12),

              // Status-specific messages (your existing code)
              if (booking.status == BookingStatus.confirmed) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Service accepted! Provider will start soon.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Date and Amount Row
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    booking.selectedDate != null
                        ? Helpers.formatDateTime(booking.selectedDate!)
                        : 'No date selected',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Price and View Details
              Row(
                children: [
                  const Icon(
                    Icons.currency_rupee,
                    size: 16,
                    color: AppColors.success,
                  ),
                  Text(
                    '${booking.totalAmount.toInt()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _navigateToBookingDetail(booking),
                    child: const Text('View Details'),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              _buildCustomerActionButtons(booking),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusDisplayName(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'pending';
      case BookingStatus.confirmed:
        return 'active';
      case BookingStatus.completed:
        return 'completed'; // ✅ Services awaiting payment
      case BookingStatus.paid:
        return 'history'; // ✅ Paid and cancelled bookings
      default:
        return 'unknown';
    }
  }

  String _getCustomerStatusDisplay(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Accepted';
      case BookingStatus.inProgress:
        return 'Work in Progress';
      case BookingStatus.completed:
        return 'Completed - Payment Required';
      case BookingStatus.paid:
        return 'Paid';
      case BookingStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Future<void> onPaymentCompleted() async {
    //debugPrint('🔄 [CUSTOMER] Payment completed, refreshing bookings');
    await _loadBookings();

    // Navigate to history tab to show the completed payment
    if (mounted) {
      _tabController.animateTo(3); // History tab index
    }
  }

  Widget _buildCustomerActionButtons(BookingModel booking) {
    switch (booking.status) {
      case BookingStatus.pending:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _cancelBooking(booking),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            child: const Text('Cancel Booking'),
          ),
        );

      case BookingStatus.confirmed:
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .doc(booking.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final status = data?['status'] as String?;
            final isWorkInProgress =
                data?['isWorkInProgress'] as bool? ?? false;

            // ✅ FIXED: Check for inProgress status
            if (status == 'inProgress' || isWorkInProgress) {
              return _buildWorkInProgressCard();
            }

            // Show OTP viewing option for confirmed bookings
            return _buildOTPViewCard(booking);
          },
        );

      case BookingStatus.inProgress:
        return _buildWorkInProgressCard();

      // ✅ FIXED: Completed status shows payment options
      case BookingStatus.completed:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Service Completed!',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose your payment method',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.success.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showPaymentOptions(booking),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.payment, size: 20),
                label: const Text(
                  'Choose Payment Method',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );

      // ✅ NEW: Show completion status for paid bookings
      case BookingStatus.paid:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: const Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Payment Completed',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'Service completed successfully',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ),
        );

      // ✅ NEW: Show cancelled status
      case BookingStatus.cancelled:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, color: AppColors.error, size: 20),
              SizedBox(width: 8),
              Text(
                'Booking Cancelled',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWorkInProgressCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.1),
              AppColors.primary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.construction,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Service In Progress',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Provider is working on your service',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPViewCard(BookingModel booking) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.orange.withValues(alpha: 0.1),
              Colors.orange.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Service Accepted!',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Provider needs your verification code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.orange.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerOTPScreen(booking: booking),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.code, size: 18),
                label: const Text(
                  'View Verification Code',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrowProgressBar(BookingModel booking) {
    if (booking.status != BookingStatus.inProgress ||
        !booking.isWorkInProgress) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(booking.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final isWorkInProgress = data['isWorkInProgress'] as bool? ?? false;
        if (!isWorkInProgress) return const SizedBox.shrink();

        final workStartTs = data['workStartTime'] as Timestamp?;
        final workStartTime = workStartTs?.toDate();
        final dbProgress = ((data['workProgress'] ?? 0.0) as num).toDouble();

        if (workStartTime == null) return const SizedBox.shrink();

        final display = _computeSyncedProgress(workStartTime, dbProgress);

        return Container(
          margin: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.work, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    'Work Progress - ${(display * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: display,
                  minHeight: 4,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _computeSyncedProgress(DateTime workStartTime, double dbProgress) {
    final minutes = DateTime.now().difference(workStartTime).inMinutes;
    final intervals = minutes ~/ 15; // one step every 15 minutes
    final stepped = 0.10 + (intervals * 0.05); // base 10% + 5% per step
    final computed = stepped.clamp(0.0, 0.95);
    final persisted = (dbProgress.isNaN ? 0.0 : dbProgress).clamp(0.0, 0.95);
    return persisted > computed ? persisted : computed;
  }

  void _showPaymentOptions(BookingModel booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentOptionsScreen(booking: booking),
      ),
    );
  }

  // ✅ NULL-SAFE: Cancel booking
  Future<void> _cancelBooking(BookingModel booking) async {
    if (booking.id.isEmpty) {
      //debugPrint('❌ [CUSTOMER] Cannot cancel booking with empty ID');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final bookingProvider = context.read<BookingProvider>();
        final success = await bookingProvider.updateBookingStatus(
          booking.id,
          BookingStatus.cancelled,
          booking.providerId,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking cancelled successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 2000));
          await _loadBookings();
        }
      } catch (e) {
        //debugPrint('❌ [CUSTOMER] Cancel error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel booking: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {}
    }
  }

  void _navigateToBookingDetail(BookingModel booking) {
    if (booking.id.isNotEmpty) {
      context.push('/customer-booking-detail/${booking.id}');
    }
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.schedule;
      case BookingStatus.confirmed:
        return Icons.construction;
      case BookingStatus.inProgress:
        return Icons.build;
      case BookingStatus.completed:
        return Icons.payment;
      case BookingStatus.paid:
        return Icons.history;
      default:
        return Icons.help_outline;
    }
  }

  // In CustomerBookingDetailScreen - Enhanced provider details fetching

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }
}
