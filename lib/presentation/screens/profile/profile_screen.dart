import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/data/models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/buttons/primary_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserBookings();
    });
  }

  void _loadUserBookings() {
    final authProvider = context.read<AuthProvider>();
    final bookingProvider = context.read<BookingProvider>();

    if (authProvider.user != null) {
      bookingProvider.loadUserBookings(authProvider.user!.uid);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();

      final success = await authProvider.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );

      if (success && mounted) {
        setState(() {
          _isEditing = false;
        });
        Helpers.showSnackBar(context, 'Profile updated successfully!');
        await Future.delayed(const Duration(seconds: 1));
      } else if (mounted) {
        Helpers.showSnackBar(
          context,
          'Failed to update profile. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Error: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signOut();
      if (mounted) {
        context.go('/user-type-selection');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.userModel;

          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ CRITICAL FIX: Only update controllers if values differ
          if (!_isEditing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Only update if the value is different to prevent unnecessary updates
                if (_nameController.text != user.name) {
                  _nameController.text = user.name;
                  debugPrint('Updated name controller: ${user.name}');
                }
                if (_phoneController.text != user.phone) {
                  _phoneController.text = user.phone;
                  debugPrint('Updated phone controller: ${user.phone}');
                }
                if (_addressController.text != (user.address ?? '')) {
                  _addressController.text = user.address ?? '';
                  debugPrint('Updated address controller: ${user.address}');
                }
              }
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Completion Banner
                if (!authProvider.isCustomerProfileComplete)
                  _buildCompletionBanner(authProvider.missingCustomerFields),

                // Profile Header
                _buildProfileHeader(user.name, user.email),
                const SizedBox(height: 24),

                // Statistics
                _buildStatisticsSection(),
                const SizedBox(height: 24),

                // Profile Details
                _buildProfileDetailsSection(),
                const SizedBox(height: 24),

                // Quick Actions
                _buildQuickActionsSection(),
                const SizedBox(height: 24),

                // Sign Out Button
                _buildSignOutButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String name, String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        final bookings = bookingProvider.userBookings ?? [];

        // ✅ Add loading state
        if (bookingProvider.isLoading) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        // ✅ ENHANCED: Calculate all statistics accurately
        final totalBookings = bookings.length;
        final completedBookings = bookings
            .where((b) => b.status == BookingStatus.completed)
            .length;
        final pendingBookings = bookings
            .where((b) => b.status == BookingStatus.pending)
            .length;
        final confirmedBookings = bookings
            .where((b) => b.status == BookingStatus.confirmed)
            .length;
        final inProgressBookings = bookings
            .where((b) => b.status == BookingStatus.inProgress)
            .length;
        final cancelledBookings = bookings
            .where((b) => b.status == BookingStatus.cancelled)
            .length;
        final paidBookings = bookings
            .where((b) => b.status == BookingStatus.paid)
            .length;

        // ✅ FIXED: Safe calculation of total spent (completed + paid bookings)
        final totalSpent = bookings
            .where(
              (b) =>
                  (b.status == BookingStatus.completed ||
                      b.status == BookingStatus.paid) &&
                  b.totalAmount != null,
            )
            .fold<double>(
              0.0,
              (sum, booking) => sum + (booking.totalAmount ?? 0.0),
            );

        // ✅ Calculate active bookings (pending + confirmed + in progress)
        final activeBookings =
            pendingBookings + confirmedBookings + inProgressBookings;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
                  Icon(Icons.analytics, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Your Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ✅ Show message when no bookings
              if (totalBookings == 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.book_online, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No bookings yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'Book your first service to see statistics',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else ...[
                // ✅ UPDATED: Enhanced statistics grid with more details
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Bookings',
                        totalBookings.toString(),
                        Icons.book_online,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Active',
                        activeBookings.toString(),
                        Icons.trending_up,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Completed',
                        completedBookings.toString(),
                        Icons.check_circle,
                        AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Cancelled',
                        cancelledBookings.toString(),
                        Icons.cancel,
                        AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Spent',
                        '₹${totalSpent.toStringAsFixed(0)}',
                        Icons.currency_rupee,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Paid Services',
                        paidBookings.toString(),
                        Icons.verified,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletionBanner(List<String> missingFields) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Please complete your profile to book services.',
            style: TextStyle(fontSize: 14, color: Colors.orange),
          ),
          const SizedBox(height: 12),
          Text(
            'Missing: ${missingFields.join(', ')}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
  String title,
  String value,
  IconData icon,
  Color color,
) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12, 
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}


  Widget _buildProfileDetailsSection() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.userModel;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
                  Icon(
                    Icons.person_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditing = !_isEditing;
                      });
                    },
                    icon: Icon(_isEditing ? Icons.close : Icons.edit, size: 16),
                    label: Text(_isEditing ? 'Cancel' : 'Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isEditing) ...[
                // ✅ Use ValueKey to force rebuild when data changes
                CustomTextField(
                  key: ValueKey('name_${user?.name}_$_isEditing'),
                  controller: _nameController,
                  label: 'Full Name',
                  prefixIcon: Icons.person,
                  hintText: 'Enter your full name',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  key: ValueKey('phone_${user?.phone}_$_isEditing'),
                  controller: _phoneController,
                  label: 'Phone Number',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  hintText: 'Enter your phone number',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  key: ValueKey('address_${user?.address}_$_isEditing'),
                  controller: _addressController,
                  label: 'Address',
                  prefixIcon: Icons.location_on,
                  maxLines: 2,
                  hintText: 'Enter your address',
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Save Changes',
                  onPressed: _updateProfile,
                  isLoading: _isLoading,
                ),
              ] else ...[
                _buildInfoRow('Name', user?.name ?? _nameController.text),
                _buildInfoRow('Phone', user?.phone ?? _phoneController.text),
                _buildInfoRow(
                  'Address',
                  (user?.address?.isNotEmpty == true)
                      ? user!.address!
                      : (_addressController.text.isNotEmpty
                            ? _addressController.text
                            : 'Not provided'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
              Icon(Icons.flash_on, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'About',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuickActionTile(
            Icons.settings,
            'Settings',
            'App preferences and notifications',
            () => _showComingSoon('Settings'),
          ),
          _buildQuickActionTile(
            Icons.help_outline,
            'Help & Support',
            'Get help and contact support',
            () => _showComingSoon('Help & Support'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _signOut,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.logout, size: 20),
        label: const Text(
          'Sign Out',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature feature coming soon!')));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
