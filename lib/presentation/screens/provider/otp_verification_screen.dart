// lib/presentation/screens/provider/otp_verification_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/services/progress_tracking_service.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/presentation/screens/provider/provider_dashboard_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final BookingModel booking;

  const OTPVerificationScreen({super.key, required this.booking});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  String _enteredOTP = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _verifyCustomerOTP() async {
    if (_enteredOTP.length != 4) {
      setState(() {
        _errorMessage = 'Please enter a valid 4-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // debugPrint('🔍 Verifying OTP for booking: ${widget.booking.id}');
      // debugPrint('🔍 Entered OTP: $_enteredOTP');

      // ✅ Use Firestore instead of Realtime Database
      final otpDoc = await FirebaseFirestore.instance
          .collection('booking_otps')
          .doc(widget.booking.id)
          .get();

      if (!otpDoc.exists) {
        // Alternative: Query by customer ID
        final querySnapshot = await FirebaseFirestore.instance
            .collection('booking_otps')
            .where('customerId', isEqualTo: widget.booking.customerId)
            .where('bookingId', isEqualTo: widget.booking.id)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw Exception('No verification code found for this booking.');
        }

        final otpData = querySnapshot.docs.first.data();
        await _validateAndProcessOTP(otpData);
      } else {
        final otpData = otpDoc.data()!;
        await _validateAndProcessOTP(otpData);
      }
    } catch (e) {
      //debugPrint('❌ Verification error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _validateAndProcessOTP(Map<String, dynamic> otpData) async {
    final storedOTP = otpData['otpCode']?.toString();
    final isAlreadyVerified = otpData['isVerified'] as bool? ?? false;
    final expiresAt = (otpData['expiresAt'] as Timestamp?)?.toDate();

    // debugPrint('🔍 Stored OTP: $storedOTP');
    // debugPrint('🔍 Is verified: $isAlreadyVerified');

    if (storedOTP == null || storedOTP.isEmpty) {
      throw Exception('Invalid verification code data.');
    }

    if (isAlreadyVerified) {
      throw Exception('This verification code has already been used.');
    }

    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw Exception('Verification code has expired.');
    }

    if (_enteredOTP.trim() != storedOTP.trim()) {
      throw Exception('Invalid customer code. Please check the 4-digit code.');
    }

    // ✅ CRITICAL: Update both OTP verification status AND booking status in a transaction
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final otpDocRef = FirebaseFirestore.instance
          .collection('booking_otps')
          .doc(widget.booking.id);

      final bookingDocRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.booking.id);

      // Mark OTP as verified
      transaction.update(otpDocRef, {
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      // Update booking status to inProgress with work tracking
      transaction.update(bookingDocRef, {
        'status': 'inProgress',
        'workStartTime': FieldValue.serverTimestamp(),
        'isWorkInProgress': true,
        'workProgress': 0.1, // Initial progress
        'progressUpdatedAt': FieldValue.serverTimestamp(),
      });
    });

    //debugPrint('✅ OTP verified and booking status updated to inProgress');

    // Start progress tracking
    await ProgressTrackingService.instance.startProgressTracking(
      widget.booking.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Code verified! Work started successfully.'),
          backgroundColor: AppColors.success,
        ),
      );

      // ✅ FIXED: Navigate to dashboard with initial Active tab
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              const ProviderDashboardScreen(initialTabIndex: 2), // Active tab
        ),
      );
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Enter Customer Code'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Header Card
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.orange.shade50, Colors.orange.shade100],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Start Service',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.booking.serviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Customer: ${widget.booking.customerName ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // OTP Input Card
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enter Customer\'s 4-Digit Code',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // OTP Input Field
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _errorMessage != null
                                ? AppColors.error
                                : Colors.orange,
                            width: 2,
                          ),
                          color: Colors.grey.shade50,
                        ),
                        child: TextFormField(
                          controller: _otpController,
                          focusNode: _focusNode,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 12,
                          ),
                          decoration: InputDecoration(
                            hintText: '1234',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              letterSpacing: 12,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          onChanged: (value) {
                            setState(() {
                              _enteredOTP = value;
                              _errorMessage = null;
                            });
                          },
                          onFieldSubmitted: (_) {
                            if (_enteredOTP.length == 4 && !_isLoading) {
                              _verifyCustomerOTP();
                            }
                          },
                        ),
                      ),

                      // Error Message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Start Work Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_enteredOTP.length == 4 && !_isLoading)
                              ? _verifyCustomerOTP
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                          ),
                          child: _isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Starting Work...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Start Work',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Info Card
              Card(
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Ask the customer for their 4-digit personal service code to begin work.',
                          style: TextStyle(fontSize: 14, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Cancel Button
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
