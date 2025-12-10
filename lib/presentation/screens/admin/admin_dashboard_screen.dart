import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/utils/navigation_helper.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/data/models/user_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;

  List<BookingModel> _bookings = [];
  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ===== 1) Load all bookings (services) =====
      final bookingsSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .get();

      final bookings = bookingsSnap.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();

      // ===== 2) Load all users (admin + providers + customers) =====
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final List<UserModel> users = [];

      for (final doc in usersSnap.docs) {
        final data = doc.data();

        // Ensure we have an id
        data['id'] ??= doc.id;

        // 🔧 NORMALIZE TIMESTAMP FIELDS
        // Firestore: createdAt: Timestamp → convert to int ms so
        // UserModel.fromRealtimeDatabase does not crash
        if (data['createdAt'] is Timestamp) {
          final ts = data['createdAt'] as Timestamp;
          data['createdAt'] = ts.millisecondsSinceEpoch;
        }

        // In case some users were stored with 'joinDate' as Timestamp
        if (data['joinDate'] is Timestamp) {
          final ts = data['joinDate'] as Timestamp;
          data['joinDate'] = ts.millisecondsSinceEpoch;
        }

        users.add(UserModel.fromRealtimeDatabase(data));
      }

      setState(() {
        _bookings = bookings;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load admin data: $e';
      });
    }
  }

  // ======= METRICS =======

  int get totalServicesCreated => _bookings.length;

  int get acceptedServicesCount =>
      _bookings.where((b) => b.status == BookingStatus.confirmed).length;

  int get activeServicesCount => _bookings
      .where(
        (b) =>
            b.status == BookingStatus.confirmed ||
            b.status == BookingStatus.inProgress,
      )
      .length;

  int get ongoingServicesCount =>
      _bookings.where((b) => b.status == BookingStatus.inProgress).length;

  int get completedServicesCount => _bookings
      .where(
        (b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.paid,
      )
      .length;

  int get cancelledServicesCount => _bookings
      .where(
        (b) =>
            b.status == BookingStatus.cancelled ||
            b.status == BookingStatus.refunded,
      )
      .length;

  Map<String, int> get statusChartData => {
    'Created': totalServicesCreated,
    'Accepted': acceptedServicesCount,
    'Active': activeServicesCount,
    'Ongoing': ongoingServicesCount,
    'Completed': completedServicesCount,
    'Cancelled': cancelledServicesCount,
  };

  Map<String, int> _groupByMonth<T>(
    List<T> items,
    DateTime? Function(T) dateSelector,
  ) {
    final Map<String, int> result = SplayTreeMap(); // sorted by key
    final formatter = DateFormat('MMM yyyy');

    for (final item in items) {
      final date = dateSelector(item);
      if (date == null) continue;
      final key = formatter.format(date);
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  Map<String, int> get servicesPerMonth =>
      _groupByMonth<BookingModel>(_bookings, (b) => b.createdAt);

  Map<String, int> get usersPerMonth =>
      _groupByMonth<UserModel>(_users, (u) => u.createdAt);

  Map<String, int> get usersByLocation {
    final Map<String, int> map = {};
    for (final u in _users) {
      final rawAddress = u.address?.trim() ?? '';
      String city;
      if (rawAddress.isEmpty) {
        city = 'Unknown';
      } else {
        // Take first part as "city"
        city = rawAddress.split(',').first.trim();
        if (city.isEmpty) city = 'Unknown';
      }
      map[city] = (map[city] ?? 0) + 1;
    }
    return map;
  }

  // ======= UI HELPERS (simple container-based charts) =======

  Widget _buildHorizontalBarChart(
    String title,
    Map<String, int> data, {
    String? subtitle,
  }) {
    final entries = data.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) {
      return _buildCard(
        title: title,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No data available',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        subtitle: subtitle,
      );
    }

    final maxValue = entries.fold<int>(
      0,
      (max, e) => e.value > max ? e.value : max,
    );

    return _buildCard(
      title: title,
      subtitle: subtitle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxBarWidth = constraints.maxWidth - 110;
            return Column(
              children: entries.map((entry) {
                final double fraction = maxValue == 0
                    ? 0
                    : entry.value / maxValue;
                final barWidth = (maxBarWidth * fraction).clamp(
                  4.0,
                  maxBarWidth,
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Container(
                              height: 16,
                              width: barWidth,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Positioned.fill(
                              child: Center(
                                child: Text(
                                  entry.value.toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard({required String title, Widget? child, String? subtitle}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
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
          if (child != null) child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSummaryTiles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildSummaryTile(
            label: 'Total Services Created',
            value: totalServicesCreated.toString(),
            icon: Icons.list_alt,
            color: AppColors.primary,
          ),
          _buildSummaryTile(
            label: 'Accepted',
            value: acceptedServicesCount.toString(),
            icon: Icons.check_circle,
            color: Colors.blue,
          ),
          _buildSummaryTile(
            label: 'Active',
            value: activeServicesCount.toString(),
            icon: Icons.bolt,
            color: Colors.orange,
          ),
          _buildSummaryTile(
            label: 'Ongoing',
            value: ongoingServicesCount.toString(),
            icon: Icons.build,
            color: Colors.teal,
          ),
          _buildSummaryTile(
            label: 'Completed',
            value: completedServicesCount.toString(),
            icon: Icons.done_all,
            color: Colors.green,
          ),
          _buildSummaryTile(
            label: 'Cancelled',
            value: cancelledServicesCount.toString(),
            icon: Icons.cancel,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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

  // ======= USERS LIST + EDIT =======

  void _showEditUserDialog(UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    final addressController = TextEditingController(text: user.address);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address / City'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedName = nameController.text.trim();
              final updatedPhone = phoneController.text.trim();
              final updatedAddress = addressController.text.trim();

              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.id)
                    .update({
                      'name': updatedName,
                      'phone': updatedPhone,
                      'address': updatedAddress,
                    });

                setState(() {
                  final index = _users.indexWhere((u) => u.id == user.id);
                  if (index != -1) {
                    _users[index] = _users[index].copyWith(
                      name: updatedName,
                      phone: updatedPhone,
                      address: updatedAddress,
                    );
                  }
                });

                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersSection() {
    return _buildCard(
      title: 'Users',
      subtitle: 'All customers, providers and admins',
      child: SizedBox(
        height: 320,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                dense: true,
                title: Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user.email.isNotEmpty)
                      Text(user.email, style: const TextStyle(fontSize: 12)),
                    Text(
                      'Role: ${user.userType}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (user.address != null && user.address!.isNotEmpty)
                      Text(
                        'Address: ${user.address}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditUserDialog(user),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ======= SERVICES / BOOKINGS LIST =======

  Widget _buildBookingsSection() {
    if (_bookings.isEmpty) {
      return _buildCard(
        title: 'All Services / Bookings',
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No bookings found.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final Map<String, UserModel> usersById = {for (final u in _users) u.id: u};

    return _buildCard(
      title: 'All Services / Bookings',
      subtitle: 'With customer and provider details',
      child: SizedBox(
        height: 360,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _bookings.length,
          itemBuilder: (context, index) {
            final booking = _bookings[index];
            final customer = usersById[booking.customerId];
            final provider = usersById[booking.providerId];

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.build_circle, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            booking.serviceName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              booking.status,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusLabel(booking.status),
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusColor(booking.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Created: ${DateFormat('dd MMM yyyy, hh:mm a').format(booking.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Customer: ${customer?.name ?? booking.customerName ?? booking.customerId}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.store, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Provider: ${provider?.name ?? booking.providerName ?? booking.providerId}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.confirmed:
        return Colors.blue;
      case BookingStatus.inProgress:
        return Colors.teal;
      case BookingStatus.completed:
        return Colors.green;
      case BookingStatus.paid:
        return Colors.purple;
      case BookingStatus.cancelled:
      case BookingStatus.refunded:
        return Colors.red;
      case BookingStatus.paymentPending:
        return Colors.deepOrange;
    }
  }

  String _getStatusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Accepted';
      case BookingStatus.inProgress:
        return 'Ongoing';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.paid:
        return 'Paid';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.refunded:
        return 'Refunded';
      case BookingStatus.paymentPending:
        return 'Payment Pending';
    }
  }

  // ======= BUILD =======

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // 🔁 Switch "view as" (Admin role selection)
          IconButton(
            tooltip: 'Switch user type',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () {
              // Go back to admin role selection screen
              // (Admin can choose "Continue as Provider" or "Continue as Customer")
              context.go('/admin-role');
            },
          ),

          // 🔄 Refresh data (existing feature)
          IconButton(
            tooltip: 'Refresh data',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),

          // 🚪 Logout
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () {
              NavigationHelper.handleLogout(context);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error, fontSize: 14),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: ListView(
                children: [
                  const SizedBox(height: 8),
                  _buildSummaryTiles(),
                  const SizedBox(height: 8),
                  _buildHorizontalBarChart(
                    'Services by Status',
                    statusChartData,
                    subtitle:
                        'Total created, accepted, active, ongoing, completed, cancelled',
                  ),
                  _buildHorizontalBarChart(
                    'Services Trend',
                    servicesPerMonth,
                    subtitle: 'Number of services (bookings) created per month',
                  ),
                  _buildHorizontalBarChart(
                    'Users Trend',
                    usersPerMonth,
                    subtitle:
                        'Number of users created per month (admin, provider, customer)',
                  ),
                  _buildHorizontalBarChart(
                    'Users by Location',
                    usersByLocation,
                    subtitle: 'All users grouped by city / address',
                  ),
                  _buildBookingsSection(),
                  _buildUsersSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
