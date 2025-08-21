import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/core/services/firebase_service.dart';
import 'package:quickfix/core/services/location_service.dart';
import 'package:quickfix/data/models/provider_model.dart';
import 'package:quickfix/data/models/service_model.dart';
import 'package:uuid/uuid.dart';

class ServiceProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService.instance;
  final LocationService _locationService = LocationService.instance;

  List<ServiceModel> _services = [];
  List<ProviderModel> _providers = [];
  List<ProviderModel> _nearbyProviders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCategory = 'All';

  List<ServiceModel> get services => _services;
  List<ProviderModel> get providers => _providers;
  List<ProviderModel> get nearbyProviders => _nearbyProviders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;

  List<String> get categories => [
    'All',
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Appliance Repair',
    'Painting',
    'Carpentry',
  ];

  void _safeNotifyListeners() {
    Future.microtask(() {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  Future<bool> addService({
    required String name,
    required String description,
    required String category,
    required double basePrice,
    String imageUrl = '',
    List<String> subServices = const [],
    required String mobileNumber,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    _isLoading = true;
    _errorMessage = null;

    if (hasListeners) {
      notifyListeners();
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Generate unique ID
      final serviceId = const Uuid().v4();

      // Create service model with location
      final newService = ServiceModel(
        id: serviceId,
        name: name,
        description: description,
        category: category,
        basePrice: basePrice,
        imageUrl: imageUrl,
        subServices: subServices,
        availability: 'available',
        mobileNumber: mobileNumber,
        providerId: currentUser.uid,
        createdAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        address: address,
        metadata: {
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        },
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .set(newService.toFireStore());

      // Add to local list
      _services.add(newService);

      _isLoading = false;
      if (hasListeners) {
        notifyListeners();
      }
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      if (hasListeners) {
        notifyListeners();
      }
      return false;
    }
  }

  // Helper methods for location
  Future<Position?> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<String?> _getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}';
      }
      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  Future<void> loadMyServices() async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      // ✅ Wait for authentication to be ready
      await Future.delayed(const Duration(milliseconds: 100));

      final currentUser = FirebaseAuth.instance.currentUser;

      // ✅ Add extensive debugging
      debugPrint('🔍 Loading services for user: ${currentUser?.uid}');
      debugPrint('🔍 User email: ${currentUser?.email}');

      if (currentUser == null) {
        debugPrint('❌ No current user found, clearing services');
        _services = [];
        _isLoading = false;
        _safeNotifyListeners();
        return;
      }

      // ✅ Force token refresh to ensure authentication is valid
      await currentUser.getIdToken(true);

      debugPrint('🔍 Querying services with providerId: ${currentUser.uid}');

      // Load services for current provider
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Request timed out. Please check your connection.',
              );
            },
          );

      debugPrint('🔍 Found ${snapshot.docs.length} services in Firestore');

      // ✅ Debug each service found
      for (var doc in snapshot.docs) {
        final data = doc.data();
        debugPrint(
          '📄 Service: ${data['name']} (ID: ${doc.id}) - Provider: ${data['providerId']}',
        );
      }

      _services = snapshot.docs
          .map((doc) => ServiceModel.fromFireStore(doc))
          .toList();

      debugPrint('✅ Successfully loaded ${_services.length} services');

      _isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading services: $e');
      _isLoading = false;
      _errorMessage = e.toString();
      _safeNotifyListeners();
    }
  }

  Future<void> loadProviders({double? userLat, double? userLng}) async {
    try {
      _setLoading(true);

      final querySnapshot = await _firebaseService.getCollection(
        'providers',
        queryBuilder: (query) => query
            .where('isActive', isEqualTo: true)
            .where('isVerified', isEqualTo: true),
      );

      _providers = querySnapshot.docs
          .map((doc) => ProviderModel.fromFireStore(doc))
          .toList();

      //calculate nearby providers if location is provided
      if (userLat != null && userLng != null) {
        _nearbyProviders = _providers.where((provider) {
          final distance = _locationService.calculateDistance(
            userLat,
            userLng,
            provider.latitude,
            provider.longitude,
          );
          return distance <= 20.0; //within 10km
        }).toList();

        //sort by distance
        _nearbyProviders.sort((a, b) {
          final distanceA = _locationService.calculateDistance(
            userLat,
            userLng,
            a.latitude,
            a.longitude,
          );
          final distanceB = _locationService.calculateDistance(
            userLat,
            userLng,
            b.latitude,
            b.longitude,
          );

          return distanceA.compareTo(distanceB);
        });
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load provider:$e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateService({
    required String id,
    required String name,
    required String description,
    required String category,
    required double basePrice,
    String imageUrl = '',
    List<String> subServices = const [],
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Update in Firestore
      await FirebaseFirestore.instance.collection('services').doc(id).update({
        'name': name,
        'description': description,
        'category': category,
        'basePrice': basePrice,
        'imageUrl': imageUrl,
        'subServices': subServices,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Update in local list
      final index = _services.indexWhere((service) => service.id == id);
      if (index != -1) {
        _services[index] = ServiceModel(
          id: id,
          name: name,
          description: description,
          category: category,
          basePrice: basePrice,
          imageUrl: imageUrl,
          subServices: subServices,
          providerId: _services[index].providerId,
          createdAt: _services[index].createdAt,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeService(String id) async {
    try {
      // Remove from Firestore
      await FirebaseFirestore.instance.collection('services').doc(id).delete();

      // Remove from local list
      _services.removeWhere((service) => service.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  List<ServiceModel> getServicesByCategory() {
    if (_selectedCategory == 'All') {
      return services;
    }
    return services
        .where((service) => service.category == selectedCategory)
        .toList();
  }

  List<ProviderModel> getProvidersByService(String serviceId) {
    return _providers
        .where((provider) => provider.services.contains(serviceId))
        .toList();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      // Only call notifyListeners if we're not in a build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Method to load all services (for customers)
  Future<void> loadAllServices({double? userLat, double? userLng}) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('isActive', isEqualTo: true)
          .get();

      List<ServiceModel> allServices = snapshot.docs
          .map((doc) => ServiceModel.fromFireStore(doc))
          .toList();

      // Filter by location if provided (within 20km radius)
      if (userLat != null && userLng != null) {
        allServices = allServices.where((service) {
          if (service.metadata != null &&
              service.metadata!['latitude'] != null &&
              service.metadata!['longitude'] != null) {
            final distance = _locationService.calculateDistance(
              userLat,
              userLng,
              service.metadata!['latitude'],
              service.metadata!['longitude'],
            );
            return distance <= 20.0; // Within 20km
          }
          return true; // Include services without location data
        }).toList();

        // Sort by distance
        allServices.sort((a, b) {
          if (a.metadata?['latitude'] == null ||
              b.metadata?['latitude'] == null) {
            return 0;
          }
          final distanceA = _locationService.calculateDistance(
            userLat,
            userLng,
            a.metadata!['latitude'],
            a.metadata!['longitude'],
          );
          final distanceB = _locationService.calculateDistance(
            userLat,
            userLng,
            b.metadata!['latitude'],
            b.metadata!['longitude'],
          );
          return distanceA.compareTo(distanceB);
        });
      }

      _services = allServices;
      _isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      _safeNotifyListeners();
    }
  }

  // ✅ Add this method to ServiceProvider class
  Future<void> addAvailabilityToExistingServices() async {
    try {
      debugPrint('🔄 Adding availability field to existing services...');

      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('✅ No existing services to update');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        // Only update if availability field doesn't exist
        final data = doc.data();
        if (!data.containsKey('availability')) {
          batch.update(doc.reference, {
            'availability': 'available',
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      }

      await batch.commit();
      debugPrint(
        '✅ Updated ${snapshot.docs.length} existing services with availability field',
      );
    } catch (e) {
      debugPrint('❌ Error updating existing services: $e');
    }
  }
}
