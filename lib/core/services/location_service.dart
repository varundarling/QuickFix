// ignore_for_file: use_build_context_synchronously, deprecated_member_use, library_prefixes

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geoCoding;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:location/location.dart' hide LocationAccuracy;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();

  LocationService._();

  final Location _location = Location();

  /// Requests location permission from the user.
  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Checks if location services are enabled on the device.
  Future<bool> isLocationEnabled() async {
    return await _location.serviceEnabled();
  }

  /// Requests the user to enable location services.
  Future<bool> enableLocationService() async {
    return await _location.requestService();
  }

  /// Gets the current location of the device.
  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      final isEnabled = await isLocationEnabled();
      if (!isEnabled) {
        final enabled = await enableLocationService();
        if (!enabled) return null;
      }

      return await _location.getLocation();
    } catch (e) {
      return null;
    }
  }

  /// Converts coordinates to a human-readable address.
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await geoCoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return '${placemark.name}, ${placemark.subLocality}, ${placemark.locality}, ${placemark.administrativeArea}';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Provides a stream of location updates.
  Stream<LocationData> getLocationStream() {
    return _location.onLocationChanged;
  }

  /// Calculates the distance between two geographical points using the Haversine formula.
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in km
    final double dlat = _toRadians(lat2 - lat1);
    final double dlon = _toRadians(lon2 - lon1);
    final double a =
        (dlat / 2).sin() * (dlat / 2).sin() +
        lat1.cos() * lat2.cos() * (dlon / 2).sin() * (dlon / 2).sin();
    final double c = 2 * a.sqrt().asin();
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  Future<void> onChangeLocationPressed(BuildContext context) async {

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Getting your location...'),
          ],
        ),
      ),
    );

    try {
      final hasPermission = await _checkLocationPermission();

      if (!hasPermission) {
        if (context.mounted) Navigator.of(context).pop();
        if (context.mounted) _showPermissionDeniedDialog(context);
        return;
      }

     final position = await _getCurrentLocation();


      // ✅ ALWAYS close dialog here
      if (context.mounted) Navigator.of(context).pop();

      if (position != null && context.mounted) {

        _showLocationConfirmationDialog(context, position);
      } else if (context.mounted) {

        _showLocationErrorDialog(context);
      }
    } catch (e) {

      if (context.mounted) {
        Navigator.of(context).pop(); // ✅ Close dialog on error
      }
      if (context.mounted) {
        _showLocationErrorDialog(context, error: e.toString());
      }
    }
  }

  // ✅ Check and request location permission
  Future<bool> _checkLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Request user to enable location services
      serviceEnabled = await Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        return false;
      }
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<Position?> _getCurrentLocation() async {
    try {


      // ✅ Use lower accuracy and shorter timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      return position;
    } on TimeoutException {

      return null;
    } catch (e) {

      return null;
    }
  }

  // ✅ Show location confirmation dialog
  Future<void> _showLocationConfirmationDialog(
    BuildContext context,
    Position position,
  ) async {
    // Get address from coordinates
    String address = 'Loading address...';
    try {
      List<geoCoding.Placemark> placemarks = await geoCoding
          .placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        address =
            '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}';
      }
    } catch (e) {
      address = 'Address not available';

    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Confirm Location'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Is this your current location?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.my_location,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(address, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will update your location for finding nearby services.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _updateUserLocation(context, position, address);
    }
  }

  static Future<void> _updateUserLocation(
    BuildContext context,
    Position position,
    String address,
  ) async {


    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Updating location...'),
          ],
        ),
      ),
    );

    try {
      final authProvider = context.read<AuthProvider>();

      final success = await authProvider.updateProfile(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );

      if (context.mounted) Navigator.of(context).pop();

      if (success && context.mounted) {


        // ✅ Wait a bit for Firebase to settle
        await Future.delayed(const Duration(milliseconds: 200));

        // ✅ Force reload user data
        await authProvider.reloadUserData();



        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Location updated: ${address.length > 50 ? '${address.substring(0, 50)}...' : address}',
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authProvider.errorMessage ?? 'Failed to update location',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {

      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ✅ Show permission denied dialog
  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Location Permission Required'),
          ],
        ),
        content: const Text(
          'QuickFix needs location permission to find nearby services. Please enable location permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ✅ Show location error dialog
  void _showLocationErrorDialog(BuildContext context, {String? error}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Location Error'),
          ],
        ),
        content: Text(
          error ??
              'Unable to get your current location. Please make sure location services are enabled and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onChangeLocationPressed(context); // Retry
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ✅ Simplest fix using StatefulBuilder
  Future<void> onManualLocationEntry(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final controller = TextEditingController();

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit_location, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Enter Location'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'City, State, Country',
                      hintText: 'e.g., Mumbai, Maharashtra, India',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) {

                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter your city name or full address',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // ✅ Use controller.text instead of location variable
                    final enteredLocation = controller.text.trim();


                    if (enteredLocation.isNotEmpty) {
                      Navigator.of(context).pop();

                      // ✅ Navigate with the captured location
                      context.go(
                        '/home?location=${Uri.encodeComponent(enteredLocation)}',
                      );
                    } else {
                      // ✅ Show error if empty
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a location'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    // if (location != null && location!.isNotEmpty && context.mounted) {
    //   await _updateManualLocation(context, location!);
    // }
  }

  static Future<void> showLocationChangeOptions(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Change Location',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Use Current Location
            ListTile(
              leading: const Icon(
                Icons.my_location,
                color: AppColors.primary,
                size: 28,
              ),
              title: const Text(
                'Use Current Location',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Get location automatically from GPS'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).pop();
                LocationService.instance.onChangeLocationPressed(context);
              },
            ),

            const Divider(height: 32),

            // Manual Entry
            ListTile(
              leading: const Icon(
                Icons.edit_location,
                color: AppColors.primary,
                size: 28,
              ),
              title: const Text(
                'Enter Location Manually',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Type your city or address'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).pop();
                LocationService.instance.onManualLocationEntry(context);
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Future<void> _updateManualLocation(
  //   BuildContext context,
  //   String location,
  // ) async {
  //   // Show loading
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => const AlertDialog(
  //       content: Row(
  //         children: [
  //           CircularProgressIndicator(),
  //           SizedBox(width: 20),
  //           Text('Updating location...'),
  //         ],
  //       ),
  //     ),
  //   );

  //   try {
  //     // ✅ Fix: Use geoCoding.Location instead of Location
  //     List<geoCoding.Location> locations = await geoCoding.locationFromAddress(
  //       location,
  //     );

  //     if (locations.isNotEmpty) {
  //       final loc = locations.first;
  //       final authProvider = context.read<AuthProvider>();

  //       final success = await authProvider.updateProfile(
  //         latitude: loc.latitude,
  //         longitude: loc.longitude,
  //         address: location,
  //       );

  //       // Close loading dialog
  //       if (context.mounted) Navigator.of(context).pop();

  //       if (success && context.mounted) {
  //         await Future.delayed(const Duration(milliseconds: 200));
  //         await authProvider.reloadUserData();
  //         debugPrint(
  //           '✅ Updated address in provider: ${authProvider.userModel?.address}',
  //         );
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(
  //             content: Text('Location updated successfully!'),
  //             backgroundColor: AppColors.success,
  //           ),
  //         );
  //       }
  //     } else {
  //       throw Exception('Location not found');
  //     }
  //   } catch (e) {
  //     // Close loading dialog
  //     if (context.mounted) Navigator.of(context).pop();

  //     // Show error
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Error: Location not found'),
  //           backgroundColor: AppColors.error,
  //         ),
  //       );
  //     }
  //   }
  // }
}

extension on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double sqrt() => math.sqrt(this);
  double asin() => math.asin(this);
}
